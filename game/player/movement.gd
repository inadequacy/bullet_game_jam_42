extends CharacterBody2D


@export var movespeed: int = 340
var movement_allowed = true

var random_names = ["Aspen", "Landen", "Yousef", 
		"Lesli", "Kacie", "Tia", "Chancellor", 
		"Dianna", "Brycen", "Kylee", "Ashlynn", 
		"Deontae", "Fredrick", "Gwendolyn", "Jaeden", 
		"Ibrahim", "Alma", "Serenity", "Maranda", 
		"Emelia", "Beatriz", "Rylee", "Donnie", "Alanis", "Andrea"]

@export_group("Dash Settings")
@export var dash_duration: float = 0.2
@export var dash_cooldown: float = 2.0
@export var dash_speed: int = 800
## Charges the player starts with. Cards add to this via STAT_DASH_CHARGES.
@export var base_dash_charges: int = 1

## Charges available right now. Recovery is one charge at a time, each taking a
## full cooldown.
var dash_charges: int = 1
## Seconds accumulated toward the next charge.
var _dash_recharge: float = 0.0
## Last known maximum, so a card that raises it can hand over the new charge.
var _known_max_charges: int = 1
## How long Phase Step's invulnerability runs after the dash ends.
@export var dash_iframe_grace: float = 0.18

## True only while a dash is in progress. Red homing projectiles read this and
## sever their lock.
var is_dashing = false
## Seconds of invulnerability left. Only set by a dash with Phase Step, and
## tracked separately from `is_dashing` so it can outlive the dash by
## dash_iframe_grace.
var _iframes_left: float = 0.0
@export_group("")

@export_group("Parry Settings")
## How long the parry stays active after the key press. Lower = tighter and more
## demanding, higher = more forgiving.
@export var parry_duration: float = 0.24
## Lockout after the window shuts. Short on purpose - the parry is already
## self-limiting, because a mistimed one leaves you standing in the shot.
@export var parry_cooldown: float = 0.4
## How close a green shot must be to count as parried.
@export var parry_radius: float = 90.0
## Radius of the clear burst a parry sets off - blue and red inside it die,
## green is excluded. Base value; cards scale it through STAT_PARRY_BURST_RADIUS
## and both the kill field and the ring read the modified value.
@export var parry_burst_radius: float = 160.0
## How long the clear field stays up. The field is held open for exactly as long
## as the ring takes to expand, so the ring can never visibly sweep over a
## survivor.
@export var parry_burst_duration: float = 0.28
## How strongly the ring draws on the press itself - input feedback, so it
## cannot wait to learn whether the parry landed. Set to 1.0 for a press ring as
## loud as a success.
@export_range(0.0, 1.0, 0.05) var parry_attempt_flash_alpha: float = 0.55
## Prints parry results to the terminal.
@export var parry_debug_logs: bool = true
@onready var parry_collider = $ParryRadius
## Optional - only used for the i-frame tint, so a renamed sprite is harmless.
@onready var _body_sprite: Sprite2D = get_node_or_null("CharacterImage")
var _body_base_modulate: Color = Color.WHITE
var parry_allowed = true
var is_parrying = false
## The press ring, kept only so a parry that lands can take it back down - see
## _parry_succeeded(). Null whenever there is nothing to retract.
var _parry_attempt_flash: ParryFlash = null
var _parry_window_opened_ms: int = 0
var _parried_this_window: int = 0
## Seconds left in the open window, then in the lockout. Ticked here rather than
## awaited on a SceneTreeTimer so the UI can read progress.
var _parry_window_left: float = 0.0
var _parry_cooldown_left: float = 0.0
## Length of the lockout currently running, so the bar has a denominator.
var _parry_cooldown_span: float = 0.0
## Set by a parry that connected. A landed parry costs no cooldown - the lockout
## punishes a wild press, and chaining parries is the intended reward.
var _parry_refunded: bool = false
## Seconds the clear field has left, and the radius it is holding. The radius is
## snapshotted when the parry lands so a card taken mid-burst cannot resize a
## field that is already up.
var _burst_left: float = 0.0
var _burst_radius: float = 0.0
@export_group("")

@export_group("Impact")
## How hard a hit shoves the player. Deliberately small - this is feedback that
## the shot connected, not a control loss.
@export var knockback_strength: float = 320.0
## Seconds a shove takes to decay to nothing.
@export var knockback_decay: float = 0.18
## Screen shake that rides along with a shove, in pixels of offset. Runs for
## knockback_decay, so the picture settles as the player stops sliding.
@export var knockback_shake_strength: float = 4.5

## Separate from `velocity`, which get_input() overwrites every frame - anything
## written into it is gone before move_and_slide() sees it.
var _knockback: Vector2 = Vector2.ZERO
## Units per second the shove sheds, so a full-strength one lasts exactly
## knockback_decay and a weaker one ends sooner.
var _knockback_drop: float = 0.0
@export_group("")

var parry_sound = preload("res://assets/sounds/parry1.wav")
var dash_sound = preload("res://assets/sounds/dash1.wav")
var levelup_sound = preload("res://assets/sounds/level_up1.wav") # used by the ultimate
var playerhit_dog_sound = preload("res://assets/sounds/playerhit_dog1.wav")
var playerhit_low_sound = preload("res://assets/sounds/playerhit_low1.wav")

@export_group("Attack Settings")
signal shoot(projectile, direction, location)
var projectile = preload("res://game/player/player_projectile.tscn")
## Seconds between casts, before Rapid Casting.
@export var cast_rate: float = 0.8
## Shots per cast before any card. Arcane Volley and Split Bolt add to this.
@export var base_projectile_count: int = 1
## Total arc a multi-shot cast is spread across, in degrees. Only ever visible
## once a card has raised the count above one.
@export var volley_spread_degrees: float = 18.0
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

@export_group("Art")
## Max's resting pose. Also what he reverts to after an attack.
@export var idle_texture: Texture2D
## Shown whenever Max releases something - a cast or an ultimate.
@export var attack_texture: Texture2D
## How long the attack pose is held for a basic cast, and for the Fire and Ice
## ultimates. The Arcane ultimate holds the pose for as long as the beam is out
## instead - see cast_ultimate().
##
## Kept well under the cast interval, so the idle pose still shows between shots
## rather than leaving Max permanently mid-cast.
@export var attack_art_duration: float = 0.22
## Shown when a hit lands on Max. Outranks the attack pose - see _pose_texture().
@export var hurt_texture: Texture2D
## How long the hurt pose is held. Longer than a single cast's attack flash, so
## a hit taken mid-rotation is not immediately painted over by the next shot.
@export var hurt_art_duration: float = 0.45
## Thrown out around Max when a parry lands. Optional.
@export var parry_sparkle_texture: Texture2D

## Seconds of attack artwork still to show. Counted down rather than reverted on
## a timer, so overlapping casts cannot leave the pose stuck on.
var _attack_art_left: float = 0.0
## Same, for the hurt pose.
var _hurt_art_left: float = 0.0
## Scales that keep each pose the same apparent size as the idle one.
var _attack_art_scale: Vector2 = Vector2.ONE
var _hurt_art_scale: Vector2 = Vector2.ONE
var _idle_art_scale: Vector2 = Vector2.ONE
@export_group("")

@export_group("Ultimate")
## Seconds between casts. Long on purpose - the ultimate is an event, not part
## of a rotation - and only Ultimate III shortens it.
@export var ultimate_cooldown: float = 22.0
## Rain of Fire: damage every enemy on screen takes per tick. Ticks every 0.35s,
## so a 3s cast lands roughly nine of these on everything alive.
@export var ultimate_fire_damage: float = 12.0
## Beam: damage per second to anything standing in it.
@export var ultimate_beam_dps: float = 70.0
## Frozen Ground: how wide the pool spreads, and how long it holds an enemy.
@export var ultimate_ice_radius: float = 300.0
@export var ultimate_ice_freeze: float = 4.0
## How long every ultimate runs before cards extend it.
@export var ultimate_duration: float = 3.5
@export var ultimate_logs: bool = true

## Seconds until the ultimate is ready. Starts at zero, so the card arriving
## hands the player a charged ultimate rather than a timer to wait out.
var _ultimate_left: float = 0.0
@export_group("")


## Leaderboard name for this run, submitted to SilentWolf on death.
var my_name: String

## The on-screen touch controls, resolved lazily through the "touch_controls"
## group. Null on desktop, and on any run where they are not in the scene.
var _touch_controls: Node = null

@export_group("Debug")
## Press H to toggle. While on, the player takes no damage - for trying out
## cards without dying.
@export var invincible: bool = false
@export var debug_logs: bool = true
@export_group("")


# --- Card-modified stats -----------------------------------------------------
# The exports above are base values. Gameplay goes through these, so any card
# that touches the stat applies automatically.

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

## Shots fired per cast. Never below one - a card must not be able to silence
## the basic attack.
func effective_projectile_count() -> int:
	return maxi(1, int(round(RunState.modified(
		CardDatabase.STAT_PROJECTILE_COUNT, base_projectile_count))))

func effective_ultimate_cooldown() -> float:
	return maxf(RunState.modified(
		CardDatabase.STAT_ULTIMATE_COOLDOWN, ultimate_cooldown), 0.1)

func effective_ultimate_duration() -> float:
	return RunState.modified(
		CardDatabase.STAT_ULTIMATE_DURATION, ultimate_duration)


# --- Ultimate (E) ------------------------------------------------------------
# Dead until an Ultimate I card is taken. Which one fires is decided by the
# element the run locked - see cast_ultimate().

## True once the unlock card has been taken. The UI uses this to decide whether
## to show anything at all.
func has_ultimate() -> bool:
	return RunState.flag(CardDatabase.FLAG_ULTIMATE)


func ultimate_is_ready() -> bool:
	return has_ultimate() and _ultimate_left <= 0.0


## Recharge progress, 0..1. Reads 1.0 whenever the ultimate is up.
func ultimate_cooldown_ratio() -> float:
	if ultimate_is_ready():
		return 1.0
	var span := effective_ultimate_cooldown()
	if span <= 0.0:
		return 1.0
	return clampf(1.0 - _ultimate_left / span, 0.0, 1.0)


## Seconds until it is ready again. Zero when it is up.
func ultimate_time_left() -> float:
	return maxf(_ultimate_left, 0.0)


func _tick_ultimate(delta: float) -> void:
	if _ultimate_left > 0.0:
		_ultimate_left = maxf(_ultimate_left - delta, 0.0)


## Fires the ultimate of whichever school the run committed to. Does nothing at
## all while locked or on cooldown, so the key is safe to mash.
func cast_ultimate() -> bool:
	if not ultimate_is_ready():
		return false

	var element := RunState.chosen_element
	# The unlock cards all carry an element, so an unlocked run is always
	# committed. Guarded anyway rather than casting nothing silently.
	if element == CardDatabase.Element.NONE:
		push_warning("Ultimate unlocked with no element committed - nothing to cast.")
		return false

	var arena := get_parent()
	var length := effective_ultimate_duration()
	var power := RunState.modified(CardDatabase.STAT_ULTIMATE_DAMAGE, 1.0)

	match element:
		CardDatabase.Element.FIRE:
			UltFireRain.cast(arena, ultimate_fire_damage * power, length)
		CardDatabase.Element.ICE:
			UltFrozenGround.cast(arena, global_position,
				RunState.modified(CardDatabase.STAT_ULTIMATE_RADIUS,
					ultimate_ice_radius),
				length,
				RunState.modified(CardDatabase.STAT_ULTIMATE_FREEZE,
					ultimate_ice_freeze))
		CardDatabase.Element.ARCANE:
			# Parented to the player, not the arena - the beam tracks facing.
			UltArcaneBeam.cast(self, ultimate_beam_dps * power, length)

	# Arcane holds the attack pose for the whole beam, since the beam is a
	# sustained cast. Rain of Fire and Frozen Ground are released and then run on
	# their own, so they get the same brief flash as an ordinary cast.
	if element == CardDatabase.Element.ARCANE:
		show_attacking(length)
	else:
		show_attacking(attack_art_duration)

	_ultimate_left = effective_ultimate_cooldown()
	SoundManager.play_sfx(levelup_sound, 0, 0.7, 0.8, 0)

	if ultimate_logs:
		print("[ULT] %s cast | %.1fs | next in %.0fs"
			% [CardDatabase.element_name(element), length, _ultimate_left])
	return true


## The HUD health bar, found via the "health_bar" group so the lookup does not
## depend on where the bar lives or how the level is loaded.
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


## True while the Phase Step card is owned. A plain dash has no i-frames.
func has_dash_iframes() -> bool:
	return RunState.flag(CardDatabase.FLAG_DASH_IFRAMES)


## Returns true only if the damage actually landed.
##
## Callers that represent a physical object - a projectile - should consume
## themselves only when it did. Freeing on a blocked hit would turn i-frames
## into a screen clear, which is the parry's job, not the dash's.
func take_damage(amount: float) -> bool:
	if invincible:
		if debug_logs:
			print("[DEBUG] blocked %s damage (invincible)" % amount)
		return false

	if _iframes_left > 0.0:
		if debug_logs:
			print("[DASH] i-frames absorbed %s damage" % amount)
		return false

	var bar := find_health_bar()
	if bar == null:
		push_warning("No node in the 'health_bar' group - damage ignored.")
		return false
	bar.take_damage(amount)

	# Below the guards, so a hit that was blocked neither sounds nor poses.
	# play_sfx takes: sound, start playing position, min pitch, max pitch, volume.
	SoundManager.play_sfx(playerhit_dog_sound, 0, 0.85, 1.1, 0)
	SoundManager.play_sfx(playerhit_low_sound, 0, 0.85, 1.1, 0)
	show_hurt(hurt_art_duration)
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


## Hands back one whole charge, up to the maximum. Called when a red projectile
## loses its lock, so severing one is free and the dash stays the dedicated
## answer to red rather than a resource red drains.
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


# --- Poses -------------------------------------------------------------------
#
# Max has three drawings - idle, attacking and hurt - and one sprite to put them
# on, so which one wins is decided in one place, _pose_texture(). Each pose is a
# countdown, so whichever runs out first falls through to the next one down.

## Shows Max's attacking artwork for `duration`. Safe to call with no attack
## texture assigned. Does not disturb a hurt pose that is still running - it
## outranks this one - but the timer still counts, so the attack pose can show
## for whatever is left of it once the hurt pose expires.
func show_attacking(duration: float) -> void:
	# The longer of the two wins, so a basic cast fired during the Arcane beam
	# cannot cut the beam's pose short.
	_attack_art_left = maxf(_attack_art_left, duration)
	_apply_pose()


## Shows Max's hurt artwork. Called from take_damage() only once the hit has got
## past the invulnerability checks.
func show_hurt(duration: float) -> void:
	_hurt_art_left = maxf(_hurt_art_left, duration)
	_apply_pose()


## Which drawing should be up right now: hurt beats attacking beats idle. Falls
## back down the list whenever a texture is not assigned, so a scene with only an
## idle drawing still works.
func _pose_texture() -> Texture2D:
	if _hurt_art_left > 0.0 and hurt_texture != null:
		return hurt_texture
	if _attack_art_left > 0.0 and attack_texture != null:
		return attack_texture
	return idle_texture


## Scale that makes `texture` read at the same size as the idle drawing.
func _pose_scale(texture: Texture2D) -> Vector2:
	if texture == hurt_texture:
		return _hurt_art_scale
	if texture == attack_texture:
		return _attack_art_scale
	return _idle_art_scale


func _apply_pose() -> void:
	if _body_sprite == null:
		return
	var texture := _pose_texture()
	if texture == null or _body_sprite.texture == texture:
		return
	_body_sprite.texture = texture
	_body_sprite.scale = _pose_scale(texture)


## Keeps Max's artwork upright while the body goes on rotating with the mouse.
##
## The body's `rotation` is the aim - aim_angle() returns it, the dash falls back
## to it, and the Arcane beam inherits it by being a child - so it cannot stop
## turning. The sprite is counter-rotated to cancel that spin and flipped
## instead, leaving the aim untouched.
func _face_art() -> void:
	if _body_sprite == null:
		return
	_body_sprite.rotation = -rotation
	_body_sprite.flip_h = cos(rotation) < 0.0


## Runs both pose countdowns and re-resolves the sprite whenever one expires.
## _apply_pose() is a no-op when the winning texture has not changed, so this is
## cheap to call every frame.
func _tick_poses(delta: float) -> void:
	if _attack_art_left <= 0.0 and _hurt_art_left <= 0.0:
		return
	_attack_art_left = maxf(_attack_art_left - delta, 0.0)
	_hurt_art_left = maxf(_hurt_art_left - delta, 0.0)
	_apply_pose()


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
	# After the guard, so a dash refused for having no charge left stays silent.
	SoundManager.play_sfx(dash_sound,  0, 0.85, 1.1, 0)

	dash_charges -= 1
	movement_allowed = false
	is_dashing = true
	# Anything still shoving the player is cancelled by the dash taking over.
	_knockback = Vector2.ZERO

	if direction == Vector2(0.0, 0.0):
		direction = self.transform.x

	# The tint runs for the whole invulnerability, grace tail included, so it
	# never promises less than the card gives.
	if has_dash_iframes():
		var invulnerable_for := dash_duration + maxf(dash_iframe_grace, 0.0)
		_iframes_left = invulnerable_for
		_show_iframes(invulnerable_for)

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

	# Also hooks up health_depleted. A missing bar is not fatal - the player just
	# cannot show or lose health.
	find_health_bar()

	_known_max_charges = max_dash_charges()
	dash_charges = _known_max_charges
	RunState.stats_changed.connect(_on_run_stats_changed)

	if _body_sprite != null:
		_body_base_modulate = _body_sprite.modulate
		_idle_art_scale = _body_sprite.scale
		# The three drawings have different frame sizes, so each is scaled to the
		# idle height to keep Max the same size across poses.
		_attack_art_scale = _match_idle_height(attack_texture)
		_hurt_art_scale = _match_idle_height(hurt_texture)


## The scale at which `texture` stands as tall as the idle drawing does. Falls
## back to the idle scale for anything unusable, so a missing or zero-height
## texture cannot produce a divide by zero or a collapsed sprite.
func _match_idle_height(texture: Texture2D) -> Vector2:
	if idle_texture == null or texture == null or texture.get_height() <= 0:
		return _idle_art_scale
	return _idle_art_scale * (float(idle_texture.get_height())
		/ float(texture.get_height()))

func _on_health_depleted() -> void:
	SilentWolf.Scores.save_score(my_name, GameManager.score)
	GameManager.message = "You lost, " + my_name + "!"
	# Deferred: the killing blow arrives from a projectile's body_entered, and
	# swapping the scene inside a physics callback tears down colliders mid-step.
	get_tree().change_scene_to_file.call_deferred("res://game/ui/end_menu.tscn")


## Press Shift to parry
func parry_this_casual() -> void:
	if not parry_allowed:
		return

	# The press itself is silent. Only a parry that lands makes a noise, and that
	# lives in _parry_succeeded().

	parry_allowed = false
	is_parrying = true
	_parried_this_window = 0
	_parry_refunded = false
	_parry_window_opened_ms = Time.get_ticks_msec()

	# $ParryRadius is a CollisionShape2D on this CharacterBody2D and stays
	# disabled - enabling it would inflate the player's own hurtbox rather than
	# detect anything. Parry detection is by distance in _resolve_parry().
	#
	# The window length is snapshotted here, not re-read while it runs, so a card
	# taken mid-parry cannot stretch a window that is already open.
	_parry_window_left = effective_parry_window()
	_parry_cooldown_left = 0.0
	_parry_cooldown_span = 0.0

	_show_parry_attempt()


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

## True only while the window is open.
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


## Runs every physics frame while the window is open. A success destroys the
## parried shot and sets off a burst that clears every other colour around the
## player.
func _resolve_parry() -> void:
	for p in get_tree().get_nodes_in_group("enemy_projectiles"):
		# queue_free leaves the node in its group until the end of the frame, and
		# the burst from the first parry in this loop frees shots the loop has not
		# reached yet - so without this one press could "parry" a shot twice.
		if not is_instance_valid(p) or p.is_queued_for_deletion():
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


## The ring for the press itself, on the frame Shift goes down. A press refused
## by the lockout never gets here.
##
## Drawn at parry_radius rather than the burst radius, since that is the reach
## the press actually had. Silent and still - see parry_this_casual().
func _show_parry_attempt() -> void:
	var parent := get_parent()
	if parent == null:
		return
	_parry_attempt_flash = ParryFlash.burst(parent, global_position, parry_radius,
		parry_burst_duration, parry_attempt_flash_alpha)


func _parry_succeeded() -> int:
	_parried_this_window += 1

	# Take the press ring down - the burst ring below replaces it at the real
	# radius, on this same frame.
	if _parry_attempt_flash != null and is_instance_valid(_parry_attempt_flash):
		_parry_attempt_flash.queue_free()
	_parry_attempt_flash = null

	# The only parry sound: every success funnels through here, a miss never does.
	SoundManager.play_sfx(parry_sound, 0, 0.85, 1.1, 0)

	# Refunded here rather than when the window shuts, so the bar reads full the
	# instant the parry connects.
	_parry_refunded = true
	_parry_cooldown_left = 0.0
	_parry_cooldown_span = 0.0
	parry_allowed = true

	# One radius for the field, the ring and the tick that follows, so the three
	# can never disagree about how big the burst was.
	_burst_radius = effective_parry_burst_radius()
	_burst_left = parry_burst_duration
	var cleared := _parry_burst()

	if RunState.flag(CardDatabase.FLAG_PARRY_REFLECT):
		_reflect_shot()

	ParryFlash.burst(get_parent(), global_position, _burst_radius, parry_burst_duration)
	# The ring shows reach and stays exactly the burst radius; the sparkles are
	# the "that worked", thrown where the player is looking - at their character.
	ParrySparkle.burst(get_parent(), global_position, parry_sparkle_texture)
	# No arguments: CameraShake's defaults are tuned for the parry.
	_shake_camera()

	return cleared


## Reflect. A landed parry throws a full cast of the player's own missiles back
## out, aimed at the nearest enemy. Fired from the player rather than by turning
## the incoming shot around, so it works for parries of any colour.
func _reflect_shot() -> void:
	var target := nearest_enemy()
	var aim := rotation
	if target != null:
		aim = global_position.direction_to(target.global_position).angle()
	_fire_volley(aim)
	show_attacking(attack_art_duration)


## Keeps the clear field up for as long as the ring is on screen, so a shot that
## flies into the circle after the parry lands dies like everything else in it.
func _tick_parry_burst(delta: float) -> void:
	if _burst_left <= 0.0:
		return
	_burst_left -= delta
	_parry_burst()


## Thumps the screen, if the level has a camera that can. Negative values fall
## back to CameraShake's own defaults.
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

	# A dash owns movement outright, so a shove arriving mid-dash is dropped
	# rather than queued - it would add to dash_speed instead of replacing it.
	if is_dashing:
		return

	var force := knockback_strength if strength < 0.0 else strength
	if force <= 0.0:
		return
	# Replaced rather than accumulated: two hits in the same instant shove once.
	_knockback = dir.normalized() * force
	_knockback_drop = force / maxf(knockback_decay, 0.001)


func _decay_knockback(delta: float) -> void:
	if _knockback != Vector2.ZERO:
		_knockback = _knockback.move_toward(Vector2.ZERO, _knockback_drop * delta)


func basic_attack() -> void:
	can_attack = false
	# Silent: magic_attack1 belongs to the green caster, where it is the tell for
	# an incoming shot.
	show_attacking(attack_art_duration)

	# One cooldown per cast, however many shots that cast contains.
	_fire_volley(aim_angle())

	await get_tree().create_timer(effective_cast_interval()).timeout
	can_attack = true


## One cast's worth of missiles, spread across volley_spread_degrees and centred
## on `aim`. Shared by the basic attack and by Reflect, so a card that adds
## projectiles adds them to both.
func _fire_volley(aim: float) -> void:
	var count := effective_projectile_count()
	var spread := deg_to_rad(volley_spread_degrees)
	for i in count:
		# Spread evenly across the arc, centred on the aim. A lone shot gets no
		# offset.
		var offset := 0.0
		if count > 1:
			offset = (float(i) / float(count - 1) - 0.5) * spread
		shoot.emit(projectile, aim + offset, position)


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


## Points the body - which is the aim, and what the Arcane beam rides on.
##
## Mouse normally. On touch there is no cursor to look at, so facing follows the
## stick and simply holds while it is centred. Basic shots are unaffected either
## way: auto_aim sends those at the nearest enemy, not along facing.
func _aim_body(direction: Vector2) -> void:
	if not _touch_is_driving():
		look_at(get_global_mouse_position())
		return
	if direction != Vector2.ZERO:
		rotation = direction.angle()


## True while the on-screen touch controls are what the player is using. Absent
## on desktop, where the group is simply empty.
func _touch_is_driving() -> bool:
	if _touch_controls == null or not is_instance_valid(_touch_controls):
		_touch_controls = get_tree().get_first_node_in_group("touch_controls")
	return _touch_controls != null and _touch_controls.is_active()


func get_input() -> void:
	# Outside the movement gate so these still register during a dash.
	if Input.is_action_just_pressed("toggle_aim"):
		toggle_auto_aim()

	if Input.is_action_just_pressed("debug_invincible"):
		toggle_invincible()

	# Also outside the gate: the ultimate must not be eaten by a dash that
	# happens to be running when the key is pressed.
	if Input.is_action_just_pressed("ultimate"):
		cast_ultimate()

	if movement_allowed == true:
		var input_direction = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
		_aim_body(input_direction)
		velocity = input_direction * effective_move_speed()

		if Input.is_action_just_pressed("dash") && can_dash():
			dash_direction(input_direction)

		if Input.is_action_just_pressed("parry") && parry_allowed:
			parry_this_casual()


func _physics_process(_delta) -> void:
	get_input()
	# After get_input, which has just aimed the body at the cursor.
	_face_art()
	# After get_input, which has just overwritten velocity from the movement keys.
	# Skipped mid-dash, so a shove applied the frame before the dash started
	# cannot go on adding to dash_speed while it decays.
	if not is_dashing:
		velocity += _knockback
	move_and_slide()
	_decay_knockback(_delta)
	_iframes_left = maxf(_iframes_left - _delta, 0.0)
	_tick_dash_recharge(_delta)
	_tick_ultimate(_delta)
	_tick_poses(_delta)
	# Resolve before ticking, so the frame that closes the window still counts.
	if is_parrying:
		_resolve_parry()
	_tick_parry(_delta)
	_tick_parry_burst(_delta)
	if can_attack == true:
		basic_attack()
