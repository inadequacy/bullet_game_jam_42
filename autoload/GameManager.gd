extends Node

var score: int = 0
var player_health: int = 10
var message = "You lost!"

func reset_game_data():
	score = 0
	player_health = 10
	message = "You lost!"

# Score
func add_score(points: int = 1):
	score += points

# Health
func lose_health(points: int = 1):
	player_health -= points

func gain_health(points: int = 1):
	player_health += points

# Update end message
func win_message():
	message = "You won!"
