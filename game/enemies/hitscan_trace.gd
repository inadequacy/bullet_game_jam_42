extends Node2D
class_name HitscanTrace

## The green caster's shot: a bright streak that travels from the caster to the
## point the player occupied when it fired.
##
## Damage and parry both resolve when it ARRIVES, and both are gated on where the
## player is at that moment:
##
##   IN the impact - within hit_radius of the aimed point - it hurts, unless a
##                   parry is active.
##   OUT of it     - nothing at all. The beam lands where it was aimed and the
##                   player has already left.
##
## The second case is the whole point of the range check. This used to damage the
## player wherever they were standing, so a beam that visibly fell short still
## took a heart off them.
##
## The streak is deliberately slow enough to be seen crossing the gap, because
## the parry is only allowed to start once it is out - see
## movement.gd's try_parry_hitscan. Flight time IS the reaction window.

## Pixels per second. ~1200 crosses a typical 300px gap in a quarter second.
var speed: float = 1200.0
## Length of the visible streak. Shorter reads as a bolt, longer as a beam.
var length: float = 140.0
var width: float = 3.0
var color: Color = Color(0.35, 1.0, 0.45)
var damage: float = 1.0
## How close to the aimed point the player must still be to be hit by this.
var hit_radius: float = 40.0
var fade_time: float = 0.1

## When this shot went out, in engine milliseconds. Handed to the player's parry
## check, which refuses any parry window that was opened before it - a shot
## cannot be answered before it exists.
var fired_at_ms: int = 0

var _direction: Vector2 = Vector2.RIGHT
var _distance: float = 0.0
var _travelled: float = 0.0
var _resolved: bool = false


## Fires a streak from `from` toward `to`. The target point is fixed at fire
## time - green is a committed shot, so the streak goes where it was pointed
## whatever the player does next.
static func fire(parent: Node, from: Vector2, to: Vector2, trace_color: Color,
		trace_speed: float, trace_length: float, trace_width: float,
		trace_damage: float, trace_hit_radius: float = 40.0) -> HitscanTrace:
	var trace := HitscanTrace.new()
	trace.color = trace_color
	trace.speed = maxf(trace_speed, 1.0)
	trace.length = trace_length
	trace.width = trace_width
	trace.damage = trace_damage
	trace.hit_radius = trace_hit_radius
	trace.fired_at_ms = Time.get_ticks_msec()
	trace.z_index = 10
	parent.add_child(trace)

	trace.global_position = from
	trace._direction = from.direction_to(to)
	trace._distance = from.distance_to(to)
	if trace._distance <= 0.0:
		trace._direction = Vector2.RIGHT
	return trace


## Where the streak actually ends, in world space.
##
## NOT `global_position` - this node stays parked at the muzzle for its whole
## life and draws the streak as an offset line, so its own position is the
## CASTER's, not the impact. Measuring the player against that would have made
## the range check "are you near the caster", which is the opposite of the test.
func impact_point() -> Vector2:
	return global_position + _direction * _distance


func _physics_process(delta: float) -> void:
	if _resolved:
		return
	_travelled += speed * delta
	queue_redraw()
	if _travelled >= _distance:
		_travelled = _distance
		_resolve()


func _resolve() -> void:
	_resolved = true
	_strike_impact_point()

	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, fade_time)
	tween.tween_callback(queue_free)


## Everything the arrival does. Split out so the ORDER is explicit: miss first,
## then parry, then damage - a shot that never reached the player must not spend
## their parry window either.
func _strike_impact_point() -> void:
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null or not is_instance_valid(player):
		return

	var impact := impact_point()
	if player.global_position.distance_to(impact) > hit_radius:
		return

	# A parry that is already active eats the shot whole.
	if player.has_method("try_parry_hitscan") \
			and player.try_parry_hitscan(impact, fired_at_ms):
		return
	if player.has_method("take_damage"):
		player.take_damage(damage)


func _draw() -> void:
	var head := minf(_travelled, _distance)
	var tail := maxf(head - length, 0.0)
	if head <= tail:
		return

	var head_point := _direction * head
	var tail_point := _direction * tail

	# Wide dim pass underneath a thin bright core - cheap glow.
	draw_line(tail_point, head_point,
		Color(color.r, color.g, color.b, 0.28), width * 3.0, true)
	draw_line(tail_point, head_point, color, width, true)
