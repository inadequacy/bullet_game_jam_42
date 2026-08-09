class_name Chaser
extends Enemy

## Melee enemy. Walks straight at the player and swings on contact - no spells,
## no range keeping. It exists to deny camping: without it the player could sit
## in a corner and out-range every caster.
##
## The swing is deliberately shaped like a cast (wind-up, strike, recovery)
## rather than instant contact damage, so a hit is always the player's mistake
## and never the enemy's pathing.

enum State { CHASING, WINDUP, STRIKE, RECOVERY }

@export_group("Melee")
## Distance at which it commits to a swing.
##
## Must stay larger than the combined collider radii of this enemy and the
## player, or the two bodies stop each other further apart than this range and
## the chaser bumps into the player forever without ever swinging. Re-check
## whenever either collider changes size.
@export var attack_range: float = 75.0
## Extra reach allowed at the moment of the strike, so walking away barely
## escapes but standing still does not.
@export var strike_reach_bonus: float = 12.0
@export var damage: float = 1.0

@export_group("Timing")
## Telegraph before the swing lands. The player's window to leave.
@export var windup_time: float = 0.4
@export var strike_time: float = 0.12
@export var recovery_time: float = 0.7
## Rooting during the swing is what makes the attack dodgeable.
@export var stop_while_attacking: bool = true

var _state: State = State.CHASING
var _state_timer: float = 0.0


func _behavior(delta: float) -> void:
	if not has_player():
		velocity = Vector2.ZERO
		return

	face_player()
	_state_timer += delta

	match _state:
		State.CHASING:
			_chase()
		State.WINDUP:
			_hold()
			if _state_timer >= windup_time:
				_enter_state(State.STRIKE)
				_strike()
		State.STRIKE:
			_hold()
			if _state_timer >= strike_time:
				_enter_state(State.RECOVERY)
		State.RECOVERY:
			_hold()
			if _state_timer >= recovery_time:
				_enter_state(State.CHASING)


func _chase() -> void:
	velocity = direction_to_player() * move_speed
	if distance_to_player() <= attack_range:
		_enter_state(State.WINDUP)
		telegraph(1.3, windup_time, strike_time)


func _hold() -> void:
	if stop_while_attacking:
		velocity = Vector2.ZERO


func _strike() -> void:
	# Re-check range: the player had the whole wind-up to leave.
	if distance_to_player() > attack_range + strike_reach_bonus:
		return
	if player.has_method("take_damage"):
		player.take_damage(damage)


func _enter_state(next: State) -> void:
	_state = next
	_state_timer = 0.0
