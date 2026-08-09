extends Node2D

## Every sound in the game goes through here. Autoloaded (see project.godot), so
## it outlives scene changes - which is what lets the background music run
## unbroken from the start menu, through a run, and into the end menu.

const SFX_PLAYERS := 8

## Background music. Looped through make_looping() below, not restarted on
## `finished`, so the seam is gapless.
const MUSIC := preload("res://assets/sounds/music1.wav")

## Shared UI sounds. Attached to whole menus at once by attach_button_sounds().
const BUTTON_HOVER := preload("res://assets/sounds/button_hover1.wav")
const BUTTON_SELECT := preload("res://assets/sounds/button_selection1.wav")

## Music sits well under the effects - it is a bed, not a layer the player is
## meant to listen to. Tune here rather than at each call site.
@export var music_volume_db: float = -14.0

var music_player: AudioStreamPlayer
var sfx_players: Array[AudioStreamPlayer] = []
var next_sfx_player := 0


func _ready():
	# The card screen pauses the whole tree while it is open. Without this the
	# music would cut out and the card buttons would click silently, because a
	# paused AudioStreamPlayer stops.
	process_mode = Node.PROCESS_MODE_ALWAYS

	music_player = AudioStreamPlayer.new()
	add_child(music_player)

	for i in SFX_PLAYERS:
		var player := AudioStreamPlayer.new()
		add_child(player)
		sfx_players.append(player)

	play_music(make_looping(MUSIC), music_volume_db)


## Marks a sample as looping and returns it, so it can be used inline.
##
## Cannot be done on the import: Godot 4.7.1's WAV importer silently drops
## `edit/loop_mode`, so a file whose .import says loop_mode=1 still loads as
## LOOP_DISABLED. Mutates the shared resource, and is idempotent.
func make_looping(stream: AudioStreamWAV) -> AudioStreamWAV:
	if stream == null or stream.loop_mode == AudioStreamWAV.LOOP_FORWARD:
		return stream
	# Read the length before touching loop_mode, and in frames - loop_end is a
	# frame index, not seconds.
	var frames := int(stream.get_length() * stream.mix_rate)
	stream.loop_begin = 0
	stream.loop_end = frames
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	return stream


func play_music(stream: AudioStream, volume_db: float = 0.0):
	music_player.stream = stream
	music_player.volume_db = volume_db
	music_player.play()


func play_sfx(
	stream: AudioStream,
	from_position: float = 0.0,
	pitch_min: float = 1.0,
	pitch_max: float = 1.0,
	volume_db: float = 0.0
):
	var player = sfx_players[next_sfx_player]

	player.stream = stream
	player.pitch_scale = randf_range(pitch_min, pitch_max)
	player.volume_db = volume_db
	player.play(from_position)

	next_sfx_player = (next_sfx_player + 1) % SFX_PLAYERS


# --- UI ------------------------------------------------------------------------

## Gives every Button under `root` the shared hover and click sounds. Walks the
## tree rather than wiring each button in its scene, so one call covers a screen.
func attach_button_sounds(root: Node) -> void:
	for node in _buttons_under(root):
		# focus_entered as well as mouse_entered, so keyboard and gamepad
		# navigation sound the same as the mouse. Guarded against double
		# connection in case a screen calls this more than once.
		if not node.mouse_entered.is_connected(play_button_hover):
			node.mouse_entered.connect(play_button_hover)
		if not node.focus_entered.is_connected(_on_button_focused):
			node.focus_entered.connect(_on_button_focused)
		if not node.pressed.is_connected(play_button_select):
			node.pressed.connect(play_button_select)


func play_button_hover() -> void:
	play_sfx(BUTTON_HOVER, 0, 0.98, 1.04, -6.0)


## A Button takes focus when it is clicked, not only when it is navigated to. A
## held mouse button means this focus came from a click, which the select sound
## already covers, so the hover sound is skipped.
func _on_button_focused() -> void:
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		return
	play_button_hover()


func play_button_select() -> void:
	play_sfx(BUTTON_SELECT, 0, 0.98, 1.04, 0)


func _buttons_under(root: Node) -> Array[BaseButton]:
	var found: Array[BaseButton] = []
	if root == null:
		return found
	if root is BaseButton:
		found.append(root)
	for child in root.get_children():
		found.append_array(_buttons_under(child))
	return found
