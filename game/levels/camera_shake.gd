extends Camera2D
class_name CameraShake

## Screen shake, kept deliberately subtle. Joins the "camera_shake" group so
## anything can trigger it without holding a reference:
##
##     var cam := get_tree().get_first_node_in_group("camera_shake")
##     if cam != null:
##         cam.shake()
##
## The camera sits still at the centre of the fixed arena - it exists only so
## there is something to shake.

## Pixels of offset at the very start of a shake. Small on purpose: a parry
## should feel like a thump, not an earthquake.
@export var default_strength: float = 3.0
@export var default_duration: float = 0.18
## Higher values make the shake die away faster. 1.0 is linear.
@export var falloff: float = 2.0

var _strength: float = 0.0
var _duration: float = 0.0
var _time_left: float = 0.0


func _ready() -> void:
	add_to_group("camera_shake")


## Negative arguments fall back to the exported defaults.
func shake(strength: float = -1.0, duration: float = -1.0) -> void:
	if strength < 0.0:
		strength = default_strength
	if duration < 0.0:
		duration = default_duration

	# A weaker shake must not cut a stronger one short.
	if _time_left > 0.0 and strength < _strength:
		return

	_strength = strength
	_duration = maxf(duration, 0.01)
	_time_left = _duration


func _process(delta: float) -> void:
	if _time_left <= 0.0:
		if offset != Vector2.ZERO:
			offset = Vector2.ZERO
		return

	_time_left -= delta
	if _time_left <= 0.0:
		offset = Vector2.ZERO
		return

	var remaining := clampf(_time_left / _duration, 0.0, 1.0)
	var amount := _strength * pow(remaining, falloff)
	offset = Vector2(randf_range(-amount, amount), randf_range(-amount, amount))
