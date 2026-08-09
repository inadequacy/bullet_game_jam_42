class_name SpellBurst
extends Node2D

## Expanding filled disc with a bright rim - a Fire explosion. Created in code
## and frees itself.
##
##     SpellBurst.at(get_parent(), global_position, radius)
##
## Same contract as ParryFlash: what the circle covers is what the effect hit.
## player_projectile.gd damages everything inside `radius` on the frame this is
## spawned at that radius, so picture and damage cannot disagree.

@export var color: Color = Color(1.0, 0.45, 0.15)
## Stroke of the rim as a fraction of the final radius, so a blast grown by
## cards reads as heavier rather than merely wider. Same trick as ParryFlash.
@export var rim_ratio: float = 0.06

## Additive, so the burst brightens what is under it instead of covering it -
## an explosion must never hide the enemies it is going off around.
func _init() -> void:
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = mat


var radius: float = 0.0:
	set(value):
		radius = value
		queue_redraw()

var alpha: float = 1.0:
	set(value):
		alpha = value
		queue_redraw()


## Spawns a disc that snaps open to `to_radius` while fading, then frees itself.
static func at(parent: Node, where: Vector2, to_radius: float,
		tint: Color = Color(1.0, 0.45, 0.15), duration: float = 0.32) -> SpellBurst:
	var burst := SpellBurst.new()
	parent.add_child(burst)
	burst.global_position = where
	burst.color = tint
	# Starts over half grown: an explosion is already happening when you see it,
	# where a shockwave ring travels outward from a point.
	burst.radius = to_radius * 0.55

	var tween := burst.create_tween().set_parallel(true)
	tween.tween_property(burst, "radius", to_radius, duration) \
		.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tween.tween_property(burst, "alpha", 0.0, duration) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_callback(burst.queue_free).set_delay(duration)
	return burst


## Rings used to fake a radial falloff. draw_circle cannot take a gradient, but
## additive blending gives one for free: stack shrinking discs of low alpha and
## the contributions pile up toward the middle, so the centre burns white-hot
## and the edge fades out. Any fewer rings and the steps band visibly.
const GLOW_STEPS := 18


func _draw() -> void:
	if alpha <= 0.0:
		return

	for i in GLOW_STEPS:
		# Outermost first. Each ring is hotter than the last, so the colour
		# climbs from the ember tint toward near-white at the core.
		var t := float(i) / float(GLOW_STEPS - 1)
		var ring := color.lerp(Color(1.0, 0.95, 0.75), t * 0.85)
		ring.a = alpha * 0.055
		draw_circle(Vector2.ZERO, radius * (1.0 - t * 0.82), ring)

	# The rim is the promise: this circle is exactly what the blast damaged.
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 48,
		Color(1.0, 0.88, 0.55, alpha), maxf(radius * rim_ratio, 3.0), true)
