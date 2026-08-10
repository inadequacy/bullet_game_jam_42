extends CanvasLayer

## The run readouts, in four places the eye already knows where to find:
##
##   top left    abilities - dash, parry, ultimate
##   top centre  the run clock
##   top right   score
##   bottom mid  XP over health, the two things read while dodging
##
## Every cluster sits over an arena the player can use every pixel of, so each
## one fades out of the way while the player is standing behind it rather than
## fencing off dodging room. They fade independently - being cornered under the
## vitals is no reason to dim the clock.

## What a cluster fades to while the player is behind it. Not zero - the bars
## still have to be readable while the player is cornered.
@export_range(0.0, 1.0, 0.05) var faded_alpha: float = 0.32
## Alpha per second. Fast enough not to lag the player, slow enough not to blink.
@export var fade_speed: float = 5.0
## How far outside a cluster the player counts as "behind" it. Covers the parts
## of the sprite that hang past its origin.
@export var fade_margin: float = 48.0

var _player: Node2D = null

## Everything that dims, found by group rather than by path, so moving a cluster
## around the screen - or adding a fifth - needs no change here.
@onready var _clusters: Array[Node] = get_tree().get_nodes_in_group("hud_cluster")


func _process(delta: float) -> void:
	for node in _clusters:
		var cluster := node as Control
		if cluster == null or not is_instance_valid(cluster):
			continue
		var target := faded_alpha if _player_is_behind(cluster) else 1.0
		cluster.modulate.a = move_toward(cluster.modulate.a, target, fade_speed * delta)


func _player_is_behind(cluster: Control) -> bool:
	var player := _find_player()
	if player == null:
		return false
	# The cluster is laid out in screen space and the player lives in the world,
	# so the player is the one that has to be converted.
	var on_screen := player.get_global_transform_with_canvas().origin
	return cluster.get_global_rect().grow(fade_margin).has_point(on_screen)


func _find_player() -> Node2D:
	if _player != null and is_instance_valid(_player):
		return _player
	_player = get_tree().get_first_node_in_group("player") as Node2D
	return _player
