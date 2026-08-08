extends CanvasLayer

## Pause menu. P freezes the game (get_tree().paused = true, same mechanism
## card_screen.gd already uses - see PROCESS_MODE_ALWAYS below, which is why
## this node keeps running while everything else stops).
##
## Refuses to open while the card screen is up - polled via the "card_screen"
## group rather than a hard reference, same pattern DashBar/ParryBar/RunTimer
## use to find the player.

@export var open_action: String = "pause"

var is_open: bool = false

@onready var _screen: Control = $Screen


func _ready() -> void:
	_screen.visible = false


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed(open_action):
		return
	if not is_open and _card_screen_is_open():
		return
	if is_open:
		close()
	else:
		open()
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


func close() -> void:
	if not is_open:
		return
	_screen.visible = false
	is_open = false
	get_tree().paused = false


func _on_resume_pressed() -> void:
	print("button pressed")
	close()


## Fresh reload: wipes RunState/GameManager and reloads level.tscn from scratch.
func _on_restart_pressed() -> void:
	get_tree().paused = false
	GameManager.reset_game_data()
	RunState.reset()
	get_tree().change_scene_to_file("res://game/levels/level.tscn")


func _on_main_menu_pressed() -> void:
	get_tree().paused = false
	GameManager.reset_game_data()
	RunState.reset()
	get_tree().change_scene_to_file("res://game/ui/start_menu.tscn")
