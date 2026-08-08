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
## Degrees per second the shot can turn toward the player. A CONSTANT pull:
## it is a property of the projectile, never scaled by how fast the player is
## moving, so outrunning the shot does not weaken its tracking.
##
## A rate-limited pursuit re-aims every frame, so raw displacement - walking OR
## dashing - does not beat it; the dash escapes by severing the lock outright,
## not by out-running the turn.
@export var homing_turn_rate: float = 220.0
## Dashing severs the lock: the shot stops tracking and continues straight.
##
## This is what makes dash - and only dash - the answer to red. Tuning turn rate
## alone cannot do it: measured across projectile speeds 600-900 and turn rates
## 90-400, there is no setting where a walking player is hit but a dashing one
## escapes, because a dash is just a brief burst of the same lateral movement.
@export var breaks_lock_on_dash: bool = true
## How close the shot must ALREADY BE for a dash to sever its lock.
##
## Without this the dash is a screen-wide cancel: one press unhooked every red
## on the map no matter how far away, so the answer to red was to dash on
## cooldown and never look at it. Gating on distance makes the dash a timed
## commitment - dodge too early and the shot simply re-aims and keeps coming.
##
## Sized against the dash itself: dash_speed 800 x dash_duration 0.2 = 160px of
## travel, so a shot released at this range is displaced clear of the player.
@export var break_lock_radius: float = 200.0
## Extra room outside the visible arena before a shot is culled. A lock that has
## been broken flies straight forever, so this is what actually retires it.
@export var despawn_margin: float = 160.0
## RED is drawn and collides at this multiple of the base size.
##
## Applied here rather than in the scene because enemy_projectile.tscn is shared
## by all three colours - growing it there would fatten blue and green too.
@export var red_size_scale: float = 2.0

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
		_apply_red_size()


## Grows RED's sprite and its hurtbox together, so what you see is what hits you.
##
## The shape is DUPLICATED first. A sub-resource is shared by every instance of a
## packed scene, so scaling the radius in place would fatten blue and green as
## well - and permanently, since the resource outlives the projectile that
## touched it. Scaling the Area2D root instead would be simpler but puts a scale
## on a physics node, which Godot handles poorly.
func _apply_red_size() -> void:
	if is_equal_approx(red_size_scale, 1.0):
		return

	_sprite.scale *= red_size_scale

	var circle := $CollisionShape2D.shape as CircleShape2D
	if circle == null:
		return
	var grown: CircleShape2D = circle.duplicate()
	grown.radius *= red_size_scale
	$CollisionShape2D.shape = grown


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


## Steers toward the player at a capped turn rate, for as long as the shot lives.
##
## There is no age-based giveup. The pull is unconditional - the shot is coming
## for you until you break it or it leaves the arena - so a red on screen is a
## problem you have to answer rather than one you can wait out.
##
## The dash only counts as an answer from inside break_lock_radius. Dash while
## the shot is still distant and this falls straight through to the steering
## below: the shot re-aims and keeps coming, and the dash is spent for nothing.
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
##
## Derived from the camera's view rather than a hard-coded 1152x648 rect, so it
## still culls correctly if the viewport or the camera zoom ever changes. The
## margin absorbs camera shake, which nudges the view a few pixels per frame.
func _is_out_of_bounds() -> bool:
	var to_world := get_canvas_transform().affine_inverse()
	var screen := get_viewport_rect()
	var world := Rect2(to_world * screen.position, to_world.basis_xform(screen.size))
	return not world.grow(despawn_margin).has_point(global_position)


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

	# Only spend the shot if the hit actually landed. A blocked hit - i-frames,
	# or the debug toggle - lets the shot fly on through, so invulnerability
	# never doubles as a screen clear.
	var landed := true
	if body.has_method("take_damage"):
		var result = body.take_damage(damage)
		# Older callers returned nothing; treat that as a hit.
		landed = result != false

	if landed:
		queue_free()
