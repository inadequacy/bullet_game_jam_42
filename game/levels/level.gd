extends Node2D

## Arena controller: spawns the player's shots and keeps the arena populated by
## replacing every enemy that dies with a random new one.

const ENEMY_SCENES := [
	preload("res://game/enemies/caster_blue.tscn"),
	preload("res://game/enemies/caster_green.tscn"),
	preload("res://game/enemies/caster_red.tscn"),
	preload("res://game/enemies/chaser.tscn"),
]

@export_group("Respawning")
## Where replacements may appear. Inset from the 1152x648 viewport.
@export var spawn_area: Rect2 = Rect2(90, 90, 972, 468)
## Replacements never appear closer than this to the player, so nothing spawns
## on top of them.
@export var min_spawn_distance: float = 320.0
## Beat between a death and its replacement, so kills feel like they landed.
@export var respawn_delay: float = 1.0
## Prints kills and spawns to the terminal.
@export var respawn_logs: bool = true


func _ready() -> void:
	for e in get_tree().get_nodes_in_group("enemies"):
		_watch(e)


## Every enemy, placed by hand or spawned later, reports its death here.
func _watch(enemy: Enemy) -> void:
	if not enemy.died.is_connected(_on_enemy_died):
		enemy.died.connect(_on_enemy_died)


func _on_enemy_died(enemy: Enemy) -> void:
	# Read the name now - the node frees itself right after emitting.
	var who := enemy.name
	if respawn_logs:
		print("[ENEMY] %s died | %d left | respawning in %.1fs"
			% [who, get_tree().get_nodes_in_group("enemies").size() - 1, respawn_delay])

	await get_tree().create_timer(respawn_delay).timeout
	_spawn_random_enemy()


func _spawn_random_enemy() -> void:
	var scene: PackedScene = ENEMY_SCENES.pick_random()
	var enemy: Enemy = scene.instantiate()
	enemy.position = _pick_spawn_point()
	add_child(enemy)
	_watch(enemy)
	if respawn_logs:
		print("[ENEMY] spawned %s at (%d, %d) | %d alive"
			% [enemy.name, enemy.position.x, enemy.position.y,
			get_tree().get_nodes_in_group("enemies").size()])


## Random point in the arena, kept away from the player. Falls back to the
## furthest candidate found if the arena is too cramped to satisfy the rule.
func _pick_spawn_point() -> Vector2:
	var player := get_tree().get_first_node_in_group("player") as Node2D
	var furthest := spawn_area.get_center()
	var furthest_dist := -1.0

	for i in 24:
		var p := Vector2(
			randf_range(spawn_area.position.x, spawn_area.end.x),
			randf_range(spawn_area.position.y, spawn_area.end.y))
		if player == null or not is_instance_valid(player):
			return p
		var d := p.distance_to(player.global_position)
		if d >= min_spawn_distance:
			return p
		if d > furthest_dist:
			furthest_dist = d
			furthest = p

	return furthest


func _on_character_shoot(projectile: Variant, direction: Variant, location: Variant) -> void:
	var spawned_projectile = projectile.instantiate()
	add_child(spawned_projectile)
	spawned_projectile.rotation = direction
	spawned_projectile.position = location
	spawned_projectile.velocity = spawned_projectile.velocity.rotated(direction)
	# The projectile despawns itself now (on enemy hit, or after its lifetime).
	# The old timer here called queue_free() on shots that had already freed
	# themselves, which errors.
