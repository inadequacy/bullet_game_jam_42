extends Label


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	var sw_result: Dictionary = await SilentWolf.Scores.get_scores(100).sw_get_scores_complete
	var new_text: String = ""
	if !sw_result:
		sw_result = await SilentWolf.Scores.get_scores(20).sw_get_scores_complete

	print(sw_result)
	if "scores" in sw_result:
			for entry in sw_result.scores:
				var player_name: String = entry.get("player_name", "Anonymous")
				var score: String = str(int(entry.get("score", 0)))

				new_text += player_name + ": " + score + "\n"
	set_text(get_text() + "\n" + new_text)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass
