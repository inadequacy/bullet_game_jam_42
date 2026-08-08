class_name UltFireRain
extends Node2D

## THE FIRE ULTIMATE. The screen washes red, flame rains across the whole of it,
## the camera shakes, and every enemy on screen burns.
##
##     UltFireRain.cast(level, damage_per_tick, duration)
##
## There is no aiming this and no dodging it - it is the whole arena at once.
## That is the point of the fire school's ultimate: fire is area, so its ultimate
## is the largest area there is.
##
## The falling flames are the same flame as the Fire card badge, minus the
## rounded square the badge draws it on - raining the badge itself looked like
## raining UI cards. See assets/images/flame.svg.

const FLAME_TEXTURE := preload("res://assets/images/flame.svg")

## Seconds between damage ticks. Every enemy takes `damage` on each one, so the
## total is roughly duration/DAMAGE_INTERVAL times it.
const DAMAGE_INTERVAL := 0.35
## New flames per second. High enough that the screen reads as a downpour -
## this is the ultimate, so it should be far too much fire.
const FLAMES_PER_SECOND := 48.0
const FALL_SPEED := Vector2(760.0, 1150.0)
const FLAME_SCALE := Vector2(0.30, 0.62)
## Flames are stretched along their fall, which reads as speed rather than as a
## sprite dropping down the screen.
const FLAME_STRETCH := 1.35
## How hard the arena is tinted at the peak of the pulse. Applied ADDITIVELY -
## see _ready - so the screen is lit red rather than covered in dark red, which
## is what alpha blending over a dark arena gave.
const WASH_ALPHA := 0.42
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
	# Behind the enemies and the player, so the wash never hides what is
	# happening in the fight it is going off around.
	z_index = -5
	# Additive, so the wash LIGHTS the arena red. Alpha blending a red rect over
	# a dark background just muddied everything to maroon. Only affects this
	# node's own _draw - the flame children carry their own colours.
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = mat
	_left = duration
	_area = _arena_bounds()
	# One damage tick lands immediately - a screen-wide ultimate that did
	# nothing for its first third of a second would feel like it had misfired.
	_burn_everything()
	_damage_tick = DAMAGE_INTERVAL


func _process(delta: float) -> void:
	_left -= delta

	# Pulses rather than holding steady, so the screen feels like it is roaring.
	_wash = 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.012)
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
	tween.tween_method(func(v: float): _wash = v; queue_redraw(), _wash, 0.0, 0.4)
	tween.tween_callback(queue_free).set_delay(0.6)


func _burn_everything() -> void:
	for e in get_tree().get_nodes_in_group("enemies"):
		var enemy := e as Enemy
		if enemy == null or not is_instance_valid(enemy) \
				or enemy.is_queued_for_deletion():
			continue
		# Enemies still walking in are off screen. The fire falls on the screen,
		# so hitting them would be hitting something the player cannot see.
		if enemy.is_entering():
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
	# Left pointing UP. Flipping it to point down the way it travels made the
	# flames read as falling rockets; a flame trailing upward off something
	# dropping is what fire actually looks like in the air.
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
	var r := _area.grow(200.0)
	draw_rect(r, Color(0.85, 0.12, 0.05, WASH_ALPHA * _wash))
