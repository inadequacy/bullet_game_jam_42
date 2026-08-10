extends Label

## The run's score, in the HUD's top right.
##
## Driven by GameManager's signal rather than polled: the number only moves on a
## kill, so there is nothing to check on the frames in between.


func _ready() -> void:
	_on_score_changed(GameManager.score)
	GameManager.score_changed.connect(_on_score_changed)


func _on_score_changed(new_score: int) -> void:
	text = "Score: %d" % new_score
