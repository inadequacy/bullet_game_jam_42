extends CharacterBody2D

@export var speed: float = 400

func get_input() -> void:
	look_at(get_global_mouse_position())
	var input_direction = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	velocity = input_direction * speed

func _physics_process(_delta) -> void:
	get_input()
	move_and_slide()
