extends Node

var score: int = 0
var message = "You won!"

func add_score(points: int = 1):
	score += points

func reset_score():
	score = 0
