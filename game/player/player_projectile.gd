class_name PlayerProjectile
extends Area2D

## The player's basic spell, and everything the element cards make it do.
##
## The element lines live here. A shot reads RunState at spawn to find out what
## it is - plain missile, explosive, chilling, piercing, overcharged - so nothing
## that fires one needs to know which school the run committed to.
##
## The exports below are base values; cards scale them through RunState, so
## retuning a card never means editing this file.
##
## A shot also LOOKS like the school it belongs to - see LOOKS. The element lock
## is a decision the player cannot take back, so their own fire should show it
## for the rest of the run.

## Art, colour and size per school, applied at spawn from RunState's element
## lock. NONE and ARCANE share the purple orb: arcane is the "stay as you are"
## school, so committing to it should not change what the shot looks like.
##
## The colours are chosen against the enemy palette as much as against each
## other. Ice is a pale cyan rather than the enemies' royal blue, and fire is
## pushed well into orange, away from the homing red the player has to dash.
## Purple stays Max's own - see docs/game_info.md §"Projectile Colors".
const LOOKS := {
	CardDatabase.Element.NONE: {
		"texture": preload("res://assets/images/magic_ball.png"),
		"color": Color(0.55, 0.10, 0.95),
		"scale": Vector2(0.038, 0.038),
	},
	CardDatabase.Element.ARCANE: {
		"texture": preload("res://assets/images/magic_ball.png"),
		"color": Color(0.55, 0.10, 0.95),
		"scale": Vector2(0.038, 0.038),
	},
	CardDatabase.Element.ICE: {
		"texture": preload("res://assets/images/ice_shard.svg"),
		"color": Color(0.42, 0.92, 1.0),
		"scale": Vector2(0.30, 0.30),
	},
	CardDatabase.Element.FIRE: {
		"texture": preload("res://assets/images/fireball.svg"),
		"color": Color(1.0, 0.28, 0.04),
		"scale": Vector2(0.34, 0.34),
	},
}

@export var speed: float = 500
## Enemy health values are 20-40, so 10 means 2-4 hits to kill.
@export var damage: float = 10.0
## Failsafe despawn so stray shots never accumulate over a long run. The bounds
## check below is what actually retires nearly every shot; this only catches one
## that somehow never leaves the view.
@export var lifetime: float = 6.0
## Extra room outside the visible arena before a shot is culled. Small, but not
## zero: the camera shakes a few pixels on a knockback, and a shot skimming the
## edge should not blink out because the view twitched.
@export var despawn_margin: float = 64.0

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
## Overcharge. Extra damage per enemy the shot has already passed through, as a
## fraction of the base hit: at 0.5 a shot deals 1.0x to the first enemy, 1.5x
## to the second, 2.0x to the third. Worth nothing without the pierce from
## Piercing Bolt, which is what makes it a reward for lining a volley up.
@export var overcharge_bonus: float = 0.5
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
	_apply_element_look()
	# Bake in the run's cards at spawn - the exports are the base values.
	damage = RunState.modified(CardDatabase.STAT_ATTACK_DAMAGE, damage)
	speed = RunState.modified(CardDatabase.STAT_PROJECTILE_SPEED, speed)
	_pierce_left = int(round(RunState.modified(CardDatabase.STAT_PIERCE, 0.0)))


## Dresses the shot as the run's school. Only the sprite changes - the hurtbox
## is a capsule along the line of travel, which fits an orb and a shard alike, so
## what the shot hits never depends on which art it is wearing.
func _apply_element_look() -> void:
	var look: Dictionary = LOOKS.get(RunState.chosen_element, {})
	if look.is_empty():
		return
	var icon := $Icon as Sprite2D
	icon.texture = look["texture"]
	icon.scale = look["scale"]
	# Read by colorize.gdshader, which rebuilds the hue from brightness - which
	# is why one greyscale shard can be any blue asked of it.
	icon.modulate = look["color"]


func _process(delta: float) -> void:
	_age += delta
	if _age >= lifetime:
		queue_free()
		return

	position += velocity * delta * speed

	if _is_out_of_bounds():
		queue_free()


## True once the shot has left the visible arena by more than despawn_margin.
## Read off the camera's canvas transform rather than a fixed size, so it still
## culls correctly if the viewport or camera zoom changes.
func _is_out_of_bounds() -> bool:
	var to_world := get_canvas_transform().affine_inverse()
	var screen := get_viewport_rect()
	var world := Rect2(to_world * screen.position, to_world.basis_xform(screen.size))
	return not world.grow(despawn_margin).has_point(global_position)


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
	# Read before damaging - take_damage can free the enemy outright.
	var hit_position := enemy.global_position
	var dealt := damage

	# Overcharge, before any other multiplier: the shot is heavier for every
	# enemy already behind it. _already_hit has just had this enemy added, so
	# subtract it back off to get the count it arrived with.
	if RunState.flag(CardDatabase.FLAG_OVERCHARGE):
		var passed_through := maxi(_already_hit.size() - 1, 0)
		var per_enemy := RunState.modified(CardDatabase.STAT_OVERCHARGE_BONUS,
			overcharge_bonus)
		dealt *= 1.0 + per_enemy * float(passed_through)

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
