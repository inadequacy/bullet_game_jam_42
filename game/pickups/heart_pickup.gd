class_name HeartPickup
extends Area2D

## A heart left behind by a dead enemy. Walking over it heals the player.
##
## Dropped by Enemy._disappear() at a flat chance, and only once the corpse has
## finished fading - the heart is what is left where the body was, so it must not
## appear on top of one.
##
## Healing is a PERCENTAGE of the player's maximum, not a flat number, so the
## drop is worth the same whether or not the run has picked up health cards.

## Fraction of maximum health restored. 0.2 is the 20% the drop is designed
## around; the heal is rounded UP so it can never come out as zero on a small bar.
@export var heal_fraction: float = 0.2
## Seconds the heart lies there before it fades and frees itself. Long enough to
## be worth crossing the arena for, short enough that hearts cannot be banked and
## hoovered up all at once during a bad moment.
@export var lifetime: float = 12.0
## The last stretch of that lifetime is spent blinking, so the player can see the
## pickup is about to go rather than having it vanish under their feet.
@export var blink_time: float = 3.0
## Height of the idle bob, in pixels.
@export var bob_height: float = 6.0
@export var bob_period: float = 1.4
@export var pickup_logs: bool = true

var _healing_sound: AudioStream = preload("res://assets/sounds/healing1.wav")

## True once collected, so two overlaps in the same frame cannot heal twice.
var _taken: bool = false
var _age: float = 0.0

@onready var _sprite: Sprite2D = $Sprite2D
## Where the sprite rests. The bob is applied around this rather than accumulated,
## so it cannot drift.
@onready var _sprite_home: Vector2 = _sprite.position


func _ready() -> void:
	add_to_group("pickups")
	body_entered.connect(_on_body_entered)
	# Small pop on arrival, so a heart appearing mid-fight catches the eye.
	var base := _sprite.scale
	_sprite.scale = base * 0.2
	var tween := create_tween()
	tween.tween_property(_sprite, "scale", base * 1.15, 0.18)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(_sprite, "scale", base, 0.12)


func _process(delta: float) -> void:
	_age += delta
	if _age >= lifetime:
		queue_free()
		return

	_sprite.position = _sprite_home + Vector2(0.0,
		-bob_height * sin(_age * TAU / maxf(bob_period, 0.001)))

	# Blink out the last few seconds. Squared so the flashing quickens as the
	# heart runs down instead of pulsing at one steady rate the whole way.
	var left := lifetime - _age
	if left <= blink_time:
		var urgency := 1.0 - left / maxf(blink_time, 0.001)
		_sprite.visible = fmod(_age, 0.36 - 0.22 * urgency) > (0.18 - 0.11 * urgency)
	else:
		_sprite.visible = true


func _on_body_entered(body: Node2D) -> void:
	if _taken or not body.is_in_group("player"):
		return

	var bar := _find_health_bar(body)
	if bar == null:
		push_warning("Heart pickup: no node in the 'health_bar' group - not collected.")
		return
	# Already at full: leave the heart on the ground rather than burning it. The
	# player can come back for it after the next hit.
	if bar.current_health >= bar.max_health:
		return

	_taken = true
	# Rounded up: at 20% of a 10 point bar this is 2, and on any bar small enough
	# to round to zero it still returns something.
	var amount := int(ceil(float(bar.max_health) * heal_fraction))
	bar.heal(amount)
	SoundManager.play_sfx(_healing_sound, 0, 0.95, 1.05, 0)

	if pickup_logs:
		print("[HEART] picked up | +%d hp | %d/%d"
			% [amount, bar.current_health, bar.max_health])

	_collect_effect()


## The bar the player is using. Asked of the player first, so a test harness that
## assigned one directly is honoured, with the group as the normal path.
func _find_health_bar(body: Node2D) -> HealthBar:
	if body.has_method("find_health_bar"):
		var bar = body.find_health_bar()
		if bar != null and is_instance_valid(bar):
			return bar
	return get_tree().get_first_node_in_group("health_bar") as HealthBar


## Swells and fades on the way out, then frees. Collision is dropped immediately
## so nothing can touch the heart while the flourish plays.
func _collect_effect() -> void:
	set_deferred("monitoring", false)
	set_process(false)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(_sprite, "scale", _sprite.scale * 2.0, 0.25)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(_sprite, "position", _sprite_home - Vector2(0.0, 26.0), 0.25)
	tween.tween_property(_sprite, "modulate:a", 0.0, 0.25)
	tween.chain().tween_callback(queue_free)
