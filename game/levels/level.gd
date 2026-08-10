extends Node2D

## Arena controller: runs the countdown, keeps the arena stocked to the cap the
## ramp has reached, and spawns the player's shots.
##
## Density is the difficulty ramp (docs/game_info.md §"Difficulty Ramp") - enemy
## stats stay flat and the crowd is what grows. Two things ramp off the clock:
## the population cap climbs one every `population_step`, and every enemy scales
## its attack interval by `attack_interval_scale()`.

const LEVEL_UP_SOUND := preload("res://assets/sounds/level_up1.wav")

const ENEMY_SCENES := [
	preload("res://game/enemies/caster_blue.tscn"),
	preload("res://game/enemies/caster_green.tscn"),
	preload("res://game/enemies/caster_red.tscn"),
	preload("res://game/enemies/chaser.tscn"),
]

@export_group("Run")
## Total run length. The clock counts down from here.
@export var run_duration: float = 360.0

@export_group("Difficulty ramp")
## Enemies alive at once when the run starts.
@export var starting_population: int = 3
## Hard ceiling on enemies alive at once - past ten the arena reads as clutter
## rather than pressure. Nothing, not even a blue pack, may exceed it.
@export var max_population: int = 10
## Seconds of run time per +1 to the cap. At 35s the arena fills from 3 to 10 by
## about 4:05 of a 6 minute run, leaving the last two minutes at full density.
@export var population_step: float = 35.0
## Attack interval multiplier at the end of the run, sliding from 1.0. Modest on
## purpose: it compounds with a population ramp that already triples the number
## of things shooting.
@export var final_attack_interval_scale: float = 0.65

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
@export var respawn_delay: float = 0.8
## Once this far under cap the arena refills at catch_up_delay instead, so a
## screen the player just cleared does not trickle back one enemy at a time.
@export var catch_up_gap: int = 3
@export var catch_up_delay: float = 0.25
## How many blue casters arrive together. Blue is the crowd enemy: trivial
## alone, a real screen only once several are firing across each other.
@export var blue_pack_size: int = 2
## Chance that pack is one bigger again.
@export_range(0.0, 1.0, 0.05) var blue_pack_bonus_chance: float = 0.35
## Prints the clock, kills and spawns to the terminal.
@export var respawn_logs: bool = true

## The blue caster, kept by reference so _spawn_random_enemy can recognise the
## one scene that arrives in packs.
const BLUE_CASTER := preload("res://game/enemies/caster_blue.tscn")

var _time_left: float = 0.0
var _refill_timer: float = 0.0
## Last cap announced to the log, so a change is printed once and not per frame.
var _logged_cap: int = -1
## Cleared once the opening wave has been placed. See _process().
var _opening_wave_pending: bool = true


func _ready() -> void:
	add_to_group("run_clock")
	_time_left = run_duration
	for e in get_tree().get_nodes_in_group("enemies"):
		_watch(e)
	GameManager.level_up.connect(_on_level_up)

func _on_level_up() -> void:
	SoundManager.play_sfx(LEVEL_UP_SOUND, 0, 0.98, 1.02, 0)
	$CardScreen.open()


func _process(delta: float) -> void:
	# Deferred out of _ready() on purpose: spawn points are measured off the
	# camera's canvas transform, which is not guaranteed to have been applied
	# while children are still being readied. By the first frame it has.
	if _opening_wave_pending:
		_opening_wave_pending = false
		_fill_to_cap()

	# Stops at zero rather than running negative. Per docs/game_info.md the run
	# continues past the final beat until the last boss dies, so this is not the
	# place that ends the run.
	_time_left = maxf(_time_left - delta, 0.0)
	_log_cap_change()
	_maintain_population(delta)


# --- Run clock (RunTimer polls these) ----------------------------------------

func time_left() -> float:
	return _time_left


## Seconds since the run began, saturating at run_duration.
func elapsed() -> float:
	return run_duration - _time_left


## M:SS. Shared by the HUD and the logs so they can never disagree.
func format_time_left() -> String:
	# Ceiling, so a fresh run reads 6:00 rather than 5:59.
	var total := int(ceil(_time_left))
	return "%d:%02d" % [total / 60, total % 60]


# --- Population --------------------------------------------------------------

## How many enemies should be alive at this moment: one more than the last step,
## every population_step seconds, never past max_population.
func population_cap() -> int:
	var grown := starting_population + int(elapsed() / maxf(population_step, 0.001))
	return clampi(grown, 1, maxi(max_population, 1))


## How far through the run we are, 0.0 at the opening and 1.0 at the final beat.
## The one place run time is turned into a fraction, so the sliding ramps below
## and the stepped enemy upgrades in caster.gd agree on where we are.
func run_progress() -> float:
	return clampf(elapsed() / maxf(run_duration, 0.001), 0.0, 1.0)


## What every enemy multiplies its attack interval by right now. Read through
## Enemy.attack_interval_scale(), so a new enemy type inherits the ramp for
## free. Slides rather than steps - the player should never be able to point at
## the moment it got harder.
func attack_interval_scale() -> float:
	return lerpf(1.0, final_attack_interval_scale, run_progress())


## Living enemies, ignoring any freed this frame - queue_free() leaves a node in
## its groups until the frame ends, which would stall the refill by a tick.
func _living_enemy_count() -> int:
	var alive := 0
	for e in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(e) and not e.is_queued_for_deletion():
			alive += 1
	return alive


## Tops the arena back up to the cap, one spawn per respawn_delay. Driven by a
## head count rather than the died signal, so it self-corrects no matter how an
## enemy went missing.
func _maintain_population(delta: float) -> void:
	var cap := population_cap()
	var alive := _living_enemy_count()
	if alive >= cap:
		_refill_timer = 0.0
		return

	# A big hole - the player cleared the screen, or the cap just stepped up -
	# closes fast; a single kill gets the full respawn_delay.
	var delay := catch_up_delay if alive <= cap - catch_up_gap else respawn_delay

	_refill_timer += delta
	if _refill_timer < delay:
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


func _log_cap_change() -> void:
	var cap := population_cap()
	if cap == _logged_cap:
		return
	_logged_cap = cap
	if respawn_logs:
		print("[RUN] %s left | cap %d enemies | attacks x%.2f"
			% [format_time_left(), cap, attack_interval_scale()])


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


## Rolls one enemy type and puts it in the arena - as a pack if it rolled blue.
##
## The pack may overshoot the current cap, and only the hard max_population
## ceiling stops it, so a pack is never trimmed down to a lone blue. The cap
## simply stops refilling until the extras are dead.
func _spawn_random_enemy() -> void:
	var scene: PackedScene = ENEMY_SCENES.pick_random()
	var count := 1
	if scene == BLUE_CASTER:
		count = maxi(blue_pack_size, 1)
		if randf() < blue_pack_bonus_chance:
			count += 1
	count = mini(count, maxi(max_population - _living_enemy_count(), 1))

	for i in count:
		_spawn_enemy(scene)


func _spawn_enemy(scene: PackedScene) -> void:
	var enemy: Enemy = scene.instantiate()
	var target := _pick_spawn_point()
	add_child(enemy)
	# Named after add_child: renaming a node already in the tree appends a number
	# on collision, so a blue pack reads as caster_blue, caster_blue2 in the log
	# instead of being given a generated name.
	enemy.name = scene.resource_path.get_file().get_basename()
	_watch(enemy)
	# After add_child: enter_from writes global_position, which only means
	# anything once the node is in the tree.
	enemy.enter_from(_offscreen_origin_for(target), target)

	if respawn_logs:
		print("[SPAWN] %s walking in to (%d, %d) | %d/%d alive"
			% [enemy.name, target.x, target.y, _living_enemy_count(),
			population_cap()])


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
	# The projectile despawns itself, on enemy hit or after its lifetime.
