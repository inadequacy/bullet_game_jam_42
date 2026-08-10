extends CanvasLayer

## Pause menu. Esc freezes the game (get_tree().paused = true, the same
## mechanism card_screen.gd uses - see PROCESS_MODE_ALWAYS on this node, which
## is why it keeps running while everything else stops).
##
## Refuses to open while the card screen is up - polled via the "card_screen"
## group rather than a hard reference, the same pattern DashBar/ParryBar/RunTimer
## use to find the player.

@export var open_action: String = "pause"

var is_open: bool = false

## Rows of the Controls panel, top to bottom.
##
## An `action` row reads its key from the InputMap, so rebinding in project.godot
## shows up here without editing this list. A `keys` row is for input the engine
## has no single action for: movement is four actions, and aiming is just where
## the mouse is. The debug keys are deliberately absent.
const CONTROLS := [
	{"keys": "WASD / Arrows", "label": "Move"},
	{"keys": "Mouse", "label": "Aim"},
	{"action": "dash", "label": "Dash"},
	{"action": "parry", "label": "Parry"},
	{"action": "ultimate", "label": "Ultimate"},
	{"action": "toggle_aim", "label": "Toggle auto-aim"},
	{"action": "pause", "label": "Pause"},
]

## Shown instead of the above once the on-screen controls are in use, where the
## keyboard list would name keys the player has no way to press.
const TOUCH_CONTROLS := [
	{"keys": "Left half", "label": "Drag to move - you face the way you walk"},
	{"keys": "DASH", "label": "Dash"},
	{"keys": "PARRY", "label": "Parry"},
	{"keys": "ULT", "label": "Ultimate, once a card unlocks it"},
	{"keys": "MENU", "label": "This menu"},
]

const PANEL_COLOR := Color(0.09, 0.09, 0.12)
const CHIP_COLOR := Color(0.16, 0.17, 0.22)
## Shared with DashBar's fill, so the panel belongs to the same HUD palette.
const ACCENT := Color(0.55, 0.85, 1.0)

@onready var _screen: Control = $Screen
@onready var _menu: VBoxContainer = $Screen/Center/Menu
@onready var _controls: PanelContainer = $Screen/Center/Controls
@onready var _grid: GridContainer = $Screen/Center/Controls/Margin/VBox/Grid
@onready var _resume_button: Button = $Screen/Center/Menu/Resume_Button
@onready var _back_button: Button = $Screen/Center/Controls/Margin/VBox/Back_Button


func _ready() -> void:
	_screen.visible = false
	_paint_panel()
	_build_controls()
	SoundManager.attach_button_sounds(self)


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed(open_action):
		return
	if not is_open and _card_screen_is_open():
		return

	if not is_open:
		open()
	elif _controls.visible:
		# Esc backs out of the Controls panel before it closes the menu.
		_show_menu()
	else:
		close()
	get_viewport().set_input_as_handled()


func _card_screen_is_open() -> bool:
	var cs := get_tree().get_first_node_in_group("card_screen")
	return cs != null and cs.is_open


func open() -> void:
	if is_open:
		return
	_screen.visible = true
	is_open = true
	get_tree().paused = true
	_show_menu()


func close() -> void:
	if not is_open:
		return
	_screen.visible = false
	is_open = false
	get_tree().paused = false


# --- Panels ------------------------------------------------------------------
# The menu and the Controls list are two pages of the same screen, so exactly
# one is visible at a time and whichever is showing takes keyboard focus.

func _show_menu() -> void:
	_controls.visible = false
	_menu.visible = true
	_resume_button.grab_focus()


func _show_controls() -> void:
	_build_controls()
	_menu.visible = false
	_controls.visible = true
	_back_button.grab_focus()


## True when the on-screen touch controls are what the player is using. Absent on
## desktop, where the group is simply empty.
func _touch_is_active() -> bool:
	var touch := get_tree().get_first_node_in_group("touch_controls")
	return touch != null and touch.is_active()


## Fills the Controls grid with a key chip and a description per row. Rebuilt
## each time the panel opens, so it follows whichever input the player switched
## to during the run.
func _build_controls() -> void:
	for child in _grid.get_children():
		_grid.remove_child(child)
		child.queue_free()

	for row in (TOUCH_CONTROLS if _touch_is_active() else CONTROLS):
		var keys: String = row.get("keys", "")
		if keys == "":
			keys = _keys_for(row["action"])
		_grid.add_child(_key_chip(keys))
		_grid.add_child(_action_label(row["label"]))


## The keys bound to `action`, named the way the player would name them. Joypad
## and mouse bindings are skipped, since this panel is the keyboard reference.
func _keys_for(action: String) -> String:
	if not InputMap.has_action(action):
		push_warning("Controls panel: no '%s' action in the input map." % action)
		return "?"

	var names: PackedStringArray = []
	for event in InputMap.action_get_events(action):
		var key := event as InputEventKey
		if key == null:
			continue
		# Physical first: that is what the bindings are authored against, so it
		# survives a non-QWERTY layout.
		var code := key.physical_keycode if key.physical_keycode != 0 else key.keycode
		var text := OS.get_keycode_string(code)
		if text != "" and not names.has(text):
			names.append(text)

	return " / ".join(names) if not names.is_empty() else "?"


func _key_chip(text: String) -> Control:
	var chip := PanelContainer.new()
	chip.add_theme_stylebox_override("panel", _chip_style())
	# Right-aligned, so the chips end in a column against the descriptions.
	chip.size_flags_horizontal = Control.SIZE_SHRINK_END

	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", ACCENT)
	chip.add_child(label)
	return chip


func _action_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 20)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return label


func _chip_style() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = CHIP_COLOR
	box.set_corner_radius_all(5)
	box.content_margin_left = 12
	box.content_margin_right = 12
	box.content_margin_top = 4
	box.content_margin_bottom = 4
	return box


## The Controls panel gets its body in code, since PanelContainer would otherwise
## take the default theme's grey and read as a different screen to the cards.
func _paint_panel() -> void:
	var box := StyleBoxFlat.new()
	box.bg_color = PANEL_COLOR
	box.set_corner_radius_all(12)
	box.set_border_width_all(2)
	box.border_color = ACCENT * Color(1, 1, 1, 0.5)
	_controls.add_theme_stylebox_override("panel", box)


# --- Buttons -----------------------------------------------------------------

func _on_resume_pressed() -> void:
	close()


func _on_controls_pressed() -> void:
	_show_controls()


func _on_controls_back_pressed() -> void:
	_show_menu()


## Fresh reload: wipes RunState/GameManager and reloads level.tscn from scratch.
func _on_restart_pressed() -> void:
	close()
	GameManager.reset_game_data()
	RunState.reset()
	get_tree().change_scene_to_file("res://game/levels/level.tscn")


func _on_main_menu_pressed() -> void:
	close()
	GameManager.reset_game_data()
	RunState.reset()
	get_tree().change_scene_to_file("res://game/ui/start_menu.tscn")
