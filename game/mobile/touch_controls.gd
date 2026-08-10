extends CanvasLayer

## On-screen controls for touch devices. A thumb stick on the left half of the
## screen, and a cluster of action buttons in the bottom right.
##
## Feeds the ordinary input actions, so nothing else in the game has to know it
## exists: the stick drives ui_left/right/up/down, and the buttons emit dash,
## parry, ultimate and pause. The one exception is facing - there is no mouse to
## look at on a phone - which movement.gd asks about through is_active().
##
## Shown when the device reports a touchscreen, then adjusted by what the player
## actually uses: any key press hides it, any touch brings it back. That covers
## touchscreen laptops and iPads, which report a desktop user agent and so
## cannot be told apart by platform alone.

## Stick directions, in the order _feed_stick writes them.
const STICK_ACTIONS := ["ui_left", "ui_right", "ui_up", "ui_down"]

@export_group("Stick")
## How far from the base the knob can travel, and so the throw of the stick.
@export var stick_radius: float = 90.0
@export var stick_knob_radius: float = 38.0
## Fraction of the throw that still counts as centred.
@export_range(0.0, 0.9, 0.01) var stick_dead_zone: float = 0.18
## Fraction of the screen width, measured from the left, where a touch plants
## the stick. The rest of the screen belongs to the buttons.
@export_range(0.1, 0.9, 0.05) var stick_area_ratio: float = 0.5

@export_group("Buttons")
@export var button_radius: float = 52.0
@export var menu_button_radius: float = 32.0
@export_group("")

@export_group("Look")
@export var idle_alpha: float = 0.26
@export var held_alpha: float = 0.55
@export var accent: Color = Color(0.55, 0.85, 1.0)
@export_group("")

## The cluster, as offsets from the bottom-right corner of the screen. Menu sits
## clear of the other three and is drawn smaller, so a panicked thumb reaching
## for Dash cannot pause the run by mistake.
const BUTTONS := [
	{"action": "dash", "label": "DASH", "offset": Vector2(-95.0, -95.0)},
	{"action": "parry", "label": "PARRY", "offset": Vector2(-215.0, -110.0)},
	{"action": "ultimate", "label": "ULT", "offset": Vector2(-110.0, -215.0)},
	{"action": "pause", "label": "MENU", "offset": Vector2(-62.0, -310.0), "small": true},
]

var _touch_mode: bool = false

## Touch index driving the stick, or -1. Tracked by index so the stick and a
## button can be held by different thumbs at once.
var _stick_index: int = -1
var _stick_base: Vector2 = Vector2.ZERO
var _stick_knob: Vector2 = Vector2.ZERO

## Button index -> the touch index holding it.
var _held: Dictionary = {}
## Stick actions currently pressed, so they can all be let go at once.
var _pressed: Dictionary = {}

var _player: Node = null

@onready var _overlay: Control = $Overlay


func _ready() -> void:
	# Runs while the tree is paused, so a stick held when the pause menu opens
	# can still be released - otherwise the player keeps walking on resume.
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("touch_controls")
	_set_touch_mode(DisplayServer.is_touchscreen_available())


## True while the touch controls are what the player is using. movement.gd reads
## this to decide whether facing follows the stick or the mouse.
func is_active() -> bool:
	return _touch_mode


## The overlay is up only when touch is in use and the game is actually running -
## the pause and card screens draw their own buttons.
func _is_live() -> bool:
	return _touch_mode and not get_tree().paused


func _process(_delta: float) -> void:
	var live := _is_live()
	if live != _overlay.visible:
		_overlay.visible = live
		if not live:
			_release_everything()
	if live:
		# The ultimate button carries a cooldown ring, so this redraws each frame.
		_overlay.queue_redraw()


func _set_touch_mode(on: bool) -> void:
	if _touch_mode == on:
		return
	_touch_mode = on
	if not on:
		_release_everything()


# --- Input -------------------------------------------------------------------

func _input(event: InputEvent) -> void:
	# Only a real key flips back to desktop. Mouse events cannot be trusted for
	# this: emulate_mouse_from_touch is on, so every tap also arrives as a click.
	if event is InputEventKey and event.pressed:
		_set_touch_mode(false)
		return
	if event is InputEventScreenTouch and event.pressed:
		_set_touch_mode(true)

	if not _is_live():
		return

	if event is InputEventScreenTouch:
		if event.pressed:
			_on_press(event.index, event.position)
		else:
			_on_release(event.index)
	elif event is InputEventScreenDrag and event.index == _stick_index:
		_move_stick(event.position)
		get_viewport().set_input_as_handled()


func _on_press(index: int, at: Vector2) -> void:
	var button := _button_at(at)
	if button >= 0:
		_held[button] = index
		_emit_action(BUTTONS[button]["action"], true)
		get_viewport().set_input_as_handled()
		return

	# Anything else on the left half plants the stick, wherever it landed - a
	# stick fixed to one spot means hunting for it without looking.
	if _stick_index == -1 and at.x <= _screen().size.x * stick_area_ratio:
		_stick_index = index
		_stick_base = at
		_move_stick(at)
		get_viewport().set_input_as_handled()


func _on_release(index: int) -> void:
	if index == _stick_index:
		_stick_index = -1
		_release_stick()
		get_viewport().set_input_as_handled()
		return

	for button in _held.keys():
		if _held[button] == index:
			_held.erase(button)
			_emit_action(BUTTONS[button]["action"], false)
			get_viewport().set_input_as_handled()
			return


## The button under `at`, or -1. Skipped for a button that is currently unusable,
## so a tap there falls through rather than firing nothing.
func _button_at(at: Vector2) -> int:
	for i in BUTTONS.size():
		if not _button_enabled(i):
			continue
		if at.distance_to(_button_center(i)) <= _button_radius(i):
			return i
	return -1


func _button_enabled(index: int) -> bool:
	if BUTTONS[index]["action"] != "ultimate":
		return true
	return _ultimate_unlocked()


# --- Stick -------------------------------------------------------------------

func _move_stick(at: Vector2) -> void:
	var offset := at - _stick_base
	if offset.length() > stick_radius:
		offset = offset.normalized() * stick_radius
	_stick_knob = _stick_base + offset
	_feed_stick(offset / stick_radius)


## Turns the stick offset into held directions.
##
## The DIRECTION is fed, at full strength, rather than how far the stick is
## pushed. Input.get_vector applies the action's own deadzone - 0.5 on the ui_*
## actions - which would swallow the whole lower half of the throw; feeding the
## unit direction keeps the angle exact and lands the player at the same speed a
## keyboard gives them.
func _feed_stick(offset: Vector2) -> void:
	if offset.length() < stick_dead_zone:
		_release_stick_actions()
		return
	var dir := offset.normalized()
	_press("ui_left", maxf(-dir.x, 0.0))
	_press("ui_right", maxf(dir.x, 0.0))
	_press("ui_up", maxf(-dir.y, 0.0))
	_press("ui_down", maxf(dir.y, 0.0))


func _press(action: String, strength: float) -> void:
	if strength > 0.0:
		Input.action_press(action, strength)
		_pressed[action] = true
	elif _pressed.has(action):
		Input.action_release(action)
		_pressed.erase(action)


func _release_stick() -> void:
	_release_stick_actions()
	_stick_base = Vector2.ZERO
	_stick_knob = Vector2.ZERO


## Only ever lets go of directions this node pressed, so it cannot stamp on a
## keyboard that is being used at the same time.
func _release_stick_actions() -> void:
	for action in STICK_ACTIONS:
		if _pressed.has(action):
			Input.action_release(action)
			_pressed.erase(action)


# --- Actions -----------------------------------------------------------------

## Sends a button press as a real input event rather than only setting the action
## state, so it reaches _unhandled_input as well - which is how the pause screen
## listens for its own open action.
func _emit_action(action: String, pressed: bool) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = pressed
	Input.parse_input_event(event)


func _release_everything() -> void:
	_release_stick()
	_stick_index = -1
	for button in _held.keys():
		_emit_action(BUTTONS[button]["action"], false)
	_held.clear()


# --- Player state ------------------------------------------------------------

func _player_node() -> Node:
	if _player != null and is_instance_valid(_player):
		return _player
	_player = get_tree().get_first_node_in_group("player")
	if _player != null and not _player.has_method("ultimate_cooldown_ratio"):
		_player = null
	return _player


func _ultimate_unlocked() -> bool:
	var player := _player_node()
	return player != null and player.has_ultimate()


func _ultimate_ready() -> bool:
	var player := _player_node()
	return player != null and player.ultimate_is_ready()


# --- Layout ------------------------------------------------------------------

func _screen() -> Rect2:
	return _overlay.get_rect()


func _button_center(index: int) -> Vector2:
	return _screen().end + (BUTTONS[index]["offset"] as Vector2)


func _button_radius(index: int) -> float:
	return menu_button_radius if BUTTONS[index].get("small", false) else button_radius


# --- Drawing -----------------------------------------------------------------

func _on_overlay_draw() -> void:
	for i in BUTTONS.size():
		_draw_button(i)
	if _stick_index != -1:
		_draw_stick()


func _draw_stick() -> void:
	var body := Color(accent.r, accent.g, accent.b, idle_alpha * 0.5)
	_overlay.draw_circle(_stick_base, stick_radius, body)
	_overlay.draw_arc(_stick_base, stick_radius, 0.0, TAU, 48,
		Color(accent.r, accent.g, accent.b, held_alpha), 3.0, true)
	_overlay.draw_circle(_stick_knob, stick_knob_radius,
		Color(accent.r, accent.g, accent.b, held_alpha))


func _draw_button(index: int) -> void:
	var spec: Dictionary = BUTTONS[index]
	if not _button_enabled(index):
		return

	var center := _button_center(index)
	var radius := _button_radius(index)
	var held := _held.has(index)
	# The ultimate reads as spent until it is charged, matching UltimateBar.
	var dim: bool = spec["action"] == "ultimate" and not _ultimate_ready()

	var alpha := held_alpha if held else idle_alpha
	var tint := accent if not dim else Color(0.6, 0.62, 0.68)

	_overlay.draw_circle(center, radius, Color(tint.r, tint.g, tint.b, alpha * 0.45))
	_overlay.draw_arc(center, radius, 0.0, TAU, 40,
		Color(tint.r, tint.g, tint.b, minf(alpha + 0.25, 1.0)), 3.0, true)

	if dim:
		_draw_cooldown(center, radius)

	var font := ThemeDB.fallback_font
	var size := 20 if not spec.get("small", false) else 15
	var text: String = spec["label"]
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	_overlay.draw_string(font, center + Vector2(-width * 0.5, size * 0.35), text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, size,
		Color(1.0, 1.0, 1.0, minf(alpha + 0.45, 1.0)))


## Sweeps a ring as the ultimate comes back, so the button carries the same
## information the HUD bar does.
func _draw_cooldown(center: Vector2, radius: float) -> void:
	var player := _player_node()
	if player == null:
		return
	var ratio: float = player.ultimate_cooldown_ratio()
	if ratio <= 0.0:
		return
	_overlay.draw_arc(center, radius - 6.0, -PI * 0.5, -PI * 0.5 + TAU * ratio, 40,
		Color(accent.r, accent.g, accent.b, 0.75), 4.0, true)
