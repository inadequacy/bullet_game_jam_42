extends CharacterBody2D

@export var speed: float = 400

var movement_allowed = true

## Press Space to dash
func dash_direction(direction: Vector2) -> void:
	movement_allowed = false
	if direction == Vector2(0.0, 0.0):
		direction = self.transform.x

	velocity = direction * speed * 2
	await get_tree().create_timer(0.3).timeout
	movement_allowed = true


## Press Shift to parry
func parry_this_casual() -> void:
	pass

## Toggle

func get_input() -> void:
	if movement_allowed == true:
		look_at(get_global_mouse_position())
		var input_direction = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
		velocity = input_direction * speed

		if Input.is_action_just_pressed("dash"):
			dash_direction(input_direction)

		if Input.is_action_just_pressed("parry"):
			parry_this_casual()


func _physics_process(_delta) -> void:
	get_input()
	move_and_slide()
