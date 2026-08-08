extends Node2D

## Arena controller: runs the countdown, keeps the arena stocked to the cap for
## the current tier of the run, and spawns the player's shots.
##
## Density is the difficulty ramp (docs/game_info.md §"Difficulty Ramp") - enemy
## stats stay flat and the crowd is what grows. The cap steps up every three
## minutes, on the same beat as the boss timings, and the arena is topped back up
## to it whenever a slot opens.

const ENEMY_SCENES := [
	preload("res://game/enemies/caster_blue.tscn"),
	preload("res://game/enemies/caster_green.tscn"),
	preload("res://game/enemies/caster_red.tscn"),
	preload("res://game/enemies/chaser.tscn"),
]

@export_group("Run")
## Total run length. The clock counts down from here.
@export var run_duration: float = 720.0
## Enemies alive at once, one entry per tier_length slice of the run:
## 0-3min 3, 3-6min 4, 6-9min 5, 9-12min 6. The last entry holds once the clock
## has run out.
@export var tier_caps: Array[int] = [3, 4, 5, 6]
## Length of one tier. Same three minute beat as the boss timings, so density
## steps up on the rhythm the run is already built around.
@export var tier_length: float = 180.0

@export_group("Spawning")
## Where enemies head for once they have walked in. Inset from the 1152x648
## viewport so nothing settles half off the edge.
@export var spawn_area: Rect2 = Rect2(90, 90, 972, 468)
## How far outside the view they start. Large enough that the spawn itself is
## never visible - the player only ever sees something walk in.
@export var spawn_offscreen_margin: float = 120.0
## Enemies never head for a point closer than this to the player, so nothing
## arrives on top of them.
@export var min_spawn_distance: float = 320.0
## Beat between a slot opening and it being filled, so kills feel like they
## landed instead of being instantly undone.
@export var respawn_delay: float = 1.0
## Prints the clock, kills and spawns to the terminal.
@export var respawn_logs: bool = true

var _time_left: float = 0.0
var _refill_timer: float = 0.0
## Last tier announced to the log, so a change is printed once and not per frame.
var _logged_tier: int = -1
## Cleared once the opening wave has been placed. See _process().
var _opening_wave_pending: bool = true


func _ready() -> void:
	add_to_group("run_clock")
	_time_left = run_duration
	for e in get_tree().get_nodes_in_group("enemies"):
		_watch(e)


func _process(delta: float) -> void:
	# Deferred out of _ready() on purpose: spawn points are measured off the
	# camera's canvas transform, which is not guaranteed to have been applied
	# while children are still being readied. By the first frame it has.
	if _opening_wave_pending:
		_opening_wave_pending = false
		_fill_to_cap()

	# Stops at zero rather than running negative. Per docs/game_info.md the run
	# continues past 12:00 until the final boss dies, so a frozen clock is the
	# documented behaviour - this is not the place that ends the run.
	_time_left = maxf(_time_left - delta, 0.0)
	_log_tier_change()
	_maintain_population(delta)


# --- Run clock (RunTimer polls these) ----------------------------------------

func time_left() -> float:
	return _time_left


## Seconds since the run began, saturating at run_duration.
func elapsed() -> float:
	return run_duration - _time_left


## M:SS. Shared by the HUD and the logs so they can never disagree.
func format_time_left() -> String:
	# Ceiling, so a fresh run reads 12:00 rather than 11:59.
	var total := int(ceil(_time_left))
	return "%d:%02d" % [total / 60, total % 60]


# --- Population --------------------------------------------------------------

## Which tier_caps entry applies right now.
func current_tier() -> int:
	if tier_caps.is_empty():
		return 0
	return clampi(int(elapsed() / maxf(tier_length, 0.001)), 0, tier_caps.size() - 1)


## How many enemies should be alive at this moment.
func population_cap() -> int:
	if tier_caps.is_empty():
		return 0
	return maxi(tier_caps[current_tier()], 0)


## Living enemies, ignoring any already freed this frame.
##
## queue_free() does not remove a node from its groups until the end of the
## frame, so counting the group raw would see a just-killed enemy as alive and
## stall the refill by a tick.
func _living_enemy_count() -> int:
	var alive := 0
	for e in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(e) and not e.is_queued_for_deletion():
			alive += 1
	return alive


## Tops the arena back up to the cap, one enemy per respawn_delay.
##
## Driven by a head count rather than by the died signal, so it self-corrects: a
## tier stepping up, several deaths in the same instant, or an enemy lost some
## other way all resolve the same way without anything having to report them.
func _maintain_population(delta: float) -> void:
	if _living_enemy_count() >= population_cap():
		_refill_timer = 0.0
		return

	_refill_timer += delta
	if _refill_timer < respawn_delay:
		return
	_refill_timer = 0.0
	_spawn_random_enemy()


## Fills every empty slot at once, with no delay. Opening the run only.
func _fill_to_cap() -> void:
	# Bounded rather than a while loop: if a spawn ever failed to register in the
	# group, an unbounded version would hang the game on the first frame.
	for i in population_cap():
		if _living_enemy_count() >= population_cap():
			return
		_spawn_random_enemy()


func _log_tier_change() -> void:
	var tier := current_tier()
	if tier == _logged_tier:
		return
	_logged_tier = tier
	if respawn_logs:
		print("[RUN] %s left | tier %d | cap %d enemies"
			% [format_time_left(), tier + 1, population_cap()])


## Every enemy, placed by hand or spawned later, reports its death here.
func _watch(enemy: Enemy) -> void:
	if not enemy.died.is_connected(_on_enemy_died):
		enemy.died.connect(_on_enemy_died)


## Logging only. The refill is driven by the head count in _maintain_population,
## which does not need to be told that anything died.
func _on_enemy_died(enemy: Enemy) -> void:
	if not respawn_logs:
		return
	# Read the name now - the node frees itself right after emitting.
	print("[ENEMY] %s died | refilling to %d" % [enemy.name, population_cap()])


func _spawn_random_enemy() -> void:
	var scene: PackedScene = ENEMY_SCENES.pick_random()
	var enemy: Enemy = scene.instantiate()
	# Name it after its scene so the logs stay readable - Godot would otherwise
	# fall back to names like "@CharacterBody2D@22".
	enemy.name = scene.resource_path.get_file().get_basename()

	var target := _pick_spawn_point()
	add_child(enemy)
	_watch(enemy)
	# After add_child: enter_from writes global_position, which only means
	# anything once the node is in the tree.
	enemy.enter_from(_offscreen_origin_for(target), target)

	if respawn_logs:
		print("[SPAWN] %s walking in to (%d, %d) | %d/%d alive | tier %d"
			% [enemy.name, target.x, target.y, _living_enemy_count(),
			population_cap(), current_tier() + 1])


## The point just outside the view nearest to `target`, so an enemy walks in from
## the closest edge instead of trekking across the whole arena to reach its spot.
func _offscreen_origin_for(target: Vector2) -> Vector2:
	var view := _view_bounds()
	var to_left := target.x - view.position.x
	var to_right := view.end.x - target.x
	var to_top := target.y - view.position.y
	var to_bottom := view.end.y - target.y

	var nearest := minf(minf(to_left, to_right), minf(to_top, to_bottom))
	if nearest == to_left:
		return Vector2(view.position.x - spawn_offscreen_margin, target.y)
	if nearest == to_right:
		return Vector2(view.end.x + spawn_offscreen_margin, target.y)
	if nearest == to_top:
		return Vector2(target.x, view.position.y - spawn_offscreen_margin)
	return Vector2(target.x, view.end.y + spawn_offscreen_margin)


## The visible world rect. Read off the canvas transform rather than assuming
## 1152x648, so this survives a viewport or camera zoom change.
func _view_bounds() -> Rect2:
	var to_world := get_canvas_transform().affine_inverse()
	var screen := get_viewport_rect()
	return Rect2(to_world * screen.position, to_world.basis_xform(screen.size))


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
