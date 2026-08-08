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
## How long the caster charges before firing. THE REACTION WINDOW - the shot
## itself is far too fast to answer, so this aura is what the player reads.
## Raise it to make the enemy more forgiving.
@export var charge_time: float = 0.6
@export var hitscan_damage: float = 1.0
## How close to the point it was aimed at the player must still be for the shot
## to connect.
##
## The shot commits to where the player STOOD at fire time, so this is what makes
## the streak honest: walk out of that spot and the beam lands behind you and
## does nothing. Without it the beam visibly stopped short of the player and hurt
## them anyway, which read as the game cheating.
@export var hitscan_hit_radius: float = 40.0
## Colour of the aura and the shot.
@export var charge_color: Color = Color(0.3, 1.0, 0.4)
## How much brighter the caster's own sprite gets at full charge. Must be well
## above 1.0 or the tint is lost against an already-green sprite.
@export var charge_glow_intensity: float = 2.4
@export var aura_start_radius: float = 26.0
@export var aura_end_radius: float = 72.0

@export_subgroup("Trace")
## Pixels per second. THIS IS THE PARRY WINDOW, not just a visual.
##
## The parry resolves when the streak ARRIVES, and a parry may only be started
## once the streak is out (see movement.gd's try_parry_hitscan) - so flight time
## is exactly how long the player has to answer a shot they can see. At 2500 the
## beam crossed a typical gap in ~0.13s, which meant the only way to parry it was
## to press before it existed. At 1200 the same gap takes ~0.25s: the beam is
## visibly in the air for the whole of the parry window it opens.
@export var trace_speed: float = 1200.0
## Length of the visible streak.
@export var trace_length: float = 140.0
@export var trace_width: float = 3.0

## The green caster's charge and its release, and nothing else in the game. Blue
## and red cast silently - there is no sample for a travelling enemy shot - and
## green is the one the player has to hear coming anyway, because the charge is
## the parry window and the release is what has to be parried.
const CHARGE_SOUND := preload("res://assets/sounds/magic_attack1.wav")

var _aura: ChargeAura = null

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


## The gap between casts right now: the authored interval, tightened by the
## arena's difficulty ramp. Floored so the ramp can never collapse it to nothing.
func effective_cast_interval() -> float:
	return maxf(cast_interval * attack_interval_scale(), 0.35)


func _tick_casting(delta: float) -> void:
	_cast_timer += delta
	var interval := effective_cast_interval()
	# The wind-up is NOT scaled by the ramp - it is the player's read on the
	# attack, and shortening it would make late-run casters unreactable rather
	# than fast. Clamped only so a heavily ramped interval cannot end up shorter
	# than its own telegraph, which would leave the caster permanently winding up.
	var wind_up := minf(telegraph_duration(), interval * 0.8)

	if not _telegraphing and _cast_timer >= interval - wind_up:
		_telegraphing = true
		_start_wind_up(wind_up)

	if _cast_timer >= interval:
		_cast_timer = 0.0
		_telegraphing = false
		_cast()


func _start_wind_up(duration: float) -> void:
	if attack_mode == AttackMode.HITSCAN:
		_start_charge_glow(duration)
	else:
		telegraph(1.25, duration, 0.1)


## Builds the aura and brightens the caster over the whole charge, so "about to
## fire" gets progressively louder instead of popping on at the end.
func _start_charge_glow(duration: float) -> void:
	# Hitscan casters never call telegraph(), so the attack artwork has to be
	# swapped in here too - the charge IS this enemy's wind-up.
	show_attacking(duration)
	# The wind-up: low and quiet, a hum starting somewhere on the map.
	SoundManager.play_sfx(CHARGE_SOUND, 0, 0.55, 0.7, -5.0)
	if _aura != null and is_instance_valid(_aura):
		_aura.queue_free()
	_aura = ChargeAura.start(self, aura_start_radius, aura_end_radius,
		duration, charge_color)

	if _sprite == null:
		return
	# Overbright, not just "green" - the sprite is already green, so tinting
	# toward the same hue would be invisible. Brightness is the signal.
	var lit := charge_color * charge_glow_intensity
	lit.a = _base_modulate.a
	var tween := create_tween()
	tween.tween_property(_sprite, "modulate", lit, duration)


func _end_charge_glow() -> void:
	if _aura != null and is_instance_valid(_aura):
		_aura.release()
		_aura = null

	if _sprite == null:
		return
	var tween := create_tween()
	# current_modulate(), not _base_modulate: a caster chilled mid-charge must
	# still look chilled when the glow drops.
	tween.tween_property(_sprite, "modulate", current_modulate(), 0.15)


func _cast() -> void:
	if attack_mode == AttackMode.HITSCAN:
		_fire_hitscan()
	else:
		_fire_projectiles()


## Releases the charge as a travelling streak aimed at where the player is
## standing right now. The target is fixed at fire time - green is a committed
## shot: once it is out, it goes where it was pointed.
##
## Answered EITHER WAY. Parry it, or be somewhere else by the time it lands - the
## trace only damages what is still within hitscan_hit_radius of the point it was
## aimed at. Both answers need the same read of the charge aura, which is what
## the aura is for.
##
## The trace resolves damage and parry on ARRIVAL, so it owns that logic, not
## this caster - it has to keep working even if the caster dies mid-flight.
func _fire_hitscan() -> void:
	_end_charge_glow()
	if not has_player():
		return

	# The release, at the instant the shot goes out. Higher and louder than the
	# wind-up above, so the pair reads as one rising cue - "charging" then "NOW" -
	# rather than as the same noise twice. The trace itself is too fast to react
	# to, so this is confirmation rather than a warning: it lands on the same
	# frame as the parry check in try_parry_hitscan().
	SoundManager.play_sfx(CHARGE_SOUND, 0, 0.8, 0.95, -1.0)

	HitscanTrace.fire(get_parent(), global_position, player.global_position,
		charge_color, trace_speed, trace_length, trace_width, hitscan_damage,
		hitscan_hit_radius)


func _on_death() -> void:
	# Don't leave an aura floating where the caster used to be.
	if _aura != null and is_instance_valid(_aura):
		_aura.queue_free()
		_aura = null


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
