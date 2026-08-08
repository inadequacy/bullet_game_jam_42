class_name EnemyProjectile
extends Area2D

## A single enemy spell. The Kind decides how the player is allowed to answer it:
##
##   BLUE  - straight and dense. Not parryable, but destroyed by a parry burst.
##   GREEN - parryable. Parrying one triggers the burst that clears blue.
##   RED   - homing. Not parryable, not cleared. Escaped by dashing only.
##
## RED must travel faster than the player's walk speed, or it never closes the
## gap and the homing is decorative. Set that per-caster via `projectile_speed`.

enum Kind { BLUE, GREEN, RED }

const COLORS := {
	Kind.BLUE: Color(0.35, 0.62, 1.0),
	Kind.GREEN: Color(0.35, 1.0, 0.45),
	Kind.RED: Color(1.0, 0.3, 0.3),
}

@export var kind: Kind = Kind.BLUE
@export var speed: float = 260.0
@export var damage: float = 1.0
## Failsafe despawn so stray shots never accumulate over a 12 minute run.
@export var lifetime: float = 8.0

@export_group("Homing (RED only)")
## Degrees per second the shot can turn toward the player.
##
## Deliberately high enough that walking never escapes. A rate-limited pursuit
## re-aims every frame, so raw displacement - walking OR dashing - does not beat
## it; the dash escapes via `breaks_lock_on_dash` below, not by out-running it.
@export var homing_turn_rate: float = 220.0
## Homing gives up after this long and the shot flies straight, so every red
## projectile eventually becomes escapable even if the player never dashes.
@export var homing_duration: float = 4.0
## Dashing severs the lock: the shot stops tracking and continues straight.
##
## This is what makes dash - and only dash - the answer to red. Tuning turn rate
## alone cannot do it: measured across projectile speeds 600-900 and turn rates
## 90-400, there is no setting where a walking player is hit but a dashing one
## escapes, because a dash is just a brief burst of the same lateral movement.
@export var breaks_lock_on_dash: bool = true

var lock_broken: bool = false

var direction: Vector2 = Vector2.RIGHT

var _age: float = 0.0
var _player: Node2D = null

@onready var _sprite: Sprite2D = $Sprite2D


func _ready() -> void:
	add_to_group("enemy_projectiles")
	_sprite.modulate = COLORS.get(kind, Color.WHITE)
	body_entered.connect(_on_body_entered)
	if kind == Kind.RED:
		_player = get_tree().get_first_node_in_group("player") as Node2D


func _physics_process(delta: float) -> void:
	_age += delta
	if _age >= lifetime:
		queue_free()
		return
	if kind == Kind.RED:
		_home(delta)
	global_position += direction * speed * delta


## Steers toward the player at a capped turn rate. Because the turn is capped,
## enough sideways displacement always beats it - that displacement is what the
## dash is for.
func _home(delta: float) -> void:
	if lock_broken or _age >= homing_duration:
		return
	if _player == null or not is_instance_valid(_player):
		return

	if breaks_lock_on_dash and _player.get("is_dashing") == true:
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


## Severs the lock and dims the shot, so the player can see the dash worked.
func _break_lock() -> void:
	lock_broken = true
	_sprite.modulate = COLORS[Kind.RED].darkened(0.45)


func is_parryable() -> bool:
	return kind == Kind.GREEN


## Whether a successful parry's clear burst destroys this projectile.
func is_cleared_by_parry_burst() -> bool:
	return kind == Kind.BLUE


func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	# The player has no health yet - this stays inert until it does.
	if body.has_method("take_damage"):
		body.take_damage(damage)
	queue_free()
