class_name EnemyProjectile
extends Area2D

## A single enemy spell. The Kind decides how the player is allowed to answer it:
##
##   BLUE  - straight and dense. Not parryable, but destroyed by a parry burst.
##   GREEN - parryable. Parrying one triggers the burst.
##   RED   - homing. Not parryable, but the burst clears it. At range the dash
##           is still the only answer, since the burst is a short radius.
##
## Purple is not here on purpose: it is Max's colour, and the one hue on screen
## that never has to be dodged.
##
## RED must outpace the player's walk, or the homing is decorative. Its speed is
## set per-caster via `projectile_speed`.

enum Kind { BLUE, GREEN, RED }

const COLORS := {
	Kind.BLUE: Color(0.35, 0.62, 1.0),
	Kind.GREEN: Color(0.35, 1.0, 0.45),
	Kind.RED: Color(1.0, 0.3, 0.3),
}

## How big each colour draws and collides, as a multiple of the shared scene's
## size. RED is the heavy one you dash away from, so it reads twice the size of
## the rest. Kept here rather than in the scene, which every colour shares.
const KIND_SIZE := {
	Kind.BLUE: 1.0,
	Kind.GREEN: 1.0,
	Kind.RED: 2.0,
}

@export var kind: Kind = Kind.BLUE
@export var speed: float = 260.0
@export var damage: float = 1.0
## Failsafe despawn so stray shots never accumulate over a long run.
@export var lifetime: float = 8.0

@export_group("Homing (RED only)")
## Degrees per second the shot turns toward the player. A constant pull, never
## scaled by player speed - it re-aims every frame, so no amount of running beats
## it. The dash escapes by severing the lock, not by out-turning it.
@export var homing_turn_rate: float = 220.0
## Dashing severs the lock and the shot continues straight. This is what makes
## dash the answer to red.
@export var breaks_lock_on_dash: bool = true
## How close the shot must already be for a dash to sever its lock, so one press
## cannot unhook every red on the map. Sized against the dash: 800 x 0.2 = 160px
## of travel.
@export var break_lock_radius: float = 200.0
## Extra room outside the visible arena before a shot is culled. A lock that has
## been broken flies straight forever, so this is what actually retires it.
@export var despawn_margin: float = 160.0
## Shove on contact, along the shot's travel. RED only - stacking shoves from a
## blue volley would take control away from the player entirely.
@export var knockback_strength: float = 320.0
@export_group("")
## Extra multiplier on top of the colour's own size in KIND_SIZE, set by the
## caster. Escalations that trade one shot for several use it to make the
## several smaller - see Caster's tier_projectile_scale.
@export var size_scale: float = 1.0

var lock_broken: bool = false

var direction: Vector2 = Vector2.RIGHT

var _age: float = 0.0
var _player: Node2D = null

@onready var _sprite: Sprite2D = $Sprite2D


func _ready() -> void:
	add_to_group("enemy_projectiles")
	_sprite.modulate = COLORS.get(kind, Color.WHITE)
	body_entered.connect(_on_body_entered)
	_apply_size()
	if kind == Kind.RED:
		_player = get_tree().get_first_node_in_group("player") as Node2D


## Sizes the sprite and the hurtbox together, so what you see is what hits you.
##
## Duplicates the shape first - the sub-resource is shared by every instance of
## the scene, so resizing it in place would resize every other shot too. The
## Area2D root is left unscaled, since Godot handles a scaled physics node
## poorly.
func _apply_size() -> void:
	var scale_factor: float = KIND_SIZE.get(kind, 1.0) * size_scale
	if is_equal_approx(scale_factor, 1.0):
		return

	_sprite.scale *= scale_factor

	var circle := $CollisionShape2D.shape as CircleShape2D
	if circle == null:
		return
	var resized: CircleShape2D = circle.duplicate()
	resized.radius *= scale_factor
	$CollisionShape2D.shape = resized


func _physics_process(delta: float) -> void:
	_age += delta
	if _age >= lifetime:
		queue_free()
		return
	if kind == Kind.RED:
		_home(delta)
	global_position += direction * speed * delta
	if _is_out_of_bounds():
		queue_free()


## Steers toward the player at a capped rate for as long as the shot lives -
## there is no age-based giveup. The dash only counts from inside
## break_lock_radius, so dashing early spends the charge for nothing.
func _home(delta: float) -> void:
	if lock_broken:
		return
	if _player == null or not is_instance_valid(_player):
		return

	if breaks_lock_on_dash and _player.get("is_dashing") == true:
		if global_position.distance_to(_player.global_position) <= break_lock_radius:
			_break_lock()
			return

	var desired := global_position.direction_to(_player.global_position)
	var max_turn := deg_to_rad(homing_turn_rate) * delta
	direction = direction.rotated(clampf(direction.angle_to(desired), -max_turn, max_turn))
	rotation = direction.angle()


## Called by the caster immediately after instantiating.
func launch(from: Vector2, dir: Vector2) -> void:
	global_position = from
	direction = dir.normalized()
	rotation = direction.angle()


## True once the shot has left the visible arena by more than despawn_margin.
func _is_out_of_bounds() -> bool:
	return not View.holds(self, global_position, despawn_margin)


## Severs the lock, dims the shot so the player can see the dash worked, and
## refunds the charge that broke it.
func _break_lock() -> void:
	lock_broken = true
	_sprite.modulate = COLORS[Kind.RED].darkened(0.45)
	if (_player != null and is_instance_valid(_player)
			and _player.has_method("refund_dash_charge")):
		_player.refund_dash_charge()


## Whether a parry window can catch this shot outright. GREEN always; RED only
## with Crimson Guard. Even then a parry only answers the red already on top of
## you - the dash is still what answers one crossing the arena.
func is_parryable() -> bool:
	if kind == Kind.GREEN:
		return true
	return kind == Kind.RED and RunState.flag(CardDatabase.FLAG_PARRY_RED)


## Whether a parry's clear burst destroys this shot. Every colour but green -
## green is excluded so one parry cannot answer a whole volley of the colour
## meant to be read shot by shot.
func is_cleared_by_parry_burst() -> bool:
	return kind != Kind.GREEN


## Whether touching the player spends the shot even when the damage was blocked
## by i-frames. True for all but GREEN, which carries on so it can still be
## parried.
func is_consumed_on_contact() -> bool:
	return kind != Kind.GREEN


func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return

	if kind == Kind.RED and body.has_method("apply_knockback"):
		body.apply_knockback(direction, knockback_strength)

	var landed := true
	if body.has_method("take_damage"):
		var result = body.take_damage(damage)
		# A caller that returns nothing counts as a hit.
		landed = result != false

	if landed or is_consumed_on_contact():
		queue_free()
