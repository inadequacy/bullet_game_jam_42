class_name Enemy
extends CharacterBody2D

## Base class for every enemy in the game, bosses included.
##
## Subclasses override _behavior() to decide how they move and attack each
## frame. Everything shared - health, damage, death, finding the player - lives
## here so a new enemy type only has to describe what makes it different.

signal died(enemy: Enemy)
signal damaged(enemy: Enemy, amount: float)

@export_group("Art")
## Normal artwork. Also what the sprite reverts to after an attack.
@export var idle_texture: Texture2D
## Shown while winding up an attack. Optional - leave empty and the sprite never
## changes, which is what a boss with a single pose wants.
@export var attack_texture: Texture2D
## Left lying on the ground after death. Optional - without one the enemy just
## disappears the way it always did.
@export var dead_texture: Texture2D
## How long the corpse lies there before it fades and frees itself.
@export var corpse_duration: float = 3.0

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

# --- Status effects (Ice and Fire cards) -------------------------------------
# Applied to the BASE class rather than to each enemy, and enforced by scaling
# `velocity` after _behavior() has set it. Subclasses therefore need no changes
# at all - a chill works on the chaser, every caster, and any boss written later
# without one of them knowing status effects exist.

## Speed multiplier while chilled. 1.0 is unaffected.
var _chill_factor: float = 1.0
var _chill_left: float = 0.0
## While above zero the enemy does not move AND does not act - _behavior() is
## skipped outright, which is what stops a frozen caster from finishing a cast.
var _freeze_left: float = 0.0
var _burn_left: float = 0.0
var _burn_dps: float = 0.0
## Burn lands in twice-a-second bites rather than per frame, so the damage flash
## reads as a pulse instead of a strobe.
const BURN_TICK := 0.5
var _burn_tick_left: float = 0.0

const CHILL_TINT := Color(0.62, 0.82, 1.25)
const FREEZE_TINT := Color(0.45, 0.75, 1.5)

## Seconds of attack artwork still to show. Counted down rather than reverted on
## a timer or a tween, so overlapping wind-ups cannot leave the sprite stuck in
## the attack pose.
var _attack_art_left: float = 0.0
## Scale that makes the attack artwork read at the same size as the idle art.
##
## The two textures are not drawn to a common frame: Attacking_cat.png is
## 784x783 against Idle_cat.png's 274x407, so swapping them at a fixed scale
## made the chaser nearly DOUBLE in size the instant it wound up, which read as
## a bug rather than as an attack.
var _attack_scale: Vector2 = Vector2.ONE
## True once this enemy has died. Guards against a second death - burn ticks and
## an ultimate landing in the same frame can both reach take_damage().
var _dying: bool = false

## True while walking in from off screen. See enter_from().
var _entering: bool = false
var _entry_target: Vector2 = Vector2.ZERO
var _entry_time: float = 0.0
## Collision mask parked while walking in, restored on arrival.
var _entry_saved_mask: int = 0

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
		_attack_scale = _base_scale
		if idle_texture != null and attack_texture != null \
				and attack_texture.get_height() > 0:
			_attack_scale = _base_scale * (float(idle_texture.get_height())
				/ float(attack_texture.get_height()))
	_acquire_player()
	_on_enemy_ready()
	died.connect(func(enemy): GameManager.add_score(enemy.xp_value))


func _physics_process(delta: float) -> void:
	# The player can be re-instanced between runs, so re-acquire if it went away.
	if player == null or not is_instance_valid(player):
		_acquire_player()

	_tick_status(delta)
	_tick_attack_art(delta)
	# Burn can finish the job. Nothing below should run on a corpse.
	if health <= 0.0:
		return

	if is_frozen():
		velocity = Vector2.ZERO
		move_and_slide()
		return

	if _entering:
		_walk_in(delta)
	else:
		_behavior(delta)
		# After _behavior, which has just set velocity from whatever the subclass
		# decided. Scaling here catches chase, strafe and retreat in one place.
		velocity *= _chill_factor
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
	# Pass through everything on the way in. The arena's LevelBounds walls sit
	# right at the edge of the view, between the spawn point and the arena, so an
	# arriving enemy would otherwise walk into a wall and stop dead just off
	# screen - alive, passive, and holding a slot in the population cap forever.
	# Guarded so a second call cannot park a mask of 0 as the "original".
	if not _entering:
		_entry_saved_mask = collision_mask
	collision_mask = 0
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
		collision_mask = _entry_saved_mask
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


# --- Status effects ----------------------------------------------------------

## Slows the enemy to `factor` of its speed for `duration`.
##
## Refreshing takes the STRONGER factor and the LONGER remaining time, rather
## than overwriting. Without that, a stream of weak hits landing on a deeply
## chilled enemy would keep resetting it to the weak slow.
func apply_chill(factor: float, duration: float) -> void:
	if duration <= 0.0:
		return
	_chill_factor = minf(_chill_factor, clampf(factor, 0.0, 1.0))
	_chill_left = maxf(_chill_left, duration)
	_refresh_status_tint()


## Stops the enemy dead - no movement, no casting - for `duration`.
func apply_freeze(duration: float) -> void:
	if duration <= 0.0:
		return
	_freeze_left = maxf(_freeze_left, duration)
	_refresh_status_tint()


## Damage over time. Refreshing takes the higher rate and the longer time, for
## the same reason chill does.
func apply_burn(damage_per_second: float, duration: float) -> void:
	if damage_per_second <= 0.0 or duration <= 0.0:
		return
	_burn_dps = maxf(_burn_dps, damage_per_second)
	_burn_left = maxf(_burn_left, duration)


## True while chilled OR frozen. Shatter reads this to decide its damage bonus,
## so a frozen enemy counts as chilled - being stopped is not less cold.
func is_chilled() -> bool:
	return _chill_left > 0.0 or _freeze_left > 0.0


func is_frozen() -> bool:
	return _freeze_left > 0.0


func _tick_status(delta: float) -> void:
	var was_cold := is_chilled()

	if _freeze_left > 0.0:
		_freeze_left = maxf(_freeze_left - delta, 0.0)

	if _chill_left > 0.0:
		_chill_left = maxf(_chill_left - delta, 0.0)
		if _chill_left <= 0.0:
			_chill_factor = 1.0

	if was_cold and not is_chilled():
		_refresh_status_tint()

	_tick_burn(delta)


func _tick_burn(delta: float) -> void:
	if _burn_left <= 0.0:
		return
	_burn_left = maxf(_burn_left - delta, 0.0)
	_burn_tick_left -= delta
	if _burn_tick_left > 0.0:
		return
	_burn_tick_left = BURN_TICK
	take_damage(_burn_dps * BURN_TICK)
	if _burn_left <= 0.0:
		_burn_dps = 0.0


## What the sprite should be tinted right now, status included. `flash()` and the
## caster's charge glow both settle back to this rather than to _base_modulate,
## so a hit or a cast cannot wipe an ice tint that is still running.
func current_modulate() -> Color:
	if _freeze_left > 0.0:
		return FREEZE_TINT
	if _chill_left > 0.0:
		return CHILL_TINT
	return _base_modulate


func _refresh_status_tint() -> void:
	if _sprite != null:
		_sprite.modulate = current_modulate()


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
	if _dying:
		return
	_dying = true

	_on_death()
	# Scoring rides on the `died` signal, connected in _ready. Adding it here too
	# double-counted every kill.
	died.emit(self)

	if dead_texture == null or not _sprite is Sprite2D:
		queue_free()
		return
	_become_corpse()


## Turns the enemy into a body on the floor for `corpse_duration`, then frees it.
##
## The corpse LEAVES the "enemies" group immediately. Everything in the game
## finds its targets through that group - auto-aim, the explosion, the beam, the
## Rain of Fire, and level.gd's head count - so staying in it would mean the
## player could keep shooting a dead cat, ultimates would waste damage on
## corpses, and the arena would refuse to spawn replacements until the bodies
## rotted. Leaving the group makes the corpse purely something to look at.
func _become_corpse() -> void:
	remove_from_group("enemies")
	set_physics_process(false)
	velocity = Vector2.ZERO
	# Nothing collides with a body: the player walks over it and shots fly past.
	collision_layer = 0
	collision_mask = 0

	var sprite := _sprite as Sprite2D
	sprite.texture = dead_texture
	sprite.scale = _corpse_scale()
	# Under the living, so a body never hides a fighter standing on it.
	sprite.z_index = -1
	# Drop any chill or freeze tint - it is not cold any more, it is dead.
	sprite.modulate = _base_modulate

	# Held at full opacity for most of its life, then faded, so the body reads
	# as scenery that decays rather than as something blinking out.
	var tween := create_tween()
	tween.tween_interval(corpse_duration * 0.7)
	tween.tween_property(sprite, "modulate:a", 0.0, corpse_duration * 0.3)
	tween.tween_callback(queue_free)


## The dead sprites are drawn lying down - dead_cat.png is 519x238 against the
## standing 274x407 - so the scale is chosen to make the body about as long as
## the enemy was tall, rather than reusing the standing scale and getting a
## corpse half again too big.
func _corpse_scale() -> Vector2:
	if idle_texture == null or dead_texture == null or dead_texture.get_width() <= 0:
		return _base_scale
	var standing_height := float(idle_texture.get_height()) * _base_scale.y
	var factor := standing_height / float(dead_texture.get_width())
	return Vector2(factor, factor)


## Turns the sprite toward the player. Only the sprite is touched - moving the
## body would move its collider with it.
##
## FLIPS rather than rotates. These are drawn characters now, and spinning one
## to point at the player leaves it lying on its side or fully upside down for
## half the arena. Rotation is kept only for anything that is not a Sprite2D,
## where it was the old placeholder behaviour.
func face_player() -> void:
	if not has_player() or _sprite == null:
		return
	if _sprite is Sprite2D:
		(_sprite as Sprite2D).flip_h = player.global_position.x < global_position.x
	elif _sprite is Node2D:
		(_sprite as Node2D).rotation = direction_to_player().angle()


## Shows the attack artwork for `duration`, then reverts. Does nothing when the
## enemy has no attack texture, so this is always safe to call.
func show_attacking(duration: float) -> void:
	if attack_texture == null or not _sprite is Sprite2D:
		return
	(_sprite as Sprite2D).texture = attack_texture
	(_sprite as Sprite2D).scale = _attack_scale
	_attack_art_left = maxf(_attack_art_left, duration)


func _tick_attack_art(delta: float) -> void:
	if _attack_art_left <= 0.0:
		return
	_attack_art_left -= delta
	if _attack_art_left <= 0.0 and idle_texture != null and _sprite is Sprite2D:
		(_sprite as Sprite2D).texture = idle_texture
		(_sprite as Sprite2D).scale = _base_scale


## The sprite's resting scale right now, which depends on which artwork is up.
## telegraph() has to tween toward this rather than _base_scale, or a wind-up
## would animate the attack pose back to the idle pose's size.
func _art_base_scale() -> Vector2:
	return _attack_scale if _attack_art_left > 0.0 else _base_scale


## Swells the sprite to telegraph an incoming attack, then settles it back to
## its authored scale. Every attack in the game gets one of these - it's the
## player's cue that something is about to land.
func telegraph(swell: float, grow_time: float, settle_time: float) -> void:
	# Every wind-up in the game runs through here, so it is the one place the
	# attack artwork needs swapping in.
	show_attacking(grow_time + settle_time)
	if _sprite == null or not _sprite is Node2D:
		return
	# _art_base_scale(), not _base_scale: show_attacking() ran a line ago, so the
	# resting size may now be the attack artwork's.
	var resting := _art_base_scale()
	var tween := create_tween()
	tween.tween_property(_sprite, "scale", resting * swell, grow_time)
	tween.tween_property(_sprite, "scale", resting, settle_time)


## Briefly tints the sprite, if the scene has one named "Sprite2D". Settles back
## to current_modulate(), so flashing a chilled enemy leaves it still looking
## chilled rather than snapping it back to its normal colour.
func flash(color: Color, duration: float) -> void:
	if _sprite == null:
		return
	_sprite.modulate = color
	var tween := create_tween()
	tween.tween_property(_sprite, "modulate", current_modulate(), duration)


func _acquire_player() -> void:
	player = get_tree().get_first_node_in_group("player") as Node2D
