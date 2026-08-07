extends Node

var score: int = 0
var player_health: int = 10
var message = "You won!"

# Score
func add_score(points: int = 1):
	score += points

func reset_score():
	score = 0

# Health
func lose_health(points: int = 1):
	player_health -= points

func gain_health(points: int = 1):
	player_health += points
