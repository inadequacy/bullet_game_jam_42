extends CharacterBody2D


@export var movespeed: int = 400
var movement_allowed = true

# Dash settings
@export_group("Dash Settings")
@export var dash_duration: float = 0.2
@export var dash_cooldown: float = 2.0
@export var dash_speed: int = 800
var dash_allowed = true
## True only while a dash is in progress. Red homing projectiles read this and
## sever their lock, which is what makes dash the counter to homing.
var is_dashing = false
@export_group("")

# Parry settings
@export_group("Parry Settings")
## THE PARRY WINDOW. How long the parry stays active after the key press.
## Lower = tighter and more demanding, higher = more forgiving.
@export var parry_duration: float = 0.2
@export var parry_cooldown: float = 2.0
## How close a green shot must be to count as parried.
@export var parry_radius: float = 90.0
## Radius of the clear burst a successful parry sets off. Destroys blue shots
## only - red is immune, green is what triggered it.
@export var parry_burst_radius: float = 160.0
## Prints parry results to the terminal. Turn off before shipping.
@export var parry_debug_logs: bool = true
@onready var parry_collider = $ParryRadius
var parry_allowed = true
var is_parrying = false
var _parry_window_opened_ms: int = 0
var _parried_this_window: int = 0
@export_group("")

# Attack settings
@export_group("Attack Settings")
signal shoot(projectile, direction, location)
var projectile = preload("res://game/player/player_projectile.tscn")
@export var cast_rate: float = 1.0
## ON  = shots track the nearest enemy, regardless of where you are facing.
## OFF = shots fly along facing (the mouse).
## Press T to flip. This is the starting mode.
@export var auto_aim: bool = true
## Auto-aim ignores enemies further away than this and falls back to facing.
## Zero means no limit - it will always find the nearest enemy on the map.
@export var auto_aim_range: float = 0.0
## Prints the aim mode to the terminal when toggled.
@export var aim_logs: bool = true
var can_attack: bool = true
@export_group("")


# Debug settings
@export_group("Debug")
## Press H to toggle. While on, the player takes no damage - for trying out
## cards without dying. Remove or force off before shipping.
@export var invincible: bool = false
@export var debug_logs: bool = true
@export_group("")


## The HUD health bar, found via the "health_bar" group.
##
## This used to be get_tree().current_scene.get_node("HUD/HealthBar"), which
## hard-coded the level's node layout AND required the level to be the current
## scene. It broke the moment the level was instanced inside anything else -
## a test harness, a wrapper scene, a future level select. The group lookup does
## not care where the bar lives or how the level is loaded.
var health_bar: HealthBar


## Resolves the bar lazily and caches it, so a bar that appears later (or one
## assigned directly, e.g. in a test) is picked up either way.
func find_health_bar() -> HealthBar:
	if health_bar != null and is_instance_valid(health_bar):
		return health_bar

	health_bar = get_tree().get_first_node_in_group("health_bar") as HealthBar
	if health_bar != null and not health_bar.health_depleted.is_connected(_on_health_depleted):
		health_bar.health_depleted.connect(_on_health_depleted)
	return health_bar


func take_damage(amount: float) -> void:
	if invincible:
		if debug_logs:
			print("[DEBUG] blocked %s damage (invincible)" % amount)
		return

	var bar := find_health_bar()
	if bar == null:
		push_warning("No node in the 'health_bar' group - damage ignored.")
		return
	bar.take_damage(amount)


func toggle_invincible() -> void:
	invincible = not invincible
	if debug_logs:
		if invincible:
			print("[DEBUG] INVINCIBLE ON - taking no damage")
		else:
			print("[DEBUG] invincible off - taking damage normally")


## Press Space to dash
func dash_direction(direction: Vector2) -> void:
	movement_allowed = false
	dash_allowed = false
	is_dashing = true

	if direction == Vector2(0.0, 0.0):
		direction = self.transform.x

	velocity = direction * dash_speed
	await get_tree().create_timer(dash_duration).timeout
	is_dashing = false
	movement_allowed = true
	await get_tree().create_timer(dash_cooldown).timeout
	dash_allowed = true


func _ready() -> void:
	# Keep the shape in sync so the parry radius is visible with debug collision
	# shapes on, even though the shape itself stays disabled.
	parry_collider.shape.set_radius(parry_radius)
	# Also hooks up health_depleted. Missing bar is not fatal - the player still
	# works, it just cannot show or lose health.
	find_health_bar()

func _on_health_depleted() -> void:
	get_tree().change_scene_to_file("res://game/ui/end_menu.tscn")

## Set Parry radius
## Maybe update this to be general universal updater later.
func parry_radius_update(new_radius: float) -> void:
	parry_radius = new_radius
	parry_collider.shape.set_radius(new_radius)


## Press Shift to parry
func parry_this_casual() -> void:
	parry_allowed = false
	is_parrying = true
	_parried_this_window = 0
	_parry_window_opened_ms = Time.get_ticks_msec()

	# NOTE: $ParryRadius is a CollisionShape2D on this CharacterBody2D, so
	# enabling it does not detect anything - it inflates the PLAYER'S OWN
	# hurtbox to 90px and eats every projectile that touches it, red included.
	# Parry detection is done by distance in _resolve_parry() instead, and this
	# shape stays disabled. Make it an Area2D child if you ever want real
	# collision-based parrying.
	await get_tree().create_timer(parry_duration).timeout
	is_parrying = false

	if parry_debug_logs and _parried_this_window == 0:
		print("[PARRY] miss    | nothing green within %dpx | window %.2fs"
			% [parry_radius, parry_duration])

	await get_tree().create_timer(parry_cooldown).timeout
	parry_allowed = true


## Runs every physics frame while the window is open. Only GREEN shots can be
## parried; a success destroys that shot and sets off a burst that clears BLUE.
func _resolve_parry() -> void:
	for p in get_tree().get_nodes_in_group("enemy_projectiles"):
		if not is_instance_valid(p):
			continue
		if not p.is_parryable():
			continue
		var dist: float = p.global_position.distance_to(global_position)
		if dist > parry_radius:
			continue

		_parried_this_window += 1
		p.queue_free()
		var cleared := _parry_burst()

		if parry_debug_logs:
			var into := (Time.get_ticks_msec() - _parry_window_opened_ms) / 1000.0
			print("[PARRY] SUCCESS | green parried at %dpx | %.2fs into %.2fs window | burst cleared %d blue"
				% [dist, into, parry_duration, cleared])


## Destroys every blue shot inside the burst radius. Returns how many died.
func _parry_burst() -> int:
	var cleared := 0
	for p in get_tree().get_nodes_in_group("enemy_projectiles"):
		if not is_instance_valid(p):
			continue
		if not p.is_cleared_by_parry_burst():
			continue
		if p.global_position.distance_to(global_position) <= parry_burst_radius:
			p.queue_free()
			cleared += 1
	return cleared


func basic_attack() -> void:
	can_attack = false
	shoot.emit(projectile, aim_angle(), position)
	await get_tree().create_timer(cast_rate).timeout
	can_attack = true


## Direction of the next shot: the nearest enemy while auto-aim is on, otherwise
## wherever the character faces. Falls back to facing when nothing is in range,
## so the player is never left firing at nothing.
func aim_angle() -> float:
	if not auto_aim:
		return rotation
	var target := nearest_enemy()
	if target == null:
		return rotation
	return global_position.direction_to(target.global_position).angle()


## Closest living enemy, or null if there are none within auto_aim_range.
func nearest_enemy() -> Node2D:
	var best: Node2D = null
	var best_dist_sq := INF
	for e in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e):
			continue
		var d: float = global_position.distance_squared_to(e.global_position)
		if d < best_dist_sq:
			best_dist_sq = d
			best = e
	if best != null and auto_aim_range > 0.0 and best_dist_sq > auto_aim_range * auto_aim_range:
		return null
	return best


func toggle_auto_aim() -> void:
	auto_aim = not auto_aim
	if aim_logs:
		if auto_aim:
			print("[AIM] AUTO - shots track the nearest enemy")
		else:
			print("[AIM] MANUAL - shots follow the mouse")


## Toggle targeting

func get_input() -> void:
	# Outside the movement gate so these still register during a dash.
	if Input.is_action_just_pressed("toggle_aim"):
		toggle_auto_aim()

	if Input.is_action_just_pressed("debug_invincible"):
		toggle_invincible()

	if movement_allowed == true:
		look_at(get_global_mouse_position())
		var input_direction = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
		velocity = input_direction * movespeed

		if Input.is_action_just_pressed("dash") && dash_allowed:
			dash_direction(input_direction)

		if Input.is_action_just_pressed("parry") && parry_allowed:
			parry_this_casual()


func _physics_process(_delta) -> void:
	get_input()
	move_and_slide()
	if is_parrying:
		_resolve_parry()
	if can_attack == true:
		basic_attack()
