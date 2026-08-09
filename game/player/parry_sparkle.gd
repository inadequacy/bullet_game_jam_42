class_name ParrySparkle
extends Node2D

## Green sparkles thrown around the player when a parry lands. Created in code
## and frees itself, same as ParryFlash.
##
##     ParrySparkle.burst(get_parent(), global_position, texture)
##
## Distinct job from the ring: the ring shows reach and must stay exactly the
## burst radius, while the sparkles say "that worked" right where the player is
## looking - at their own character.

## How many sparkles a parry throws.
const COUNT := 4
## Ring the sparkles are scattered on, in pixels from the player.
const SPREAD_MIN := 44.0
const SPREAD_MAX := 78.0
const LIFETIME := 0.42


static func burst(parent: Node, at: Vector2, texture: Texture2D) -> ParrySparkle:
	if texture == null or parent == null or not parent.is_inside_tree():
		return null

	var node := ParrySparkle.new()
	parent.add_child(node)
	node.global_position = at
	# Above the player, so the confirmation is never hidden behind them.
	node.z_index = 6

	for i in COUNT:
		node._add_sparkle(texture, i)

	# Frees itself once the last sparkle has finished.
	var done := node.create_tween()
	done.tween_interval(LIFETIME + 0.1)
	done.tween_callback(node.queue_free)
	return node


func _add_sparkle(texture: Texture2D, index: int) -> void:
	var sparkle := Sprite2D.new()
	sparkle.texture = texture
	add_child(sparkle)

	# Spread evenly around the player with a little jitter - four fully random
	# angles clump often enough to look like a mistake.
	var angle := TAU * (float(index) / float(COUNT)) + randf_range(-0.35, 0.35)
	var distance := randf_range(SPREAD_MIN, SPREAD_MAX)
	var target := Vector2.RIGHT.rotated(angle) * distance

	sparkle.position = target * 0.35
	sparkle.rotation = randf_range(0.0, TAU)
	sparkle.scale = Vector2.ZERO

	var size := randf_range(0.5, 0.9)
	var tween := sparkle.create_tween().set_parallel(true)
	# Pops out to full size fast, then drifts outward while fading.
	tween.tween_property(sparkle, "scale", Vector2(size, size), LIFETIME * 0.3) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(sparkle, "position", target, LIFETIME) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(sparkle, "modulate:a", 0.0, LIFETIME) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
