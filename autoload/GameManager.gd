extends Node

signal score_changed(new_score: int)
signal exp_changed(current: int, threshold: int)
signal level_up

var score: int = 0
var message: String
var player_name: String
var experience: int = 0
## How the last run ended. Read by the end screen, which is the same scene for
## both outcomes and needs to know which one it is showing.
var won: bool = false

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
	won = false
	message = "You lost, " + player_name + "!"
	exp_changed.emit(experience, exp_threshold)


## Closes out a run: records the outcome and posts the score. Both endings come
## through here - level.gd when the clock runs out, movement.gd when the player's
## health does - so the leaderboard cannot end up with one and not the other.
##
## Only the caller switches to the end screen. This says how the run went, not
## what to show next.
func finish_run(player_won: bool) -> void:
	won = player_won
	message = ("You survived, %s!" if player_won else "You lost, %s!") % player_name
	SilentWolf.Scores.save_score(player_name, score)


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
	