extends CanvasLayer

## The run readouts.
##
## The cluster sits in a corner of an arena the player can use every pixel of,
## so it fades out of the way when they stand behind it rather than fencing off
## dodging room.

## What the cluster fades to while the player is behind it. Not zero - the bars
## still have to be readable while the player is cornered.
@export_range(0.0, 1.0, 0.05) var faded_alpha: float = 0.32
## Alpha per second. Fast enough not to lag the player, slow enough not to blink.
@export var fade_speed: float = 5.0
## How far outside the cluster the player counts as "behind" it. Covers the parts
## of the sprite that hang past its origin.
@export var fade_margin: float = 48.0

var _player: Node2D = null

@onready var _cluster: Control = $Cluster


func _process(delta: float) -> void:
	var target := faded_alpha if _player_is_behind_cluster() else 1.0
	_cluster.modulate.a = move_toward(_cluster.modulate.a, target, fade_speed * delta)


func _player_is_behind_cluster() -> bool:
	var player := _find_player()
	if player == null:
		return false
	# The cluster is laid out in screen space and the player lives in the world,
	# so the player is the one that has to be converted.
	var on_screen := player.get_global_transform_with_canvas().origin
	return _cluster.get_global_rect().grow(fade_margin).has_point(on_screen)


func _find_player() -> Node2D:
	if _player != null and is_instance_valid(_player):
		return _player
	_player = get_tree().get_first_node_in_group("player") as Node2D
	return _player
