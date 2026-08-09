extends Node2D
class_name ChargeAura

## The aura a charging caster builds. Grows in radius and opacity across the
## whole charge, so "about to fire" is readable at a glance and gets louder the
## closer the shot is.
##
## Parented to the caster so it follows it, drawn behind the sprite.

var color: Color = Color(0.35, 1.0, 0.45)

var radius: float = 0.0:
	set(value):
		radius = value
		queue_redraw()

var alpha: float = 0.0:
	set(value):
		alpha = value
		queue_redraw()


## Starts an aura that swells over `duration`. Keep the returned reference and
## call release() when the shot goes off.
static func start(host: Node2D, from_radius: float, to_radius: float,
		duration: float, aura_color: Color) -> ChargeAura:
	var aura := ChargeAura.new()
	aura.color = aura_color
	aura.z_index = -1
	aura.radius = from_radius
	aura.alpha = 0.0
	host.add_child(aura)

	var tween := aura.create_tween().set_parallel(true)
	tween.tween_property(aura, "radius", to_radius, duration)
	tween.tween_property(aura, "alpha", 1.0, duration)
	return aura


## Snaps bright for an instant then fades - the visual "discharge".
func release(fade_time: float = 0.18) -> void:
	var tween := create_tween().set_parallel(true)
	tween.tween_property(self, "radius", radius * 1.35, fade_time)
	tween.tween_property(self, "alpha", 0.0, fade_time)
	tween.tween_callback(queue_free).set_delay(fade_time)


func _draw() -> void:
	if alpha <= 0.0 or radius <= 0.0:
		return
	# Soft body plus a brighter rim, so it reads as a glow rather than a disc.
	draw_circle(Vector2.ZERO, radius, Color(color.r, color.g, color.b, alpha * 0.22))
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 48,
		Color(color.r, color.g, color.b, alpha * 0.8), 3.0, true)
