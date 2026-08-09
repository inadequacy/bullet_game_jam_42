extends Control
class_name UltimateBar

## Shows whether the ultimate is charged, and how far the cooldown has come back.
##
## HIDDEN ENTIRELY until the unlock card is taken. The ultimate is a discovery -
## a greyed-out slot sitting on the HUD from the first second of the run would
## give that away and turn the card into an inevitability rather than a find.
##
## Built to match DashBar and ParryBar deliberately - a pip for the ability and a
## bar filling toward its return - so all three cooldowns read the same way at a
## glance. Polls the player for the same reason those two do: the value changes
## every frame while recharging, and polling means no wiring in the level.

@export var pip_size: Vector2 = Vector2(46, 14)
## Charged and ready to fire.
@export var ready_color: Color = Color(1.0, 0.82, 0.29)
## Spent, waiting on the cooldown.
@export var empty_color: Color = Color(0.22, 0.26, 0.32)
## Seconds remaining, shown next to the pip. The ultimate cooldown is long
## enough that a bare bar does not answer "how long?" at a glance.
@export var show_seconds: bool = true

var _player: Node = null

@onready var _pip: ColorRect = $Rows/Pips/Pip
@onready var _recharge: ProgressBar = $Rows/Recharge
@onready var _label: Label = $Rows/Pips/Timer


func _ready() -> void:
	_pip.custom_minimum_size = pip_size
	HudStyle.paint_bar(_recharge, empty_color, ready_color)
	visible = false


func _process(_delta: float) -> void:
	var player := _find_player()
	if player == null:
		return

	# The whole bar appears the moment the unlock card lands.
	visible = player.has_ultimate()
	if not visible:
		return

	var is_ready: bool = player.ultimate_is_ready()
	_pip.color = ready_color if is_ready else empty_color
	_recharge.value = player.ultimate_cooldown_ratio() * 100.0
	_recharge.visible = not is_ready

	if not show_seconds:
		_label.text = ""
	elif is_ready:
		_label.text = "E"
	else:
		_label.text = "%ds" % int(ceil(player.ultimate_time_left()))


func _find_player() -> Node:
	if _player != null and is_instance_valid(_player):
		return _player
	_player = get_tree().get_first_node_in_group("player")
	# Only drive this from a player that actually has the ultimate API.
	if _player != null and not _player.has_method("ultimate_cooldown_ratio"):
		_player = null
	return _player
