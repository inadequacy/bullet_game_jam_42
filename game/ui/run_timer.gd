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

## The arena, which owns the clock. format_time_left is what proves it.
var _clock_ref := GroupRef.new("run_clock", "format_time_left")


func _process(_delta: float) -> void:
	var clock := _clock_ref.resolve(self)
	if clock == null:
		return
	text = clock.format_time_left()
	modulate = warn_color if clock.time_left() <= warn_below else normal_color
