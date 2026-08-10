class_name GroupRef
extends RefCounted

## A lazily resolved, cached reference to a node in a group.
##
##     var _player_ref := GroupRef.new("player", "max_dash_charges")
##     ...
##     var player := _player_ref.resolve(self)
##     if player == null:
##         return
##
## Half the game reads a node it did not spawn and cannot be wired to - the HUD
## bars poll the player, the clock polls the arena, an enemy polls the run clock -
## and each of them used to carry its own copy of "look it up, check it is the
## right thing, remember it, notice when it goes away".
##
## `api` is a method the node must have. It is what stops a readout latching onto
## something that merely shares the group name, and it is optional: pass nothing
## where membership alone is proof enough.

var _group: String
var _api: String
var _node: Node = null


func _init(group: String, api: String = "") -> void:
	_group = group
	_api = api


## The node, or null while there is none to be had. Resolves again after the node
## it was holding is freed, so a level reload needs no reset here.
func resolve(from: Node) -> Node:
	if _node != null and is_instance_valid(_node):
		return _node
	# Called from a node that has left the tree - during teardown, or before the
	# first frame - which has no tree to search.
	if not from.is_inside_tree():
		return null
	_node = from.get_tree().get_first_node_in_group(_group)
	if _node != null and _api != "" and not _node.has_method(_api):
		_node = null
	return _node
