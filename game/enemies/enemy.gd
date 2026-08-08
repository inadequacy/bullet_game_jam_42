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
	_acquire_player()
	_on_enemy_ready()
	died.connect(func(enemy): GameManager.add_score(enemy.xp_value))


func _physics_process(delta: float) -> void:
	# The player can be re-instanced between runs, so re-acquire if it went away.
	if player == null or not is_instance_valid(player):
		_acquire_player()

	_tick_status(delta)
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
	_on_death()
	# Scoring rides on the `died` signal, connected in _ready. Adding it here too
	# double-counted every kill.
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
