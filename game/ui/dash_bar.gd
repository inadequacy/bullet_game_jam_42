extends Control
class_name DashBar

## Shows the player's dash charges as a row of pips, plus a bar filling toward
## the next one. The pip row rebuilds itself when a card changes the maximum.
##
## Polls the player rather than listening for signals - the values change every
## frame while recharging anyway, and polling means no wiring in the level.

@export var pip_size: Vector2 = Vector2(28, 14)
@export var filled_color: Color = Color(0.55, 0.85, 1.0)
@export var empty_color: Color = Color(0.22, 0.26, 0.32)
## Hide the recovery bar when the pool is full, rather than showing an empty one.
@export var hide_bar_when_full: bool = true

## The player, resolved through the group rather than a path, so the bar works
## wherever the level puts it. The method name is what proves it is the player.
var _player_ref := GroupRef.new("player", "max_dash_charges")
var _pips: Array[ColorRect] = []
var _shown_max: int = -1

@onready var _pip_row: HBoxContainer = $Rows/Pips
@onready var _recharge: ProgressBar = $Rows/Recharge


func _ready() -> void:
	HudStyle.paint_bar(_recharge, empty_color, filled_color)


func _process(_delta: float) -> void:
	var player := _player_ref.resolve(self)
	if player == null:
		return

	var maximum: int = player.max_dash_charges()
	if maximum != _shown_max:
		_rebuild_pips(maximum)

	var current: int = player.dash_charges
	for i in _pips.size():
		_pips[i].color = filled_color if i < current else empty_color

	var ratio: float = player.dash_recharge_ratio()
	_recharge.value = ratio * 100.0
	if hide_bar_when_full:
		_recharge.visible = current < maximum


func _rebuild_pips(count: int) -> void:
	for pip in _pips:
		pip.queue_free()
	_pips.clear()

	for i in count:
		var pip := ColorRect.new()
		pip.custom_minimum_size = pip_size
		pip.color = empty_color
		_pip_row.add_child(pip)
		_pips.append(pip)

	_shown_max = count
