extends CharacterBody2D


@export var movespeed: int = 340
var movement_allowed = true

var random_names = ["Aspen", "Landen", "Yousef", 
		"Lesli", "Kacie", "Tia", "Chancellor", 
		"Dianna", "Brycen", "Kylee", "Ashlynn", 
		"Deontae", "Fredrick", "Gwendolyn", "Jaeden", 
		"Ibrahim", "Alma", "Serenity", "Maranda", 
		"Emelia", "Beatriz", "Rylee", "Donnie", "Alanis", "Andrea"]

# Dash settings
@export_group("Dash Settings")
@export var dash_duration: float = 0.2
@export var dash_cooldown: float = 2.0
@export var dash_speed: int = 800
## Charges the player starts with. Cards add to this via STAT_DASH_CHARGES.
@export var base_dash_charges: int = 1

## Charges available right now. Spending is instant; recovery is one charge at
## a time, each taking a full cooldown - so burning two in a row means waiting
## one cooldown for the first back, then another for the second.
var dash_charges: int = 1
## Seconds accumulated toward the next charge.
var _dash_recharge: float = 0.0
## Last known maximum, so a card that raises it can hand over the new charge.
var _known_max_charges: int = 1
## True only while a dash is in progress. Red homing projectiles read this and
## sever their lock, which is what makes dash the counter to homing.
var is_dashing = false
@export_group("")

# Parry settings
@export_group("Parry Settings")
## THE PARRY WINDOW. How long the parry stays active after the key press.
## Lower = tighter and more demanding, higher = more forgiving.
@export var parry_duration: float = 0.2
## Lockout after the window shuts. Short on purpose - the parry is already
## self-limiting, because a mistimed one leaves you standing in the shot.
## The ParryBar is what stops this from feeling arbitrary; without the readout
## a spent parry is indistinguishable from a broken one.
@export var parry_cooldown: float = 0.4
## How close a green shot must be to count as parried.
@export var parry_radius: float = 90.0
## Radius of the clear burst a successful parry sets off. Destroys blue AND red
## inside it; green is excluded, being what triggered it.
##
## This is the BASE. Cards scale it through STAT_PARRY_BURST_RADIUS, and both the
## kill field and the ring drawn on screen read the modified value, so a bigger
## radius is always visibly bigger.
@export var parry_burst_radius: float = 160.0
## How long the clear field stays up after a parry.
##
## The burst is not an instant snapshot. It used to be, and the ring - which
## takes this long to expand - would visibly sweep over shots that survived,
## because they had been outside the radius at the single instant it was
## measured. Holding the field open for the ring's whole life makes the promise
## the visual is making true: what the circle covers, dies.
@export var parry_burst_duration: float = 0.28
## Prints parry results to the terminal. Turn off before shipping.
@export var parry_debug_logs: bool = true
@onready var parry_collider = $ParryRadius
## Optional - only used for the i-frame tint, so a renamed sprite is harmless.
@onready var _body_sprite: Sprite2D = get_node_or_null("CharacterImage")
var _body_base_modulate: Color = Color.WHITE
var parry_allowed = true
var is_parrying = false
var _parry_window_opened_ms: int = 0
var _parried_this_window: int = 0
## Seconds left in the open window, then in the lockout after it.
##
## These are ticked in _physics_process rather than awaited on a SceneTreeTimer,
## which the dash cooldown already does. An awaited timer knows only "not yet" -
## it cannot say how far along it is, so a UI readout is impossible without it.
var _parry_window_left: float = 0.0
var _parry_cooldown_left: float = 0.0
## Length of the lockout currently running, so the bar has a denominator.
var _parry_cooldown_span: float = 0.0
## Set by a parry that connected. A parry that lands costs NO cooldown - the
## lockout exists to punish a wild press, so landing one should not be punished
## at all. Chaining parries back to back is the intended reward for reading the
## screen correctly.
var _parry_refunded: bool = false
## Seconds the clear field has left, and the radius it is holding. The radius is
## snapshotted when the parry lands so a card taken mid-burst cannot resize a
## field that is already up and no longer matches the ring on screen.
var _burst_left: float = 0.0
var _burst_radius: float = 0.0
@export_group("")

# Impact settings
@export_group("Impact")
## How hard a hit shoves the player. Deliberately small - this is feedback that
## the shot connected, not a control loss.
@export var knockback_strength: float = 320.0
## Seconds a shove takes to decay to nothing.
@export var knockback_decay: float = 0.18
## Screen shake that rides along with a shove, in pixels of offset. A little
## harder than the parry's 3.0 thump - this one is a hit landing ON you, rather
## than one you answered. The shake runs for knockback_decay so the picture
## settles at the same moment the player stops sliding.
@export var knockback_shake_strength: float = 4.5

## Carried separately from `velocity` because get_input() overwrites velocity
## outright every frame from the movement keys - anything written straight into
## it is gone before move_and_slide() ever sees it. This is added on top instead.
var _knockback: Vector2 = Vector2.ZERO
## Units per second the shove sheds, so a full-strength one lasts exactly
## knockback_decay and a weaker one ends sooner.
var _knockback_drop: float = 0.0
@export_group("")
# Sounds
var attack_sound = preload("res://assets/sounds/magic_attack1.wav")
var parry_sound = preload("res://assets/sounds/parry1.wav")
var dash_sound = preload("res://assets/sounds/dash1.wav")
var healing_sound = preload("res://assets/sounds/healing1.wav")
var levelup_sound = preload("res://assets/sounds/level_up1.wav")
var playerhit_dog_sound = preload("res://assets/sounds/playerhit_dog1.wav")
var playerhit_low_sound = preload("res://assets/sounds/playerhit_low1.wav")

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


## Leaderboard name for this run, submitted to SilentWolf on death.
var my_name: String

# Debug settings
@export_group("Debug")
## Press H to toggle. While on, the player takes no damage - for trying out
## cards without dying. Remove or force off before shipping.
@export var invincible: bool = false
@export var debug_logs: bool = true
@export_group("")


# --- Card-modified stats -----------------------------------------------------
# The exports above are BASE values. Never use them directly in gameplay - go
# through these, so any card that touches the stat applies automatically.

func effective_move_speed() -> float:
	return RunState.modified(CardDatabase.STAT_MOVE_SPEED, movespeed)

func effective_dash_cooldown() -> float:
	return RunState.modified(CardDatabase.STAT_DASH_COOLDOWN, dash_cooldown)

func effective_parry_window() -> float:
	return RunState.modified(CardDatabase.STAT_PARRY_WINDOW, parry_duration)

func effective_parry_cooldown() -> float:
	return RunState.modified(CardDatabase.STAT_PARRY_COOLDOWN, parry_cooldown)

func effective_parry_burst_radius() -> float:
	return RunState.modified(CardDatabase.STAT_PARRY_BURST_RADIUS, parry_burst_radius)

func effective_cast_interval() -> float:
	return RunState.modified(CardDatabase.STAT_CAST_INTERVAL, cast_rate)


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


## True while the Phase Step card is owned. A plain dash has NO i-frames - that
## is the whole reason red homing is dangerous, so this is a keystone upgrade.
func has_dash_iframes() -> bool:
	return RunState.flag(CardDatabase.FLAG_DASH_IFRAMES)


## Anything that would hurt the player checks this. Covers the debug toggle and
## an i-frame dash.
func is_invulnerable() -> bool:
	return invincible or (is_dashing and has_dash_iframes())


## Returns TRUE only if the damage actually landed.
##
## Callers that represent a physical object - a projectile - should consume
## themselves only when it did. Freeing on a blocked hit would turn i-frames
## into a screen clear, which is the parry's job, not the dash's.
func take_damage(amount: float) -> bool:
	SoundManager.play_sfx(playerhit_dog_sound, 0, 0.85, 1.1, 0)
	SoundManager.play_sfx(playerhit_low_sound, 0, 0.85, 1.1, 0)
	if invincible:
		if debug_logs:
			print("[DEBUG] blocked %s damage (invincible)" % amount)
		return false

	if is_dashing and has_dash_iframes():
		if debug_logs:
			print("[DASH] i-frames absorbed %s damage" % amount)
		return false

	var bar := find_health_bar()
	if bar == null:
		push_warning("No node in the 'health_bar' group - damage ignored.")
		return false
	bar.take_damage(amount)
	return true


func toggle_invincible() -> void:
	invincible = not invincible
	if debug_logs:
		if invincible:
			print("[DEBUG] INVINCIBLE ON - taking no damage")
		else:
			print("[DEBUG] invincible off - taking damage normally")


# --- Dash charges ------------------------------------------------------------

## How many charges the player can hold, base plus any cards.
func max_dash_charges() -> int:
	return maxi(1, int(round(RunState.modified(
		CardDatabase.STAT_DASH_CHARGES, base_dash_charges))))


func can_dash() -> bool:
	return dash_charges > 0


## Progress toward the next charge, 0..1. Zero when the pool is full.
func dash_recharge_ratio() -> float:
	if dash_charges >= max_dash_charges():
		return 0.0
	var cooldown := effective_dash_cooldown()
	if cooldown <= 0.0:
		return 1.0
	return clampf(_dash_recharge / cooldown, 0.0, 1.0)


## Refills one charge per cooldown, never more than one at a time. The leftover
## is carried so a long frame cannot swallow part of the next recharge.
func _tick_dash_recharge(delta: float) -> void:
	var maximum := max_dash_charges()
	if dash_charges >= maximum:
		_dash_recharge = 0.0
		return

	_dash_recharge += delta
	var cooldown := effective_dash_cooldown()
	if _dash_recharge >= cooldown:
		_dash_recharge -= cooldown
		dash_charges += 1
		if dash_charges >= maximum:
			_dash_recharge = 0.0


## Hands back one charge, up to the maximum. Called when a red projectile loses
## its lock, so severing one is free.
##
## Without this, answering red correctly left the player with no dash and a
## cooldown to wait out, which is the worst possible moment to be immobile - the
## caster is already winding up the next one. Refunding turns the dash into the
## dedicated answer to red rather than a resource red drains.
##
## Deliberately not routed through _dash_recharge: this is a whole charge landing
## now, not progress toward one.
func refund_dash_charge() -> void:
	var maximum := max_dash_charges()
	if dash_charges >= maximum:
		return
	dash_charges += 1
	if dash_charges >= maximum:
		_dash_recharge = 0.0
	if debug_logs:
		print("[DASH] lock broken - charge refunded | %d/%d" % [dash_charges, maximum])


## A card raising the maximum hands over the extra charge immediately, rather
## than making the player wait a cooldown for something they just bought.
func _on_run_stats_changed() -> void:
	var maximum := max_dash_charges()
	if maximum > _known_max_charges:
		dash_charges += maximum - _known_max_charges
	_known_max_charges = maximum
	dash_charges = clampi(dash_charges, 0, maximum)


## Goes translucent and cold for the length of an invulnerable dash, then
## settles back to whatever the sprite normally looks like.
func _show_iframes(duration: float) -> void:
	if _body_sprite == null:
		return
	var tween := create_tween()
	tween.tween_property(_body_sprite, "modulate",
		Color(0.6, 0.9, 1.0, 0.5), duration * 0.2)
	tween.tween_property(_body_sprite, "modulate",
		_body_base_modulate, duration * 0.8)


## Press Space to dash
func dash_direction(direction: Vector2) -> void:
	if not can_dash():
		return

	dash_charges -= 1
	movement_allowed = false
	is_dashing = true
	# Anything still shoving the player is cancelled by the dash taking over.
	_knockback = Vector2.ZERO

	if direction == Vector2(0.0, 0.0):
		direction = self.transform.x

	# An i-frame dash has to look different, or the player cannot tell whether
	# the card is doing anything.
	if has_dash_iframes():
		_show_iframes(dash_duration)

	velocity = direction * dash_speed
	await get_tree().create_timer(dash_duration).timeout
	is_dashing = false
	movement_allowed = true

func _ready() -> void:
	# Keep the shape in sync so the parry radius is visible with debug collision
	# shapes on, even though the shape itself stays disabled.
	parry_collider.shape.set_radius(parry_radius)

	# One name per run, reused if the player restarts. GameManager holds it so it
	# survives the scene change to the end menu, where the score is shown.
	if !GameManager.player_name:
		my_name = random_names.pick_random()
		GameManager.player_name = my_name
	else:
		my_name = GameManager.player_name

	# Also hooks up health_depleted. Missing bar is not fatal - the player still
	# works, it just cannot show or lose health.
	find_health_bar()

	_known_max_charges = max_dash_charges()
	dash_charges = _known_max_charges
	RunState.stats_changed.connect(_on_run_stats_changed)

	if _body_sprite != null:
		_body_base_modulate = _body_sprite.modulate

func _on_health_depleted() -> void:
	SilentWolf.Scores.save_score(my_name, GameManager.score)
	GameManager.message = "You lost, " + my_name + "!"
	get_tree().change_scene_to_file("res://game/ui/end_menu.tscn")


## Set Parry radius
## Maybe update this to be general universal updater later.
func parry_radius_update(new_radius: float) -> void:
	parry_radius = new_radius
	parry_collider.shape.set_radius(new_radius)


## Press Shift to parry
func parry_this_casual() -> void:
	if not parry_allowed:
		return

	# After the guard, not before it. Played first, the parry sound fired on every
	# press including ones the cooldown refused, so a locked-out parry was
	# indistinguishable by ear from a real one - exactly the confusion the
	# ParryBar was added to clear up.
	SoundManager.play_sfx(parry_sound)

	parry_allowed = false
	is_parrying = true
	_parried_this_window = 0
	_parry_refunded = false
	_parry_window_opened_ms = Time.get_ticks_msec()

	# NOTE: $ParryRadius is a CollisionShape2D on this CharacterBody2D, so
	# enabling it does not detect anything - it inflates the PLAYER'S OWN
	# hurtbox to 90px and eats every projectile that touches it, red included.
	# Parry detection is done by distance in _resolve_parry() instead, and this
	# shape stays disabled. Make it an Area2D child if you ever want real
	# collision-based parrying.
	#
	# The window length is snapshotted here, not re-read while it runs, so a card
	# taken mid-parry cannot stretch a window that is already open.
	_parry_window_left = effective_parry_window()
	_parry_cooldown_left = 0.0
	_parry_cooldown_span = 0.0


## Runs the open window down, then the lockout. Split from the window itself so
## _resolve_parry() and the UI can both read where in the cycle we are.
func _tick_parry(delta: float) -> void:
	if is_parrying:
		_parry_window_left -= delta
		if _parry_window_left > 0.0:
			return

		_parry_window_left = 0.0
		is_parrying = false
		if parry_debug_logs and _parried_this_window == 0:
			print("[PARRY] miss    | nothing green within %dpx | window %.2fs"
				% [parry_radius, effective_parry_window()])

		# A parry that connected already refunded itself the moment it landed;
		# don't hand it a lockout now that the window has run out.
		if not _parry_refunded:
			_parry_cooldown_span = maxf(effective_parry_cooldown(), 0.0)
			_parry_cooldown_left = _parry_cooldown_span
		parry_allowed = _parry_cooldown_left <= 0.0
		return

	if _parry_cooldown_left > 0.0:
		_parry_cooldown_left = maxf(_parry_cooldown_left - delta, 0.0)
		if _parry_cooldown_left <= 0.0:
			parry_allowed = true


# --- Parry readouts (ParryBar polls these) -----------------------------------

## True only while the window is open. The window is a fifth of a second, so the
## UI needs to be told about it explicitly - it is easy to miss on screen.
func parry_is_active() -> bool:
	return is_parrying

## True when a parry can be started right now.
func parry_is_ready() -> bool:
	return parry_allowed

## Lockout recovery, 0..1. Reads 1.0 whenever the parry is up, and 0.0 for the
## length of the open window, so the bar drains and refills once per use.
func parry_cooldown_ratio() -> float:
	if parry_allowed:
		return 1.0
	if is_parrying or _parry_cooldown_span <= 0.0:
		return 0.0
	return clampf(1.0 - _parry_cooldown_left / _parry_cooldown_span, 0.0, 1.0)


## Runs every physics frame while the window is open. Only GREEN shots can be
## parried; a success destroys that shot and sets off a burst that clears every
## other colour around the player.
func _resolve_parry() -> void:
	for p in get_tree().get_nodes_in_group("enemy_projectiles"):
		if not is_instance_valid(p):
			continue
		if not p.is_parryable():
			continue
		var dist: float = p.global_position.distance_to(global_position)
		if dist > parry_radius:
			continue

		p.queue_free()
		var cleared := _parry_succeeded()

		if parry_debug_logs:
			var into := (Time.get_ticks_msec() - _parry_window_opened_ms) / 1000.0
			print("[PARRY] SUCCESS | green shot parried at %dpx | %.2fs into %.2fs window | burst cleared %d shots | cooldown refunded"
				% [dist, into, effective_parry_window(), cleared])


## Called by a hitscan attack at the instant it fires. Returns true if the
## player was parrying, which eats the shot entirely.
##
## Hitscan cannot be dodged - the trace is instant - so the parry has to be
## already active when this is called. The player reacts to the caster's charge
## glow, never to the trace.
func try_parry_hitscan(_from: Vector2) -> bool:
	if not is_parrying:
		return false

	var cleared := _parry_succeeded()
	if parry_debug_logs:
		var into := (Time.get_ticks_msec() - _parry_window_opened_ms) / 1000.0
		print("[PARRY] SUCCESS | hitscan parried | %.2fs into %.2fs window | burst cleared %d shots | cooldown refunded"
			% [into, effective_parry_window(), cleared])
	return true


## Everything a successful parry does, whatever it caught: refunds the cooldown,
## clears the shots around the player, throws up the ring, and thumps the screen.
## Returns how many shots the burst destroyed.
func _parry_succeeded() -> int:
	_parried_this_window += 1

	# Refunded here rather than when the window shuts, so the bar reads full the
	# instant the parry connects instead of a fifth of a second later.
	_parry_refunded = true
	_parry_cooldown_left = 0.0
	_parry_cooldown_span = 0.0
	parry_allowed = true

	# One radius for the field, the ring and the tick that follows, so the three
	# can never disagree about how big the burst was.
	_burst_radius = effective_parry_burst_radius()
	_burst_left = parry_burst_duration
	var cleared := _parry_burst()

	ParryFlash.burst(get_parent(), global_position, _burst_radius, parry_burst_duration)
	# No arguments: the parry is what CameraShake's defaults were tuned for.
	_shake_camera()

	return cleared


## Keeps the clear field up for as long as the ring is on screen, so a shot that
## flies into the circle after the parry lands dies like everything else in it.
func _tick_parry_burst(delta: float) -> void:
	if _burst_left <= 0.0:
		return
	_burst_left -= delta
	_parry_burst()


## Thumps the screen, if the level has a camera that can. Negative values fall
## back to CameraShake's own defaults. A weaker shake will not cut a stronger one
## short, so a red hit landing during a parry still reads as the bigger event.
func _shake_camera(strength: float = -1.0, duration: float = -1.0) -> void:
	var camera := get_tree().get_first_node_in_group("camera_shake")
	if camera != null and camera.has_method("shake"):
		camera.shake(strength, duration)


## Destroys every shot the burst is allowed to take inside its radius - blue and
## red both, green excluded. Returns how many died.
func _parry_burst() -> int:
	var cleared := 0
	for p in get_tree().get_nodes_in_group("enemy_projectiles"):
		# queue_free leaves the node in its group until the end of the frame, so
		# without this a shot killed by the burst is recounted on the next tick.
		if not is_instance_valid(p) or p.is_queued_for_deletion():
			continue
		if not p.is_cleared_by_parry_burst():
			continue
		if p.global_position.distance_to(global_position) <= _burst_radius:
			p.queue_free()
			cleared += 1
	return cleared


## Shoves the player along `dir` - called by whatever hit them, so the push
## follows the shot's own travel direction rather than pointing away from its
## source. Passing a negative strength uses knockback_strength.
func apply_knockback(dir: Vector2, strength: float = -1.0) -> void:
	if dir == Vector2.ZERO:
		return

	# The hit still registers on screen even when the shove itself is refused.
	_shake_camera(knockback_shake_strength, knockback_decay)

	# A DASH OWNS MOVEMENT OUTRIGHT. Stacking a shove on top adds to dash_speed
	# rather than replacing it, which threw the player most of the way across the
	# arena - and being flung further for having dodged is worse than not being
	# shoved at all. The shove is dropped, not queued: by the time the dash ends
	# the hit is old news.
	if is_dashing:
		return

	var force := knockback_strength if strength < 0.0 else strength
	if force <= 0.0:
		return
	# Replaced rather than accumulated: two hits in the same instant should shove
	# once, not launch the player at double speed.
	_knockback = dir.normalized() * force
	_knockback_drop = force / maxf(knockback_decay, 0.001)


func _decay_knockback(delta: float) -> void:
	if _knockback != Vector2.ZERO:
		_knockback = _knockback.move_toward(Vector2.ZERO, _knockback_drop * delta)


func basic_attack() -> void:
	can_attack = false
	SoundManager.play_sfx(attack_sound, 0.2, 0.85, 1.1, 0)
	
	shoot.emit(projectile, aim_angle(), position)
	await get_tree().create_timer(effective_cast_interval()).timeout
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
		velocity = input_direction * effective_move_speed()

		if Input.is_action_just_pressed("dash") && can_dash():
			dash_direction(input_direction)

		if Input.is_action_just_pressed("parry") && parry_allowed:
			parry_this_casual()


func _physics_process(_delta) -> void:
	get_input()
	# After get_input, which has just overwritten velocity from the movement keys.
	# Skipped mid-dash: apply_knockback already refuses a shove while dashing, but
	# one applied a frame BEFORE the dash started would still be decaying, and it
	# would add to dash_speed exactly the same way.
	if not is_dashing:
		velocity += _knockback
	move_and_slide()
	_decay_knockback(_delta)
	_tick_dash_recharge(_delta)
	# Resolve before ticking, so the frame that closes the window still counts.
	if is_parrying:
		_resolve_parry()
	_tick_parry(_delta)
	_tick_parry_burst(_delta)
	if can_attack == true:
		basic_attack()
