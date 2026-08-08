extends Node2D
class_name ParryFlash

## Expanding ring drawn at the parry burst radius - the visual confirmation that
## a parry landed. Created in code and frees itself; no scene needed.
##
##     ParryFlash.burst(get_parent(), global_position, burst_radius)

@export var color: Color = Color(0.45, 1.0, 0.55)
@export var width: float = 4.0

var radius: float = 0.0:
	set(value):
		radius = value
		queue_redraw()

var alpha: float = 1.0:
	set(value):
		alpha = value
		queue_redraw()


## Spawns a ring that expands to `to_radius` while fading, then frees itself.
static func burst(parent: Node, at: Vector2, to_radius: float,
		duration: float = 0.28) -> ParryFlash:
	var flash := ParryFlash.new()
	parent.add_child(flash)
	flash.global_position = at
	# Start part-grown so the ring reads as a shockwave, not a dot.
	flash.radius = to_radius * 0.3

	var tween := flash.create_tween().set_parallel(true)
	tween.tween_property(flash, "radius", to_radius, duration) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(flash, "alpha", 0.0, duration)
	tween.tween_callback(flash.queue_free).set_delay(duration)
	return flash


func _draw() -> void:
	if alpha <= 0.0:
		return
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 48,
		Color(color.r, color.g, color.b, alpha), width, true)
