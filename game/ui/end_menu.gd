extends Control

## The screen both endings arrive at. GameManager.won says which one this is -
## the run's outcome is decided by level.gd or movement.gd, never here.

## Title colour for a win. Loss keeps the theme's own white: a death does not
## need colouring in, and the wording already says it.
const WIN_COLOR := Color(1.0, 0.85, 0.35)

## How long before the buttons will take a press, matching the level-up hand in
## card_screen.gd.
##
## This screen also arrives on a frame the player did not choose, mid-fight,
## with a finger on dash and a thumb on the mouse - and dash is Space, which is
## also ui_accept. Without the wait, whatever was queued for the fight would
## restart the run before the player had read how the last one ended.
const ARM_DELAY := 0.5
const DEALING_ALPHA := 0.45

@onready var _title: Label = $VBoxContainer/Label
@onready var _score: Label = $VBoxContainer/Score
@onready var _buttons: VBoxContainer = $VBoxContainer
@onready var _restart: Button = $VBoxContainer/Start_Button
@onready var _menu: Button = $VBoxContainer/Menu_Button
@onready var _quit: Button = $VBoxContainer/Quit_Button


func _ready() -> void:
	_title.text = str(GameManager.message)
	_score.text = "Score: " + str(GameManager.score)

	if GameManager.won:
		_title.add_theme_color_override("font_color", WIN_COLOR)
		# "Restart" is what you do to a run that went wrong. This one didn't.
		_restart.text = "Play again"

	SoundManager.attach_button_sounds(self)
	_arm()


## Holds the buttons unpressable while the screen fades up, then hands focus to
## the first one so the menu is playable without the mouse.
func _arm() -> void:
	for button in [_restart, _menu, _quit]:
		button.disabled = true
	_buttons.modulate.a = DEALING_ALPHA
	create_tween().tween_property(_buttons, "modulate:a", 1.0, ARM_DELAY)

	await get_tree().create_timer(ARM_DELAY).timeout
	if not is_inside_tree():
		return
	for button in [_restart, _menu, _quit]:
		button.disabled = false
	_restart.grab_focus()


## RunState as well as GameManager, the same pair the pause menu wipes. It is an
## autoload and outlives the level, so without this the next run opens holding
## the last one's cards and element lock.
func _on_start_button_pressed() -> void:
	GameManager.reset_game_data()
	RunState.reset()
	get_tree().change_scene_to_file("res://game/levels/level.tscn")


func _on_menu_button_pressed() -> void:
	GameManager.reset_game_data()
	RunState.reset()
	get_tree().change_scene_to_file("res://game/ui/start_menu.tscn")


func _on_quit_button_pressed() -> void:
	get_tree().quit()
