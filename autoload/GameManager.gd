extends Node

signal score_changed(new_score: int)
signal exp_changed(current: int, threshold: int)
signal level_up

var score: int = 0
var message: String
var player_name: String
var experience: int = 0
var exp_threshold: int = 400

func _ready() -> void:
	SilentWolf.configure({
	"api_key": "uWPN7UbP9l2CLDn20xZTm17jouyGc4KCNysEh6Da",
	"game_id": "bullet_hell_42_max",
	"log_level": 1
	})


func reset_game_data():
	score = 0
	experience = 0
	exp_threshold = 400
	message = "You lost, " + player_name + "!"
	exp_changed.emit(experience, exp_threshold)

# Score
func add_score(points: int = 1):
	experience += points
	score += points
	score_changed.emit(score)

	if experience >= exp_threshold:
		exp_changed.emit(exp_threshold, exp_threshold)

		experience -= exp_threshold
		exp_threshold = exp_threshold + int(exp_threshold * 1.15)
		level_up.emit()
		return   # bar stays "full" until card_screen.gd resets it on pick

	exp_changed.emit(experience, exp_threshold)
	
func exp_ratio() -> float:
	if exp_threshold <= 0:
		return 0.0
	return clampf(float(experience) / float(exp_threshold), 0.0, 1.0)

# Update end message
func win_message():
	message = "You won, " + player_name + "!"
