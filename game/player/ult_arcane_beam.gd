class_name UltArcaneBeam
extends Node2D

## The arcane ultimate. A huge purple beam fired from the player, sweeping with
## them for as long as it lasts.
##
##     UltArcaneBeam.cast(player, damage_per_second, duration)
##
## Follows facing and ignores auto-aim - this is the one ultimate aimed by hand.
## As a child of the player at zero rotation it inherits the facing movement.gd
## applies, and never reads aim_angle(), which is what auto-aim changes.

## Long enough to leave the arena from any corner.
const LENGTH := 1600.0
## Half-width of the damage band. Generous, so the beam is not something to
## thread.
const HALF_WIDTH := 34.0
## Damage lands in bites rather than per frame, so it is frame-rate independent
## and the hit flashes read as pulses.
const DAMAGE_INTERVAL := 0.12

## The beam's hum, held for as long as the beam is out. A seamless two second
## loop, looped by SoundManager.make_looping() rather than by the import, so a
## card that extends the ultimate extends the sound too.
const BEAM_SOUND := preload("res://assets/sounds/ultimate_beam1.wav")
const BEAM_VOLUME_DB := -10.0

## Its own player rather than SoundManager's pool, which round robins its voices
## and cannot stop a sustained sound. Parented here, so it cannot outlive the
## beam.
var _hum: AudioStreamPlayer

var damage_per_second: float = 40.0
var duration: float = 3.0

var _left: float = 0.0
var _tick: float = 0.0
var _alpha: float = 0.0
## 0..1, how far the beam has opened. Drives width so it snaps out rather than
## simply appearing at full size.
var _open: float = 0.0


static func cast(player: Node2D, dps: float, length: float) -> UltArcaneBeam:
	var beam := UltArcaneBeam.new()
	beam.damage_per_second = dps
	beam.duration = length
	# Child of the player, at zero rotation, so the beam is the player's facing.
	player.add_child(beam)
	beam.position = Vector2.ZERO
	beam.rotation = 0.0
	return beam


func _ready() -> void:
	# Over the arena but below the HUD.
	z_index = 5
	_left = duration

	var tween := create_tween().set_parallel(true)
	tween.tween_method(_set_open, 0.0, 1.0, 0.14) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_method(_set_alpha, 0.0, 1.0, 0.1)

	# Rises with the beam opening, over the same 0.14s, so the two land together.
	_hum = AudioStreamPlayer.new()
	_hum.stream = SoundManager.make_looping(BEAM_SOUND)
	_hum.volume_db = BEAM_VOLUME_DB - 14.0
	add_child(_hum)
	_hum.play()
	create_tween().tween_property(_hum, "volume_db", BEAM_VOLUME_DB, 0.14)


func _set_open(value: float) -> void:
	_open = value
	queue_redraw()


func _set_alpha(value: float) -> void:
	_alpha = value
	queue_redraw()


func _process(delta: float) -> void:
	_left -= delta
	# Redrawn every frame regardless: the player is turning under it.
	queue_redraw()

	if _left <= 0.0:
		_finish()
		return

	_tick -= delta
	if _tick <= 0.0:
		_tick = DAMAGE_INTERVAL
		_burn_along_beam(damage_per_second * DAMAGE_INTERVAL)


func _finish() -> void:
	set_process(false)
	var tween := create_tween().set_parallel(true)
	tween.tween_method(_set_alpha, _alpha, 0.0, 0.18)
	tween.tween_method(_set_open, _open, 0.0, 0.18)
	if _hum != null:
		# On the same tween as the visuals, so the hum dies exactly as the beam
		# closes rather than being chopped off by the queue_free that follows.
		tween.tween_property(_hum, "volume_db", -50.0, 0.18)
	tween.chain().tween_callback(queue_free)


## Damages every enemy whose centre lies within HALF_WIDTH of the beam's line,
## in front of the player and inside LENGTH.
func _burn_along_beam(amount: float) -> void:
	var origin := global_position
	var forward := Vector2.RIGHT.rotated(global_rotation)

	for enemy in Enemy.living(self):
		# Anything the player can see standing in the beam.
		if not enemy.is_on_screen():
			continue

		var to_enemy := enemy.global_position - origin
		# Distance along the beam; negative means behind the player.
		var along := to_enemy.dot(forward)
		if along < 0.0 or along > LENGTH:
			continue
		if absf(to_enemy.cross(forward)) > HALF_WIDTH:
			continue
		enemy.take_damage(amount)


func _draw() -> void:
	if _alpha <= 0.0 or _open <= 0.0:
		return

	var half := HALF_WIDTH * _open
	# Layered outward-in, brightest at the core - the same additive trick
	# SpellBurst uses, so the two effects share a visual language.
	var layers := [
		[2.4, Color(0.45, 0.15, 0.85, 0.16 * _alpha)],
		[1.6, Color(0.60, 0.28, 0.95, 0.26 * _alpha)],
		[1.0, Color(0.78, 0.52, 1.00, 0.55 * _alpha)],
		[0.42, Color(0.98, 0.93, 1.00, 0.95 * _alpha)],
	]
	for layer in layers:
		var w: float = half * (layer[0] as float)
		draw_rect(Rect2(0.0, -w, LENGTH, w * 2.0), layer[1] as Color)

	# A flare at the muzzle, so the beam clearly comes out of the caster.
	draw_circle(Vector2.ZERO, half * 2.2, Color(0.75, 0.45, 1.0, 0.35 * _alpha))
	draw_circle(Vector2.ZERO, half * 1.1, Color(1.0, 0.95, 1.0, 0.8 * _alpha))
