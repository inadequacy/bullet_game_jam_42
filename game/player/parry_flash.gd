extends Node2D
class_name ParryFlash

## Expanding ring drawn at the parry burst radius - the visual confirmation that
## a parry landed. Created in code and frees itself; no scene needed.
##
##     ParryFlash.burst(get_parent(), global_position, burst_radius)
##
## This ring is a PROMISE: everything it covers is destroyed. movement.gd holds
## its clear field open for exactly `duration` at exactly `to_radius`, so pass
## both from the same values the burst itself used - a ring that outlives or
## outgrows the field is a ring that visibly sweeps over survivors.

@export var color: Color = Color(0.45, 1.0, 0.55)
## Floor on the stroke, so a tiny burst still draws a visible line.
@export var width: float = 4.0
## Stroke thickness as a fraction of the final radius. A burst grown by cards
## should read as HEAVIER and not merely wider - at a fixed stroke a 40% larger
## ring looks about the same, which is what made the upgrade feel like it had not
## applied. 0.025 reproduces the original 4px at the default 160 radius.
@export var width_ratio: float = 0.025

var radius: float = 0.0:
	set(value):
		radius = value
		queue_redraw()

var alpha: float = 1.0:
	set(value):
		alpha = value
		queue_redraw()


## Spawns a ring that expands to `to_radius` while fading, then frees itself.
##
## `peak_alpha` is what it fades FROM. A parry that landed draws at full
## strength; a window that closed empty draws the same ring fainter, so the two
## outcomes are told apart by how loud the ring is rather than by its presence.
static func burst(parent: Node, at: Vector2, to_radius: float,
		duration: float = 0.28, peak_alpha: float = 1.0) -> ParryFlash:
	var flash := ParryFlash.new()
	parent.add_child(flash)
	flash.global_position = at
	flash.width = maxf(to_radius * flash.width_ratio, flash.width)
	# Start part-grown so the ring reads as a shockwave, not a dot.
	flash.radius = to_radius * 0.3
	flash.alpha = peak_alpha

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
