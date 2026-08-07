class_name EnemyProjectile
extends Area2D

## A single enemy spell. The Kind decides how the player is allowed to answer it:
##
##   BLUE  - straight and dense. Not parryable, but destroyed by a parry burst.
##   GREEN - parryable. Parrying one triggers the burst that clears blue.
##   RED   - homing. Not parryable, not cleared. Escaped by dashing only.
##
## Only BLUE is used so far; the other two are here so the parry and boss work
## can slot in without reworking this script.

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

var direction: Vector2 = Vector2.RIGHT

var _age: float = 0.0

@onready var _sprite: Sprite2D = $Sprite2D


func _ready() -> void:
	add_to_group("enemy_projectiles")
	_sprite.modulate = COLORS.get(kind, Color.WHITE)
	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	_age += delta
	if _age >= lifetime:
		queue_free()
		return
	global_position += direction * speed * delta


## Called by the caster immediately after instantiating.
func launch(from: Vector2, dir: Vector2) -> void:
	global_position = from
	direction = dir.normalized()
	rotation = direction.angle()


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
