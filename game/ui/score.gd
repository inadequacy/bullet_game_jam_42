extends Label

func _ready() -> void:
	text = "Score: " + str(GameManager.score)
	GameManager.score_changed.connect(_on_score_changed)

func _on_score_changed(new_score: int) -> void:
	text = "Score: " + str(new_score)
