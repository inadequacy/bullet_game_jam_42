class_name Caster
extends Enemy

## A range-keeping spellcaster. Holds a distance from the player and fires a
## spread of projectiles on a timer.
##
## All three colours are this one script, differing only by `projectile_kind`
## and tuning, so a new colour costs a scene and no code.
##
##   BLUE  - short interval, wide spread, many shots. The crowd.
##   GREEN - long charge, one shot too fast to dodge on reaction. The parry
##           bait: the charge aura is the warning, not the shot.
##   RED   - homing. Answered by a dash, or by a parry with Crimson Guard.

@export_group("Positioning")
@export var preferred_range: float = 340.0
## How far outside preferred_range it tolerates before closing or backing off.
@export var range_tolerance: float = 70.0
## Strafing speed as a fraction of move_speed, used while at preferred range.
@export var strafe_speed_ratio: float = 0.55
## Seconds between strafe reversals, so it doesn't orbit predictably.
@export var strafe_flip_interval: float = 2.5

@export_group("Casting")
@export var projectile_scene: PackedScene
## Drives colour and how the player is allowed to answer the shot.
@export var projectile_kind: EnemyProjectile.Kind = EnemyProjectile.Kind.BLUE
## Overrides the projectile scene's own speed when above zero.
##
## Ceiling ~3120: contact is sampled once per physics tick, so the shot steps
## speed/60 px and must stay well under the 52px depth of player hurtbox plus
## shot. Green runs 1600 for a 2x margin; past the ceiling a head-on hit is
## missed outright.
@export var projectile_speed: float = 0.0
@export var cast_interval: float = 2.4
## Wind-up before each cast. The player's cue to start moving.
@export var telegraph_time: float = 0.5
@export var projectiles_per_cast: int = 3
## Total arc of the spread, in degrees.
@export var spread_degrees: float = 26.0
## Casters root themselves while winding up, which makes them punishable.
@export var stop_while_casting: bool = true

@export_group("Charge glow")
## Swap the plain telegraph flash for the swelling aura. Green only: the charge
## is what a parry is timed against, so it needs to be louder than blue's flash.
@export var charge_wind_up: bool = false
@export var charge_color: Color = Color(0.3, 1.0, 0.4)
## Must be well above 1.0 or the tint is lost against an already-green sprite.
@export var charge_glow_intensity: float = 2.4
@export var aura_start_radius: float = 26.0
@export var aura_end_radius: float = 72.0

## Green's charge and release. Blue and red cast silently - green is the one the
## player has to hear coming.
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


## The authored interval, tightened by the arena's difficulty ramp. Floored so
## the ramp can never collapse it to nothing.
func effective_cast_interval() -> float:
	return maxf(cast_interval * attack_interval_scale(), 0.35)


func _tick_casting(delta: float) -> void:
	_cast_timer += delta
	var interval := effective_cast_interval()
	# The wind-up is not scaled by the ramp - it is the player's read on the
	# attack. Clamped only so a heavily ramped interval cannot end up shorter
	# than its own telegraph, leaving the caster permanently winding up.
	var wind_up := minf(telegraph_time, interval * 0.8)

	if not _telegraphing and _cast_timer >= interval - wind_up:
		_telegraphing = true
		if charge_wind_up:
			_start_charge_glow(wind_up)
		else:
			telegraph(1.25, wind_up, 0.1)

	if _cast_timer >= interval:
		_cast_timer = 0.0
		_telegraphing = false
		_fire_projectiles()


## Builds the aura and brightens the caster across the whole charge, so "about
## to fire" gets progressively louder instead of popping on at the end.
func _start_charge_glow(duration: float) -> void:
	# The charge is this caster's wind-up, so it owns the art swap too.
	show_attacking(duration)
	SoundManager.play_sfx(CHARGE_SOUND, 0, 0.55, 0.7, -5.0)
	if _aura != null and is_instance_valid(_aura):
		_aura.queue_free()
	_aura = ChargeAura.start(self, aura_start_radius, aura_end_radius,
		duration, charge_color)

	if _sprite == null:
		return
	# Overbright, not just "green": the sprite is already green, so brightness is
	# the only part of the tint that reads.
	var lit := charge_color * charge_glow_intensity
	lit.a = _base_modulate.a
	create_tween().tween_property(_sprite, "modulate", lit, duration)


func _end_charge_glow() -> void:
	if _aura != null and is_instance_valid(_aura):
		_aura.release()
		_aura = null

	if _sprite == null:
		return
	# current_modulate(), not _base_modulate: a caster chilled mid-charge must
	# still look chilled when the glow drops.
	create_tween().tween_property(_sprite, "modulate", current_modulate(), 0.15)


func _on_death() -> void:
	# Don't leave an aura floating where the caster used to be.
	if _aura != null and is_instance_valid(_aura):
		_aura.queue_free()
		_aura = null


func _fire_projectiles() -> void:
	# Before the bail below: a caster that loses its player mid-charge must not
	# be left lit up forever.
	if charge_wind_up:
		_end_charge_glow()

	if projectile_scene == null or not has_player():
		return

	# Paired with the hum from _start_charge_glow so the two read as one rising
	# cue. Only for casters that charge; blue and red stay silent.
	if charge_wind_up:
		SoundManager.play_sfx(CHARGE_SOUND, 0, 0.8, 0.95, -1.0)

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
