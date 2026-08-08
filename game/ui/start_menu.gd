extends Control

func _ready() -> void:
	SoundManager.attach_button_sounds(self)


func _on_start_button_pressed() -> void:
	get_tree().change_scene_to_file("res://game/levels/level.tscn")


func _on_quit_button_pressed() -> void:
	get_tree().quit()
