extends Control
class_name HealthBar

signal health_depleted
signal health_changed(current: int, max: int)

@export var max_health: int = 10
var current_health: int


@export var background_color: Color = Color(0.22, 0.26, 0.32)
@export var fill_color: Color = Color(0.702, 0.004, 0.0, 1.0)

@onready var _fill: ProgressBar = $Fill
@onready var _label: Label = $Label


func _ready() -> void:
	_paint()
	current_health = max_health
	_fill.max_value = max_health
	_fill.value = current_health

func take_damage(amount: int) -> void:
	current_health = clamp(current_health - amount, 0, max_health)
	_fill.value = current_health
	health_changed.emit(current_health, max_health)
	if current_health == 0:
		health_depleted.emit()

func heal(amount: int) -> void:
	current_health = clamp(current_health + amount, 0, max_health)
	_fill.value = current_health
	health_changed.emit(current_health, max_health)

func _paint() -> void:
	var bg := StyleBoxFlat.new()
	bg.bg_color = background_color
	bg.set_corner_radius_all(4)
	_fill.add_theme_stylebox_override("background", bg)

	var fg := StyleBoxFlat.new()
	fg.bg_color = fill_color
	fg.set_corner_radius_all(4)
	_fill.add_theme_stylebox_override("fill", fg)
