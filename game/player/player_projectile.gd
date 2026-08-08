class_name PlayerProjectile
extends Area2D

## The player's basic spell, and everything the element cards make it do.
##
## THE ELEMENT LINES LIVE HERE. A shot reads RunState at spawn to find out what
## it is - plain missile, explosive, chilling, piercing, homing - so nothing
## that fires one needs to know which school the run committed to.
##
## The exports below are BASE values. Cards scale them through RunState, exactly
## like `damage` already did, so retuning a card never means editing this file.

@export var speed: float = 500
## Enemy health values are 20-40, so 10 means 2-4 hits to kill.
@export var damage: float = 10.0
## Failsafe despawn so stray shots never accumulate over a long run.
@export var lifetime: float = 6.0

@export_group("Fire")
@export var explosion_radius: float = 85.0
## Splash damage as a fraction of the direct hit. Well under 1.0 - the explosion
## is a bonus for hitting a crowd, not a reason to stop aiming.
@export var explosion_damage_ratio: float = 0.5
@export var burn_damage_per_second: float = 4.0
@export var burn_duration: float = 3.0

@export_group("Ice")
## Enemy speed while chilled, as a fraction. Cards push this down.
@export var chill_factor: float = 0.6
@export var chill_duration: float = 2.0
@export var freeze_duration: float = 1.5

@export_group("Arcane")
## Degrees per second a Seeker shot can turn. High enough to correct a near
## miss, low enough that it cannot loop back on something it flew past.
@export var homing_turn_rate: float = 260.0
## Extra damage a chilled enemy takes with Shatter, as a multiplier.
@export var shatter_bonus: float = 1.4
@export_group("")

var velocity := Vector2.RIGHT

var _age: float = 0.0
## Enemies still to pass through. Spent one at a time; at zero the shot dies on
## its next hit.
var _pierce_left: int = 0
## Enemies this shot has already damaged, so a piercing shot cannot hit the same
## body twice as it passes through - Area2D re-reports overlaps.
var _already_hit: Dictionary = {}


func _ready() -> void:
	add_to_group("player_projectiles")
	body_entered.connect(_on_body_entered)
	# Bake in the run's cards at spawn - the exports are the base values.
	damage = RunState.modified(CardDatabase.STAT_ATTACK_DAMAGE, damage)
	speed = RunState.modified(CardDatabase.STAT_PROJECTILE_SPEED, speed)
	_pierce_left = int(round(RunState.modified(CardDatabase.STAT_PIERCE, 0.0)))


func _process(delta: float) -> void:
	_age += delta
	if _age >= lifetime:
		queue_free()
		return

	if RunState.flag(CardDatabase.FLAG_HOMING_SHOTS):
		_steer_toward_target(delta)

	position += velocity * delta * speed


## Seeker Missiles. Turns the shot toward the nearest enemy at a capped rate, so
## it corrects rather than snaps - a shot that turned instantly would make aiming
## and the auto-aim toggle both meaningless.
func _steer_toward_target(delta: float) -> void:
	var target := _nearest_enemy()
	if target == null:
		return
	var wanted := global_position.direction_to(target.global_position)
	var max_turn := deg_to_rad(homing_turn_rate) * delta
	velocity = velocity.rotated(
		clampf(velocity.angle_to(wanted), -max_turn, max_turn)).normalized()
	# Keep the sprite pointing where it is actually going.
	rotation = velocity.angle()


func _nearest_enemy() -> Node2D:
	var best: Node2D = null
	var best_dist := INF
	for e in get_tree().get_nodes_in_group("enemies"):
		if not _is_live_enemy(e):
			continue
		var d: float = global_position.distance_squared_to((e as Node2D).global_position)
		if d < best_dist:
			best_dist = d
			best = e
	return best


func _on_body_entered(body: Node2D) -> void:
	# The player is on the same collision layer and the shot spawns on top of
	# them, so anything that isn't an enemy is ignored rather than filtered out
	# with layers.
	if not body is Enemy:
		return
	if _already_hit.has(body.get_instance_id()):
		return
	_already_hit[body.get_instance_id()] = true

	_strike(body as Enemy)

	# Pierce is spent per enemy struck, so a shot with one charge hits two.
	if _pierce_left > 0:
		_pierce_left -= 1
		return
	queue_free()


## One enemy taking one hit, with whatever the run's element adds to it.
func _strike(enemy: Enemy) -> void:
	var hit_position := enemy.global_position
	# Read the chill BEFORE damaging - take_damage can free the enemy outright.
	var dealt := damage
	if RunState.flag(CardDatabase.FLAG_SHATTER) and enemy.is_chilled():
		dealt *= RunState.modified(CardDatabase.STAT_SHATTER_BONUS, shatter_bonus)

	enemy.take_damage(dealt)

	if RunState.flag(CardDatabase.FLAG_CHILLING_SHOTS):
		_apply_chill(enemy)

	if RunState.flag(CardDatabase.FLAG_EXPLOSIVE_SHOTS):
		_apply_burn(enemy)
		explode(get_parent(), hit_position,
			RunState.modified(CardDatabase.STAT_EXPLOSION_RADIUS, explosion_radius),
			RunState.modified(CardDatabase.STAT_EXPLOSION_DAMAGE,
				damage * explosion_damage_ratio),
			burn_damage_per_second, burn_duration, enemy)


## Ice on-hit. Every Nth hit freezes outright instead of chilling - see
## RunState.count_hit_and_check_freeze, which owns the counter so it keeps
## running across every shot in the run rather than per projectile.
func _apply_chill(enemy: Enemy) -> void:
	if not _is_live_enemy(enemy):
		return
	if RunState.count_hit_and_check_freeze():
		enemy.apply_freeze(
			RunState.modified(CardDatabase.STAT_FREEZE_DURATION, freeze_duration))
		return
	enemy.apply_chill(
		RunState.modified(CardDatabase.STAT_SLOW_FACTOR, chill_factor),
		RunState.modified(CardDatabase.STAT_SLOW_DURATION, chill_duration))


func _apply_burn(enemy: Enemy) -> void:
	if not RunState.flag(CardDatabase.FLAG_BURN) or not _is_live_enemy(enemy):
		return
	enemy.apply_burn(
		RunState.modified(CardDatabase.STAT_BURN_DAMAGE, burn_damage_per_second),
		RunState.modified(CardDatabase.STAT_BURN_DURATION, burn_duration))


## A Fire explosion: splash damage to everything in `radius`, plus the visual at
## exactly that radius so the circle drawn is the circle that hurt.
##
## `except` is the enemy the shot hit directly - it has already taken the full
## hit and must not also take the splash from its own impact.
##
## Static so Chain Reaction can call it again from a corpse. `depth` is the only
## thing stopping a chain from running away: one enemy killed by a chained blast
## does not start a third.
static func explode(where: Node, at: Vector2, radius: float, splash: float,
		burn_dps: float, burn_time: float, except: Enemy = null,
		depth: int = 0) -> void:
	if where == null or not is_instance_valid(where) or not where.is_inside_tree():
		return

	SpellBurst.at(where, at, radius)

	var chains: Array[Vector2] = []
	var burning := RunState.flag(CardDatabase.FLAG_BURN)
	var chaining := RunState.flag(CardDatabase.FLAG_CHAIN_EXPLOSION) and depth < 1

	for e in where.get_tree().get_nodes_in_group("enemies"):
		var enemy := e as Enemy
		if enemy == null or enemy == except:
			continue
		if not is_instance_valid(enemy) or enemy.is_queued_for_deletion():
			continue
		if enemy.global_position.distance_to(at) > radius:
			continue

		var spot := enemy.global_position
		enemy.take_damage(splash)

		if not is_instance_valid(enemy) or enemy.is_queued_for_deletion() \
				or enemy.health <= 0.0:
			# Chain Reaction: the blast that killed it becomes the next blast.
			if chaining:
				chains.append(spot)
			continue

		if burning:
			enemy.apply_burn(burn_dps, burn_time)

	# Collected first, detonated after: spawning inside the loop would mutate the
	# group being iterated.
	for spot in chains:
		explode(where, spot, radius, splash, burn_dps, burn_time, null, depth + 1)


static func _is_live_enemy(node: Node) -> bool:
	return node is Enemy and is_instance_valid(node) \
		and not node.is_queued_for_deletion() and (node as Enemy).health > 0.0
