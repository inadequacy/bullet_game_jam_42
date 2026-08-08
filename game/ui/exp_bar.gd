extends Control
class_name EXPBar

## Shows progress toward the next level-up card screen.
##
## Unlike DashBar/ParryBar this polls an autoload (GameManager), not the player,
## since XP is run-global state, not a per-character stat.

@export var background_color: Color = Color(0.22, 0.26, 0.32)
@export var fill_color: Color = Color(0.702, 0.004, 0.996, 1.0)

@onready var _fill: ProgressBar = $Fill
@onready var _label: Label = $Label


func _ready() -> void:
	_paint()
	GameManager.exp_changed.connect(_on_exp_changed)
	_on_exp_changed(GameManager.experience, GameManager.exp_threshold)


func _on_exp_changed(current: int, threshold: int) -> void:
	_fill.max_value = threshold
	_fill.value = current


func _paint() -> void:
	var bg := StyleBoxFlat.new()
	bg.bg_color = background_color
	bg.set_corner_radius_all(4)
	_fill.add_theme_stylebox_override("background", bg)

	var fg := StyleBoxFlat.new()
	fg.bg_color = fill_color
	fg.set_corner_radius_all(4)
	_fill.add_theme_stylebox_override("fill", fg)
