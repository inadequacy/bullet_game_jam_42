class_name Caster
extends Enemy

## A range-keeping spellcaster. Holds a preferred distance from the player and
## fires a spread of projectiles on a timer.
##
## Blue, green and red casters are all this one script - they differ only by
## `projectile_kind` and tuning, so each new colour costs a scene and no code.
##
##   BLUE  - short interval, wide spread, many projectiles. The crowd.
##   GREEN - long telegraph, few projectiles. The parry bait.
##   RED   - homing. Gate behind the first boss (see docs/game_info.md §5).

@export_group("Positioning")
## Distance the caster tries to hold from the player.
@export var preferred_range: float = 340.0
## How far outside preferred_range it tolerates before closing or backing off.
@export var range_tolerance: float = 70.0
## Strafing speed as a fraction of move_speed, used while at preferred range.
@export var strafe_speed_ratio: float = 0.55
## Seconds between strafe direction reversals, so it doesn't orbit predictably.
@export var strafe_flip_interval: float = 2.5

@export_group("Casting")
@export var projectile_scene: PackedScene
## Which spell this caster throws. Drives colour and how the player answers it.
@export var projectile_kind: EnemyProjectile.Kind = EnemyProjectile.Kind.BLUE
## Overrides the projectile scene's own speed when above zero.
@export var projectile_speed: float = 0.0
@export var cast_interval: float = 2.4
## Wind-up before each cast. The player's cue to start moving.
@export var telegraph_time: float = 0.5
@export var projectiles_per_cast: int = 3
## Total arc of the spread, in degrees.
@export var spread_degrees: float = 26.0
## Casters root themselves while winding up, which makes them punishable.
@export var stop_while_casting: bool = true

var _cast_timer: float = 0.0
var _telegraphing: bool = false
var _strafe_dir: float = 1.0
var _strafe_flip_timer: float = 0.0


func _on_enemy_ready() -> void:
	_strafe_dir = 1.0 if randf() < 0.5 else -1.0
	# Desync casters that spawn on the same frame.
	_cast_timer = randf() * cast_interval


func _behavior(delta: float) -> void:
	if not has_player():
		velocity = Vector2.ZERO
		return

	face_player()
	_move(delta)
	_tick_casting(delta)


func _move(delta: float) -> void:
	if _telegraphing and stop_while_casting:
		velocity = Vector2.ZERO
		return

	_strafe_flip_timer += delta
	if _strafe_flip_timer >= strafe_flip_interval:
		_strafe_flip_timer = 0.0
		_strafe_dir *= -1.0

	var to_player := direction_to_player()
	var dist := distance_to_player()

	if dist > preferred_range + range_tolerance:
		velocity = to_player * move_speed
	elif dist < preferred_range - range_tolerance:
		velocity = -to_player * move_speed
	else:
		# Inside the band: circle the player instead of standing still.
		velocity = to_player.orthogonal() * _strafe_dir * move_speed * strafe_speed_ratio


func _tick_casting(delta: float) -> void:
	_cast_timer += delta

	if not _telegraphing and _cast_timer >= cast_interval - telegraph_time:
		_telegraphing = true
		telegraph(1.25, telegraph_time, 0.1)

	if _cast_timer >= cast_interval:
		_cast_timer = 0.0
		_telegraphing = false
		_cast()


func _cast() -> void:
	if projectile_scene == null or not has_player():
		return

	var base_angle := direction_to_player().angle()
	var spread := deg_to_rad(spread_degrees)

	for i in projectiles_per_cast:
		# Spread evenly across the arc, centred on the player.
		var offset := 0.0
		if projectiles_per_cast > 1:
			offset = (float(i) / float(projectiles_per_cast - 1) - 0.5) * spread

		var projectile := projectile_scene.instantiate() as EnemyProjectile
		# Set kind before the node enters the tree - _ready() colours it.
		projectile.kind = projectile_kind
		if projectile_speed > 0.0:
			projectile.speed = projectile_speed
		# Parent to the scene, not the caster, so shots don't inherit its motion.
		get_tree().current_scene.add_child(projectile)
		projectile.launch(global_position, Vector2.RIGHT.rotated(base_angle + offset))
