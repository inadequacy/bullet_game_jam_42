class_name HudStyle
extends RefCounted

## Shared paint for the HUD readouts.
##
## Every bar in the bottom strip used to roll its own StyleBoxFlat, and the three
## cooldown bars rolled none at all - they inherited the default theme, which is
## nearly the same grey as the panel they now sit on. One place to set the shape
## so the five readouts read as one instrument panel rather than five widgets.

## Corner rounding shared by every bar and pip.
const RADIUS := 4


## Gives `bar` a flat track and fill. Call once, from _ready().
static func paint_bar(bar: ProgressBar, track: Color, fill: Color) -> void:
	bar.add_theme_stylebox_override("background", _flat(track))
	bar.add_theme_stylebox_override("fill", _flat(fill))


static func _flat(color: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(RADIUS)
	return box
