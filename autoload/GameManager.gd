extends Node

signal score_changed(new_score: int)
signal exp_changed(current: int, threshold: int)
signal level_up

var score: int = 0
var message: String
var player_name: String
var experience: int = 0

## XP for the first card, sized so the opening minutes are not played cardless.
const FIRST_LEVEL_XP := 350
## What the requirement is multiplied by after each level. Gentle enough that a
## run going well keeps paying out cards to the end.
const LEVEL_XP_GROWTH := 1.15

var exp_threshold: int = FIRST_LEVEL_XP

func _ready() -> void:
	SilentWolf.configure({
	"api_key": "uWPN7UbP9l2CLDn20xZTm17jouyGc4KCNysEh6Da",
	"game_id": "bullet_hell_42_max",
	"log_level": 1
	})


func reset_game_data():
	score = 0
	experience = 0
	exp_threshold = FIRST_LEVEL_XP
	message = "You lost, " + player_name + "!"
	exp_changed.emit(experience, exp_threshold)


func add_score(points: int = 1):
	experience += points
	score += points
	score_changed.emit(score)

	if experience >= exp_threshold:
		exp_changed.emit(exp_threshold, exp_threshold)

		experience -= exp_threshold
		exp_threshold = int(exp_threshold * LEVEL_XP_GROWTH)
		# level.gd listens for this: it opens the card screen and plays the
		# fanfare.
		level_up.emit()
		return   # bar stays "full" until card_screen.gd resets it on pick

	exp_changed.emit(experience, exp_threshold)
	