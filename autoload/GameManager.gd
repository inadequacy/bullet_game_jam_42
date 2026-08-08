extends Node

signal score_changed(new_score: int)
var score: int = 0
var message = "You lost!"

func reset_game_data():
	score = 0
	message = "You lost!"

# Score
func add_score(points: int = 1):
	score += points
	score_changed.emit(score)

# Update end message
func win_message():
	message = "You won!"
