extends CharacterBody2D

@export var movespeed: int = 400
var movement_allowed = true

# Dash settings
@export var dash_duration: float = 0.2
@export var dash_cooldown: float = 2.0
@export var dash_speed: int = 800
var dash_allowed = true

# Parry settings
@export var parry_duration: float = 0.2
@export var parry_cooldown: float = 2.0
var parry_allowed = true

## Press Space to dash
func dash_direction(direction: Vector2) -> void:
	movement_allowed = false
	dash_allowed = false

	if direction == Vector2(0.0, 0.0):
		direction = self.transform.x

	velocity = direction * dash_speed
	await get_tree().create_timer(dash_duration).timeout
	movement_allowed = true
	await get_tree().create_timer(dash_cooldown).timeout
	dash_allowed = true


## Press Shift to parry
func parry_this_casual() -> void:
	parry_allowed = false
	#

## Toggle targeting

func get_input() -> void:
	if movement_allowed == true:
		look_at(get_global_mouse_position())
		var input_direction = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
		velocity = input_direction * movespeed

		if Input.is_action_just_pressed("dash") && dash_allowed:
			dash_direction(input_direction)

		if Input.is_action_just_pressed("parry") && parry_allowed:
			parry_this_casual()


func _physics_process(_delta) -> void:
	get_input()
	move_and_slide()
