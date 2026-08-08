extends Node

signal score_changed(new_score: int)
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
	message = "You lost, " + player_name + "!"

# Score
func add_score(points: int = 1):
	experience += points
	score += points
	if experience > exp_threshold:
		get_node("/root/Level/CardScreen").open()
		exp_threshold = exp_threshold + (exp_threshold * 1.15)
	score_changed.emit(score)

# Update end message
func win_message():
	message = "You won, " + player_name + "!"
