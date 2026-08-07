extends CharacterBody2D

@export var movespeed: int = 400
var movement_allowed = true

# Dash settings
@export_group("Dash Settings")
@export var dash_duration: float = 0.2
@export var dash_cooldown: float = 2.0
@export var dash_speed: int = 800
var dash_allowed = true
@export_group("")

# Parry settings
@export_group("Parry Settings")
@export var parry_duration: float = 0.2
@export var parry_cooldown: float = 2.0
@export var parry_radius: float = 90.0
@onready var parry_collider = $ParryRadius
var parry_allowed = true
@export_group("")

# Attack settings
@export_group("Attack Settings")
signal shoot(projectile, direction, location)
var projectile = preload("res://Scenes/player_projectile.tscn")
@export var cast_rate: float = 1.0
var can_attack: bool = true
@export_group("")

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


## Set Parry radius
## Maybe update this to be general universal updater later.
func parry_radius_update(new_radius: float) -> void:
	parry_collider.shape.set_radius(new_radius)


## Press Shift to parry
func parry_this_casual() -> void:
	parry_allowed = false

	parry_collider.set_deferred("disabled", false)
	await get_tree().create_timer(parry_duration).timeout
	parry_collider.set_deferred("disabled", true)
	await get_tree().create_timer(parry_cooldown).timeout
	parry_allowed = true


func basic_attack() -> void:
	can_attack = false
	shoot.emit(projectile, rotation, position)
	await get_tree().create_timer(cast_rate).timeout
	can_attack = true


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
	if can_attack == true:
		basic_attack()
