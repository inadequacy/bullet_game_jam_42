class_name HudStyle
extends RefCounted

## Shared paint for the HUD readouts. One place to set the shape, so bars spread
## across four corners of the screen still read as one instrument.

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
