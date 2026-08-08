extends Control
class_name HealthBar

signal health_depleted
signal health_changed(current: int, max: int)

@export var max_health: int = 100
var current_health: int

@onready var progress_bar: ProgressBar = $ProgressBar

func _ready() -> void:
	current_health = max_health
	progress_bar.max_value = max_health
	progress_bar.value = current_health

func take_damage(amount: int) -> void:
	current_health = clamp(current_health - amount, 0, max_health)
	progress_bar.value = current_health
	health_changed.emit(current_health, max_health)
	if current_health == 0:
		health_depleted.emit()

func heal(amount: int) -> void:
	current_health = clamp(current_health + amount, 0, max_health)
	progress_bar.value = current_health
	health_changed.emit(current_health, max_health)
