extends Node2D
class_name HitscanTrace

## The green caster's shot: a bright streak that travels from the caster to the
## point the player occupied when it fired.
##
## It is FAST - fast enough that reacting to the streak itself is not possible -
## but it is not instant, so the shot is visible in flight. The reaction window
## is the caster's charge aura, not this.
##
## Damage and parry resolve on ARRIVAL, not on firing. That gives the parry its
## natural timing: the player commits during the charge, and the shot lands a
## moment later.

## Pixels per second. ~2200 crosses a typical 400px gap in under 0.2s.
var speed: float = 2200.0
## Length of the visible streak. Shorter reads as a bolt, longer as a beam.
var length: float = 140.0
var width: float = 3.0
var color: Color = Color(0.35, 1.0, 0.45)
var damage: float = 1.0
var fade_time: float = 0.1

var _direction: Vector2 = Vector2.RIGHT
var _distance: float = 0.0
var _travelled: float = 0.0
var _resolved: bool = false


## Fires a streak from `from` toward `to`. The target point is fixed at fire
## time - green is a committed shot, answered by parrying, not by dodging.
static func fire(parent: Node, from: Vector2, to: Vector2, trace_color: Color,
		trace_speed: float, trace_length: float, trace_width: float,
		trace_damage: float) -> HitscanTrace:
	var trace := HitscanTrace.new()
	trace.color = trace_color
	trace.speed = maxf(trace_speed, 1.0)
	trace.length = trace_length
	trace.width = trace_width
	trace.damage = trace_damage
	trace.z_index = 10
	parent.add_child(trace)

	trace.global_position = from
	trace._direction = from.direction_to(to)
	trace._distance = from.distance_to(to)
	if trace._distance <= 0.0:
		trace._direction = Vector2.RIGHT
	return trace


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

	var player := get_tree().get_first_node_in_group("player")
	if player != null and is_instance_valid(player):
		# A parry that is already active eats the shot whole.
		var parried := false
		if player.has_method("try_parry_hitscan"):
			parried = player.try_parry_hitscan(global_position)
		if not parried and player.has_method("take_damage"):
			player.take_damage(damage)

	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, fade_time)
	tween.tween_callback(queue_free)


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
