class_name UltFrozenGround
extends Node2D

## THE ICE ULTIMATE. A pool of ice centred on where the player stood, holding
## everything inside it FULLY FROZEN - not slowed, stopped.
##
##     UltFrozenGround.cast(level, player.global_position, radius, duration, freeze)
##
## Control rather than damage, which is the ice school's whole identity: the
## other two ultimates kill things, this one takes the fight away from the enemy
## and hands the player the arena for a few seconds.
##
## The pool is PLACED, not carried. It stays where it was cast, so dropping it is
## a decision about ground rather than a button that follows you around - and the
## player can walk out of their own pool to reposition while the enemies cannot.

## How often enemies inside are re-frozen. The freeze itself lasts far longer
## than this, so the refresh is what catches anything that wanders in later.
const REFRESH_INTERVAL := 0.25

var radius: float = 260.0
var duration: float = 3.0
## How long a caught enemy stays frozen once the pool releases it.
var freeze_duration: float = 3.0

var _left: float = 0.0
var _refresh: float = 0.0
var _alpha: float = 0.0
## Grows in over a beat, so the pool spreads rather than popping into existence.
var _shown_radius: float = 0.0


static func cast(parent: Node, where: Vector2, pool_radius: float,
		length: float, freeze: float) -> UltFrozenGround:
	var pool := UltFrozenGround.new()
	pool.radius = pool_radius
	pool.duration = length
	pool.freeze_duration = freeze
	parent.add_child(pool)
	pool.global_position = where
	return pool


func _ready() -> void:
	# Under the fighters - this is ground, and it must not hide the enemies
	# standing frozen on it. Requires level.tscn's Background to stay at
	# z_index -10; at 0 the floor draws over the pool and it vanishes.
	z_index = -4
	_left = duration
	_freeze_everything_inside()

	var tween := create_tween().set_parallel(true)
	tween.tween_method(_set_shown_radius, radius * 0.15, radius, 0.25) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_method(_set_alpha, 0.0, 1.0, 0.18)


func _set_shown_radius(value: float) -> void:
	_shown_radius = value
	queue_redraw()


func _set_alpha(value: float) -> void:
	_alpha = value
	queue_redraw()


func _process(delta: float) -> void:
	_left -= delta
	if _left <= 0.0:
		_finish()
		return

	_refresh -= delta
	if _refresh <= 0.0:
		_refresh = REFRESH_INTERVAL
		_freeze_everything_inside()


func _finish() -> void:
	set_process(false)
	var tween := create_tween()
	tween.tween_method(_set_alpha, _alpha, 0.0, 0.35)
	tween.tween_callback(queue_free)


## Everything standing on the ice is frozen for freeze_duration. Enemy.apply_freeze
## takes the LONGER of the two, so refreshing never cuts an existing freeze short.
func _freeze_everything_inside() -> void:
	for e in get_tree().get_nodes_in_group("enemies"):
		var enemy := e as Enemy
		if enemy == null or not is_instance_valid(enemy) \
				or enemy.is_queued_for_deletion():
			continue
		if enemy.is_entering():
			continue
		if enemy.global_position.distance_to(global_position) > radius:
			continue
		enemy.apply_freeze(freeze_duration)


func _draw() -> void:
	if _alpha <= 0.0 or _shown_radius <= 0.0:
		return

	# Body: a pale sheet of ice, solid enough to read as ground.
	draw_circle(Vector2.ZERO, _shown_radius, Color(0.45, 0.78, 0.95, 0.26 * _alpha))
	draw_circle(Vector2.ZERO, _shown_radius * 0.72,
		Color(0.62, 0.88, 1.0, 0.16 * _alpha))

	# Rim: where the freeze stops, drawn hard so the edge is unambiguous.
	draw_arc(Vector2.ZERO, _shown_radius, 0.0, TAU, 64,
		Color(0.85, 0.97, 1.0, 0.9 * _alpha), maxf(_shown_radius * 0.02, 3.0), true)

	# A few facets, so the pool reads as ice rather than as a blue puddle.
	for i in 6:
		var a := TAU * float(i) / 6.0
		var edge := Vector2.RIGHT.rotated(a) * _shown_radius
		draw_line(edge * 0.35, edge * 0.92,
			Color(0.9, 0.98, 1.0, 0.22 * _alpha), 2.0, true)
