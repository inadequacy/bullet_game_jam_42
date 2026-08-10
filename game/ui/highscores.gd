extends Label

## The leaderboard on the end screen, fetched from SilentWolf.
##
## Appends to whatever the label already says, so the "High scores:" heading
## lives in the scene rather than here.

## Dropped to this if the first request comes back empty - a shorter board is
## better than none.
const FALLBACK_COUNT := 20


func _ready() -> void:
	var result: Dictionary = await SilentWolf.Scores.get_scores(100).sw_get_scores_complete
	if not result:
		result = await SilentWolf.Scores.get_scores(FALLBACK_COUNT).sw_get_scores_complete
	if not "scores" in result:
		return

	var lines := ""
	for entry in result.scores:
		lines += "%s: %d\n" % [entry.get("player_name", "Anonymous"),
			int(entry.get("score", 0))]
	text += "\n" + lines
