extends Node2D

const SFX_PLAYERS := 8

var music_player: AudioStreamPlayer
var sfx_players: Array[AudioStreamPlayer] = []
var next_sfx_player := 0


func _ready():
	# Reproductor de música
	music_player = AudioStreamPlayer.new()
	add_child(music_player)

	# Crear reproductores para los SFX
	for i in SFX_PLAYERS:
		var player := AudioStreamPlayer.new()
		add_child(player)
		sfx_players.append(player)

# BG music and BG sound fx are yet not implemented nor being called. 
func play_music(stream: AudioStream):
	music_player.stream = stream
	music_player.play()


func stop_music():
	music_player.stop()


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
