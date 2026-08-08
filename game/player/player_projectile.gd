extends Area2D

## The player's basic spell. Damages the first enemy it touches, then dies.

var velocity = Vector2.RIGHT
@export var speed: float = 500
## Enemy health values are 20-40, so 10 means 2-4 hits to kill.
@export var damage: float = 10.0
## Failsafe despawn so stray shots never accumulate over a long run.
@export var lifetime: float = 6.0

var _age: float = 0.0


func _ready() -> void:
	add_to_group("player_projectiles")
	body_entered.connect(_on_body_entered)
	# Bake in the run's damage cards at spawn - the export is the base value.
	damage = RunState.modified(CardDatabase.STAT_ATTACK_DAMAGE, damage)


func _process(delta: float) -> void:
	_age += delta
	if _age >= lifetime:
		queue_free()
		return
	position += velocity * delta * speed


func _on_body_entered(body: Node2D) -> void:
	# The player is on the same collision layer and the shot spawns on top of
	# them, so anything that isn't an enemy is ignored rather than filtered out
	# with layers.
	if body is Enemy:
		(body as Enemy).take_damage(damage)
		queue_free()
