extends Node2D

var music_player: AudioStreamPlayer
var sfx_player: AudioStreamPlayer

func _ready():
	music_player = AudioStreamPlayer.new()
	sfx_player = AudioStreamPlayer.new()

	add_child(music_player)
	add_child(sfx_player)

func play_music(stream: AudioStream):
	if music_player.stream == stream and music_player.playing:
		return

	music_player.stream = stream
	music_player.play()

func stop_music():
	music_player.stop()

func play_sfx(stream: AudioStream):
	sfx_player.stream = stream
	sfx_player.volume_db = -9
	sfx_player.pitch_scale = randf_range(0.85, 1.1)
	sfx_player.play(0.1)
