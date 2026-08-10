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
##
## Each colour also upgrades at fixed points in the run - see the Escalation
## group. Unlike the arena's sliding ramps these step, on purpose: a colour
## learning a new trick is meant to be a moment the player notices.
##
##   BLUE  - 1 shot, then 2 at 30%, then 3 - one down the middle - at 60%.
##   GREEN - fires twice as often from 50%.
##   RED   - one heavy homing shot, then two smaller ones in succession at 50%.

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

@export_group("Escalation")
## Fractions of the run at which this caster gains its next upgrade, ascending.
## Left empty it fights the same way from the first second to the last.
##
## These pick the tier every array below is read at: tier 0 is the authored
## opening, tier 1 what it becomes past the first fraction, and so on. A tier
## array shorter than the tier asked for holds its last entry, so a colour only
## has to write the values that actually change.
@export var upgrade_at: Array[float] = []
## Projectiles per cast, per tier. Empty leaves projectiles_per_cast alone.
@export var tier_projectiles: Array[int] = []
## Casting rate per tier, as a multiple of the authored one - 2.0 fires twice as
## often. Multiplies with the arena's own attack ramp rather than replacing it.
@export var tier_fire_rate: Array[float] = []
## Volleys per cast, per tier. Above one they leave the staff one after another
## instead of together, which is what makes a burst read as a burst.
@export var tier_burst_shots: Array[int] = []
## Seconds between the volleys of a burst. Short enough to arrive as one attack,
## long enough that the player can see two things coming rather than one.
@export var burst_interval: float = 0.18
## Projectile size per tier, as a multiple of the colour's normal size. What lets
## an upgrade trade one heavy shot for several lighter ones.
@export var tier_projectile_scale: Array[float] = []

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
## Volleys of the current burst still owed, and the countdown to the next one.
var _burst_left: int = 0
var _burst_timer: float = 0.0
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


# --- Escalation --------------------------------------------------------------

## Which upgrade this caster has reached, counted off the run clock. Read live
## rather than latched, so a caster that spawns late arrives already upgraded and
## one alive across a threshold gains the upgrade with it.
func tier() -> int:
	var progress := run_progress()
	var reached := 0
	for fraction in upgrade_at:
		if progress >= fraction:
			reached += 1
	return reached


## `values` at the current tier, holding its last entry once the tier runs past
## the end of it. `fallback` covers the colours that never wrote the array.
func _tier_int(values: Array[int], fallback: int) -> int:
	if values.is_empty():
		return fallback
	return values[mini(tier(), values.size() - 1)]


func _tier_float(values: Array[float], fallback: float) -> float:
	if values.is_empty():
		return fallback
	return values[mini(tier(), values.size() - 1)]


# --- Casting -----------------------------------------------------------------

## The authored interval, tightened by this tier's fire rate and then by the
## arena's difficulty ramp. Floored so neither can collapse it to nothing.
func effective_cast_interval() -> float:
	var rate := maxf(_tier_float(tier_fire_rate, 1.0), 0.05)
	return maxf(cast_interval * attack_interval_scale() / rate, 0.35)


func _tick_casting(delta: float) -> void:
	# A burst runs on its own clock, alongside the wind-up for the next cast.
	if _burst_left > 0:
		_burst_timer -= delta
		if _burst_timer <= 0.0:
			_burst_timer = burst_interval
			_burst_left -= 1
			_fire_volley()

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


## One cast: the first volley now, and the rest of the burst - if this tier has
## one - queued behind it.
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

	_burst_left = maxi(_tier_int(tier_burst_shots, 1) - 1, 0)
	_burst_timer = burst_interval
	_fire_volley()


## A single spread, re-aimed at where the player is right now - so the later
## volleys of a burst track a player who moved off the first one.
func _fire_volley() -> void:
	if projectile_scene == null or not has_player():
		return

	var count := maxi(_tier_int(tier_projectiles, projectiles_per_cast), 1)
	var size_scale := _tier_float(tier_projectile_scale, 1.0)
	var base_angle := direction_to_player().angle()
	var spread := deg_to_rad(spread_degrees)

	for i in count:
		# Spread evenly across the arc, centred on the player. An odd count puts
		# one straight down the middle and the rest either side of it.
		var offset := 0.0
		if count > 1:
			offset = (float(i) / float(count - 1) - 0.5) * spread

		var projectile := projectile_scene.instantiate() as EnemyProjectile
		# Set these before the node enters the tree - _ready() reads them to
		# colour and size the shot.
		projectile.kind = projectile_kind
		projectile.size_scale = size_scale
		if projectile_speed > 0.0:
			projectile.speed = projectile_speed
		# Parent to the scene, not the caster, so shots don't inherit its motion.
		get_tree().current_scene.add_child(projectile)
		projectile.launch(global_position, Vector2.RIGHT.rotated(base_angle + offset))
