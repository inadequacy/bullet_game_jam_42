extends Control
class_name ParryBar

## Whether the parry is up, and how far the lockout has recovered. Matches
## DashBar so the two cooldowns read the same way rather than being two things
## to learn, and polls for the same reason: the value changes every frame, so
## polling costs nothing and needs no wiring.

@export var pip_size: Vector2 = Vector2(28, 14)
## Parry is available.
@export var ready_color: Color = Color(0.5, 1.0, 0.62)
## The window is open right now. It lasts a fifth of a second, so this flash is
## the player's confirmation that the press registered.
@export var active_color: Color = Color(1.0, 1.0, 1.0)
## Spent, waiting on the lockout.
@export var empty_color: Color = Color(0.22, 0.26, 0.32)
## Hide the recovery bar while the parry is up, rather than showing a full one.
@export var hide_bar_when_ready: bool = true

## See DashBar - the same lookup, proved by the parry API instead.
var _player_ref := GroupRef.new("player", "parry_cooldown_ratio")

@onready var _pip: ColorRect = $Rows/Pips/Pip
@onready var _recharge: ProgressBar = $Rows/Recharge


func _ready() -> void:
	_pip.custom_minimum_size = pip_size
	HudStyle.paint_bar(_recharge, empty_color, ready_color)


func _process(_delta: float) -> void:
	var player := _player_ref.resolve(self)
	if player == null:
		return

	var is_ready: bool = player.parry_is_ready()
	if player.parry_is_active():
		_pip.color = active_color
	elif is_ready:
		_pip.color = ready_color
	else:
		_pip.color = empty_color

	_recharge.value = player.parry_cooldown_ratio() * 100.0
	if hide_bar_when_ready:
		_recharge.visible = not is_ready
