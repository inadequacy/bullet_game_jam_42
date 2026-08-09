extends Label
class_name RunTimer

## The run countdown, in M:SS.
##
## Polls the level through the "run_clock" group rather than being wired to it,
## the same way DashBar and ParryBar find the player: the value changes every
## frame anyway, and the HUD stays independent of where the clock actually lives.
##
## Formatting belongs to the clock, not here - level.gd prints the same string to
## its logs, so the two can never disagree.

## Colour for most of the run.
@export var normal_color: Color = Color(0.92, 0.94, 1.0)
## Colour once the clock drops below warn_below.
@export var warn_color: Color = Color(1.0, 0.55, 0.45)
@export var warn_below: float = 60.0

var _clock: Node = null


func _process(_delta: float) -> void:
	var clock := _find_clock()
	if clock == null:
		return
	text = clock.format_time_left()
	modulate = warn_color if clock.time_left() <= warn_below else normal_color


func _find_clock() -> Node:
	if _clock != null and is_instance_valid(_clock):
		return _clock
	_clock = get_tree().get_first_node_in_group("run_clock")
	# Only drive this from something that actually keeps the time.
	if _clock != null and not _clock.has_method("format_time_left"):
		_clock = null
	return _clock
