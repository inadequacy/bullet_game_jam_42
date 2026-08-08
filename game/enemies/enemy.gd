class_name Enemy
extends CharacterBody2D

## Base class for every enemy in the game, bosses included.
##
## Subclasses override _behavior() to decide how they move and attack each
## frame. Everything shared - health, damage, death, finding the player - lives
## here so a new enemy type only has to describe what makes it different.

signal died(enemy: Enemy)
signal damaged(enemy: Enemy, amount: float)

@export_group("Stats")
@export var max_health: float = 30.0
@export var move_speed: float = 120.0
## XP awarded to the player on death. Bosses set this much higher.
@export var xp_value: int = 1

@export_group("Entry")
## How close to its entry target an enemy must get before it starts fighting.
@export var entry_arrive_distance: float = 24.0
## Failsafe. An enemy blocked on its way in - jammed against another that spawned
## on the same edge - starts fighting anyway after this long, rather than
## loitering off screen forever while holding a slot in the population cap.
@export var entry_timeout: float = 6.0
@export_group("")

var health: float
var player: Node2D = null

## True while walking in from off screen. See enter_from().
var _entering: bool = false
var _entry_target: Vector2 = Vector2.ZERO
var _entry_time: float = 0.0

@onready var _sprite: CanvasItem = get_node_or_null("Sprite2D")

var _base_modulate: Color = Color.WHITE
var _base_scale: Vector2 = Vector2.ONE


func _ready() -> void:
	health = max_health
	add_to_group("enemies")
	if _sprite != null:
		_base_modulate = _sprite.modulate
		if _sprite is Node2D:
			_base_scale = (_sprite as Node2D).scale
	_acquire_player()
	_on_enemy_ready()
	died.connect(func(enemy): GameManager.add_score(enemy.xp_value))


func _physics_process(delta: float) -> void:
	# The player can be re-instanced between runs, so re-acquire if it went away.
	if player == null or not is_instance_valid(player):
		_acquire_player()
	if _entering:
		_walk_in(delta)
	else:
		_behavior(delta)
	move_and_slide()


# --- Walking in --------------------------------------------------------------

## Drops the enemy at `from` - meant to be somewhere off screen - and sends it
## walking to `target` inside the arena.
##
## Until it arrives, _behavior() is skipped ENTIRELY: it does not cast, swing or
## strafe. An enemy that could attack from outside the view would be hitting the
## player from somewhere they cannot see, let alone answer.
##
## Call this after add_child(), not before - it writes global_position, which
## only means anything once the node is in the tree.
func enter_from(from: Vector2, target: Vector2) -> void:
	global_position = from
	_entry_target = target
	_entry_time = 0.0
	_entering = true


## True while the enemy is still walking in and not yet fighting.
func is_entering() -> bool:
	return _entering


## Straight line to the entry target, no avoidance - it is a short walk across
## empty ground at the edge of the arena.
func _walk_in(delta: float) -> void:
	_entry_time += delta
	if (global_position.distance_to(_entry_target) <= entry_arrive_distance
			or _entry_time >= entry_timeout):
		_entering = false
		velocity = Vector2.ZERO
		return
	velocity = global_position.direction_to(_entry_target) * move_speed


# --- Overridable by subclasses -----------------------------------------------

## Called once after the base class has finished setting up.
func _on_enemy_ready() -> void:
	pass


## Called every physics frame. Set `velocity` here; the base class moves.
func _behavior(_delta: float) -> void:
	pass


## Called after health is reduced but before the death check.
func _on_damaged(_amount: float) -> void:
	pass


## Called just before the node is freed.
func _on_death() -> void:
	pass


# --- Shared helpers ----------------------------------------------------------

func has_player() -> bool:
	return player != null and is_instance_valid(player)


func direction_to_player() -> Vector2:
	if not has_player():
		return Vector2.ZERO
	return global_position.direction_to(player.global_position)


func distance_to_player() -> float:
	if not has_player():
		return INF
	return global_position.distance_to(player.global_position)


func take_damage(amount: float) -> void:
	if health <= 0.0:
		return
	health -= amount
	damaged.emit(self, amount)
	flash(Color(4.0, 4.0, 4.0), 0.08)
	_on_damaged(amount)
	if health <= 0.0:
		die()


func die() -> void:
	_on_death()
	died.emit(self)
	queue_free()


## Turns the sprite toward the player. Only the sprite rotates - rotating the
## body would rotate its collider with it.
func face_player() -> void:
	if has_player() and _sprite is Node2D:
		(_sprite as Node2D).rotation = direction_to_player().angle()


## Swells the sprite to telegraph an incoming attack, then settles it back to
## its authored scale. Every attack in the game gets one of these - it's the
## player's cue that something is about to land.
func telegraph(swell: float, grow_time: float, settle_time: float) -> void:
	if _sprite == null or not _sprite is Node2D:
		return
	var tween := create_tween()
	tween.tween_property(_sprite, "scale", _base_scale * swell, grow_time)
	tween.tween_property(_sprite, "scale", _base_scale, settle_time)


## Briefly tints the sprite, if the scene has one named "Sprite2D".
func flash(color: Color, duration: float) -> void:
	if _sprite == null:
		return
	_sprite.modulate = color
	var tween := create_tween()
	tween.tween_property(_sprite, "modulate", _base_modulate, duration)


func _acquire_player() -> void:
	player = get_tree().get_first_node_in_group("player") as Node2D
