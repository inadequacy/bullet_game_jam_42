extends Control


func _ready() -> void:
	$VBoxContainer/Label.text = str(GameManager.message)
	$VBoxContainer/Score.text = "Score: " + str(GameManager.score)


func _on_start_button_pressed() -> void:
	get_tree().change_scene_to_file("res://game/levels/level.tscn")


func _on_menu_button_pressed() -> void:
	get_tree().change_scene_to_file("res://game/ui/start_menu.tscn")


func _on_quit_button_pressed() -> void:
	get_tree().quit()
