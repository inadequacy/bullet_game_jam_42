class_name UltFireRain
extends Node2D

## The fire ultimate. The screen washes red, flame rains across the whole of it,
## the camera shakes, and every enemy on screen burns.
##
##     UltFireRain.cast(level, damage_per_tick, duration)
##
## No aiming and no dodging - fire is area, so its ultimate is the whole arena
## at once.

const FLAME_TEXTURE := preload("res://assets/images/flame.svg")

## The roar, held for the whole ultimate. A seamless two second loop, looped by
## SoundManager.make_looping() rather than by the import, so it covers whatever
## duration a card stretches this to.
const ROAR_SOUND := preload("res://assets/sounds/ultimate_fire1.wav")
## Under the effects it plays over - it is a bed, not a hit.
const ROAR_VOLUME_DB := -8.0

## Its own player rather than SoundManager's pool, which round robins its voices
## and cannot stop a sustained sound. Parented here, so it cannot outlive the
## fire.
var _roar: AudioStreamPlayer

## Seconds between damage ticks. Every enemy takes `damage` on each one, so the
## total is roughly duration/DAMAGE_INTERVAL times it.
const DAMAGE_INTERVAL := 0.35
## New flames per second. High enough that the screen reads as a downpour.
const FLAMES_PER_SECOND := 48.0
const FALL_SPEED := Vector2(760.0, 1150.0)
const FLAME_SCALE := Vector2(0.30, 0.62)
## Flames are stretched along their fall, which reads as speed rather than as a
## sprite dropping down the screen.
const FLAME_STRETCH := 1.35
## The colour the arena floor is multiplied by at the peak of the pulse, and how
## far toward it the pulse goes. Multiplied rather than added or alpha blended,
## so it turns whatever is underneath red regardless of the background art.
const WASH_TINT := Color(1.0, 0.24, 0.16)
const WASH_STRENGTH := 0.88

## Multiplying can only take light away, so dark art would just go brown. This
## additive layer puts red light back in, and the two together read as red on a
## pale floor and a dark one alike.
const GLOW_COLOR := Color(0.95, 0.11, 0.04)
const GLOW_ALPHA := 0.30

var _glow: ColorRect
const SHAKE_STRENGTH := 2.6

var damage: float = 8.0
var duration: float = 3.0

var _left: float = 0.0
var _damage_tick: float = 0.0
var _flame_debt: float = 0.0
## The arena in world space, measured once at cast.
var _area: Rect2
var _wash: float = 0.0


## Fires the ultimate. `parent` should be the level, so the effect outlives the
## player's own node and sits under the HUD rather than over it.
static func cast(parent: Node, damage_per_tick: float,
		length: float) -> UltFireRain:
	var rain := UltFireRain.new()
	rain.damage = damage_per_tick
	rain.duration = length
	parent.add_child(rain)
	return rain


func _ready() -> void:
	# Behind the enemies and the player, so the wash never hides the fight going
	# on inside it. Requires the level background below this - level.tscn's
	# Background sprite is pinned to z_index -10 for that reason.
	z_index = -5
	# Multiply, so the floor is tinted red rather than having red added on top of
	# it. Only affects this node's own _draw; the flame children carry their own
	# material and stay bright.
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_MUL
	material = mat
	_left = duration
	_area = _arena_bounds()
	_build_glow()
	_start_roar()
	# One damage tick lands immediately, so the cast bites the moment it goes off.
	_burn_everything()
	_damage_tick = DAMAGE_INTERVAL


## The additive half of the wash. A ColorRect rather than more _draw calls: a
## CanvasItem gets one blend mode, and this node's is already the multiply.
## Added before any flame, so the flames draw on top of it.
func _build_glow() -> void:
	_glow = ColorRect.new()
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_glow.material = mat
	_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var r := _area.grow(200.0)
	_glow.position = r.position
	_glow.size = r.size
	_glow.color = Color(GLOW_COLOR.r, GLOW_COLOR.g, GLOW_COLOR.b, 0.0)
	add_child(_glow)


## Brought up over a beat rather than started at full volume, so the fire builds
## the way the wash does instead of the roar snapping on ahead of the visuals.
func _start_roar() -> void:
	_roar = AudioStreamPlayer.new()
	_roar.stream = SoundManager.make_looping(ROAR_SOUND)
	_roar.volume_db = ROAR_VOLUME_DB - 12.0
	add_child(_roar)
	_roar.play()
	create_tween().tween_property(_roar, "volume_db", ROAR_VOLUME_DB, 0.35)


func _process(delta: float) -> void:
	_left -= delta

	# Pulses rather than holding steady, but only between "red" and "very red" -
	# a trough that reached zero would look like the ultimate flickering out.
	_wash = 0.78 + 0.22 * sin(Time.get_ticks_msec() * 0.012)
	if _glow != null:
		_glow.color.a = GLOW_ALPHA * _wash
	queue_redraw()

	_spawn_flames(delta)
	_shake()

	_damage_tick -= delta
	if _damage_tick <= 0.0 and _left > 0.0:
		_damage_tick = DAMAGE_INTERVAL
		_burn_everything()

	if _left <= 0.0:
		_finish()


## Fades the wash out and lets the flames still in the air finish falling, so
## the effect ends rather than being cut off mid-frame.
func _finish() -> void:
	set_process(false)
	var tween := create_tween()
	tween.tween_method(_fade_wash, _wash, 0.0, 0.4)
	tween.tween_callback(queue_free).set_delay(0.6)

	# Faded over the whole tail rather than cut with the wash - there is still
	# fire in the air for another half second after the tint has gone.
	if _roar != null:
		create_tween().tween_property(_roar, "volume_db", -50.0, 0.9)


## Both halves of the wash have to fade together, or the additive glow would be
## left hanging on screen after the multiply had gone.
func _fade_wash(value: float) -> void:
	_wash = value
	if _glow != null:
		_glow.color.a = GLOW_ALPHA * value
	queue_redraw()


func _burn_everything() -> void:
	for e in get_tree().get_nodes_in_group("enemies"):
		var enemy := e as Enemy
		if enemy == null or not is_instance_valid(enemy) \
				or enemy.is_queued_for_deletion():
			continue
		# The fire falls on the screen, so it burns what is on the screen -
		# including a wave that walked in after the cast. See Enemy.is_on_screen,
		# and do not go back to asking is_entering() here.
		if not enemy.is_on_screen():
			continue
		enemy.take_damage(damage)


func _shake() -> void:
	var camera := get_tree().get_first_node_in_group("camera_shake")
	if camera != null and camera.has_method("shake"):
		# Short and constantly renewed, so it rumbles for the whole duration
		# instead of one thump at the start.
		camera.shake(SHAKE_STRENGTH, 0.25)


## Flames are plain Sprite2Ds that fall and free themselves - no pooling, since
## a three second ultimate spawns fewer than a hundred of them.
func _spawn_flames(delta: float) -> void:
	if _left <= 0.0:
		return
	_flame_debt += FLAMES_PER_SECOND * delta
	while _flame_debt >= 1.0:
		_flame_debt -= 1.0
		_drop_one_flame()


func _drop_one_flame() -> void:
	var flame := Sprite2D.new()
	flame.texture = FLAME_TEXTURE
	var size := randf_range(FLAME_SCALE.x, FLAME_SCALE.y)
	flame.scale = Vector2(size, size * FLAME_STRETCH)
	# Left pointing up, trailing off something falling, rather than turned to
	# face its travel - which would read as falling rockets.
	flame.rotation = randf_range(-0.22, 0.22)
	# The art already carries its colour; modulate only varies the heat a little
	# and thins the smaller ones so the rain has depth.
	flame.modulate = Color(1.0, randf_range(0.85, 1.0), randf_range(0.8, 1.0),
		randf_range(0.7, 1.0))
	flame.position = Vector2(
		randf_range(_area.position.x, _area.end.x),
		_area.position.y - randf_range(40.0, 260.0))
	add_child(flame)

	var fall := randf_range(FALL_SPEED.x, FALL_SPEED.y)
	var travel := _area.end.y + 120.0 - flame.position.y
	var tween := flame.create_tween().set_parallel(true)
	tween.tween_property(flame, "position:y", _area.end.y + 120.0,
		travel / fall)
	tween.tween_property(flame, "modulate:a", 0.0, travel / fall) \
		.set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(flame.queue_free)


## The visible world rect. Read off the canvas transform rather than assuming
## 1152x648, the same way level.gd finds its spawn edges.
func _arena_bounds() -> Rect2:
	var to_world := get_canvas_transform().affine_inverse()
	var screen := get_viewport_rect()
	return Rect2(to_world * screen.position, to_world.basis_xform(screen.size))


func _draw() -> void:
	if _wash <= 0.0:
		return
	# Generous margin so the wash still covers the screen while it is shaking.
	# White multiplies to no change, so the pulse rides between untouched and
	# WASH_TINT rather than fading a red rect in and out.
	var r := _area.grow(200.0)
	draw_rect(r, Color.WHITE.lerp(WASH_TINT, WASH_STRENGTH * _wash))
