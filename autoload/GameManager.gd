extends Node

signal score_changed(new_score: int)
var score: int = 0
var message: String
var player_name: String

func _ready() -> void:
	SilentWolf.configure({
	"api_key": "uWPN7UbP9l2CLDn20xZTm17jouyGc4KCNysEh6Da",
	"game_id": "bullet_hell_42_max",
	"log_level": 1
	})


func reset_game_data():
	score = 0
	message = "You lost, " + player_name + "!"

# Score
func add_score(points: int = 1):
	score += points
	score_changed.emit(score)

# Update end message
func win_message():
	message = "You won, " + player_name + "!"
