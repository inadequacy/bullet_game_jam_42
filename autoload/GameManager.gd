extends Node

signal score_changed(new_score: int)
signal exp_changed(current: int, threshold: int)
signal level_up

var score: int = 0
var message: String
var player_name: String
var experience: int = 0

## XP for the first card. Halved from 400 with the run cut to six minutes - the
## first level-up was arriving so late that the opening was played with no cards
## at all.
const FIRST_LEVEL_XP := 200
## What the requirement is multiplied by after each level. The old curve added
## 115% of the threshold on top of itself, so it MORE THAN DOUBLED every time and
## the fifth card was effectively unreachable. 1.6 still slows down, but a run
## that goes well keeps paying out.
const LEVEL_XP_GROWTH := 1.6

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

# Score
func add_score(points: int = 1):
	experience += points
	score += points
	if experience >= exp_threshold:
		exp_threshold = int(exp_threshold * LEVEL_XP_GROWTH)
		# The card screen is opened by whoever is listening to this - level.gd,
		# which also plays the fanfare. It used to ALSO be opened from here by
		# node path, which only worked while the level happened to be called
		# "Level" and sat at the root.
		level_up.emit()
	score_changed.emit(score)
	exp_changed.emit(experience, exp_threshold)

func exp_ratio() -> float:
	if exp_threshold <= 0:
		return 0.0
	return clampf(float(experience) / float(exp_threshold), 0.0, 1.0)

# Update end message
func win_message():
	message = "You won, " + player_name + "!"
