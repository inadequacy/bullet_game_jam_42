extends Control
class_name HealthBar

## The player's death, which movement.gd turns into the end screen.
signal health_depleted

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
	_relabel()

func take_damage(amount: int) -> void:
	current_health = clamp(current_health - amount, 0, max_health)
	_fill.value = current_health
	_relabel()
	if current_health == 0:
		health_depleted.emit()

func heal(amount: int) -> void:
	current_health = clamp(current_health + amount, 0, max_health)
	_fill.value = current_health
	_relabel()


## The caption, drawn ON the bar rather than above it, so health and XP stack
## directly on top of each other with no label rows between them. A bar alone
## answers "how hurt am I" but not "how many more hits do I have", which is the
## question actually being asked.
func _relabel() -> void:
	_label.text = "HP  %d/%d" % [current_health, max_health]

func _paint() -> void:
	HudStyle.paint_bar(_fill, background_color, fill_color)
