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

## PROJECTILE fires travelling shots. HITSCAN charges, then hits instantly.
enum AttackMode { PROJECTILE, HITSCAN }

@export_group("Casting")
@export var attack_mode: AttackMode = AttackMode.PROJECTILE
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
## For HITSCAN this must stay ON - a stationary, glowing caster IS the tell.
@export var stop_while_casting: bool = true

@export_group("Hitscan")
## How long the caster glows before firing. THE ENTIRE REACTION WINDOW - the
## trace itself is instant and cannot be dodged, so this is what the player
## reads and parries. Raise it to make the enemy more forgiving.
@export var charge_time: float = 0.3
@export var hitscan_damage: float = 1.0
## Colour the caster glows while charging.
@export var charge_color: Color = Color(0.35, 1.0, 0.45)
## How long the trace stays on screen after the hit. Cosmetic only.
@export var trace_lifetime: float = 0.12
@export var trace_width: float = 3.0

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


## The wind-up before a shot. Hitscan uses charge_time - that glow is the only
## warning the player gets, so the two knobs are kept separate per mode.
func telegraph_duration() -> float:
	return charge_time if attack_mode == AttackMode.HITSCAN else telegraph_time


func _tick_casting(delta: float) -> void:
	_cast_timer += delta
	var wind_up := telegraph_duration()

	if not _telegraphing and _cast_timer >= cast_interval - wind_up:
		_telegraphing = true
		_start_wind_up(wind_up)

	if _cast_timer >= cast_interval:
		_cast_timer = 0.0
		_telegraphing = false
		_cast()


func _start_wind_up(duration: float) -> void:
	if attack_mode == AttackMode.HITSCAN:
		_start_charge_glow(duration)
	else:
		telegraph(1.25, duration, 0.1)


## Ramps the sprite toward charge_color over the whole charge, so the glow
## builds rather than popping on - it reads as "about to fire".
func _start_charge_glow(duration: float) -> void:
	if _sprite == null:
		return
	var tween := create_tween()
	tween.tween_property(_sprite, "modulate", charge_color, duration)


func _end_charge_glow() -> void:
	if _sprite == null:
		return
	var tween := create_tween()
	tween.tween_property(_sprite, "modulate", _base_modulate, 0.12)


func _cast() -> void:
	if attack_mode == AttackMode.HITSCAN:
		_fire_hitscan()
	else:
		_fire_projectiles()


## Instant hit along a straight line to wherever the player is standing right
## now. Deliberately undodgeable: the player's chance was the charge glow. The
## only way out is a parry that is ALREADY active when this fires.
func _fire_hitscan() -> void:
	_end_charge_glow()
	if not has_player():
		return

	var target: Vector2 = player.global_position
	_spawn_trace(global_position, target)

	if player.has_method("try_parry_hitscan") and player.try_parry_hitscan(global_position):
		return
	if player.has_method("take_damage"):
		player.take_damage(hitscan_damage)


## The line the player sees after the fact. Purely feedback - the damage has
## already been resolved by the time this appears.
func _spawn_trace(from: Vector2, to: Vector2) -> void:
	var line := Line2D.new()
	line.width = trace_width
	line.default_color = charge_color
	line.z_index = 10
	line.add_point(from)
	line.add_point(to)
	get_tree().current_scene.add_child(line)

	var tween := line.create_tween()
	tween.tween_property(line, "modulate:a", 0.0, trace_lifetime)
	tween.tween_callback(line.queue_free)


func _fire_projectiles() -> void:
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
