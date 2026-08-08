extends Node

## Everything a run accumulates from cards: which cards were taken, which
## element is locked, and the resulting stat modifiers.
##
## This is an AUTOLOAD on purpose. The card screen is a node inside level.tscn,
## so anything stored there dies when the level reloads - and end_menu.gd
## restarts with change_scene_to_file. Run state has to outlive that.
##
## Gameplay never reads a raw export. It asks for the modified value:
##
##     velocity = direction * RunState.modified(CardDatabase.STAT_MOVE_SPEED, movespeed)
##
## so a card that changes a stat needs no change at the call site.

## Emitted whenever a card lands. Anything caching a modified value should
## recompute here.
signal stats_changed

## The committed spell school, or NONE while the player is on plain missiles.
var chosen_element: CardDatabase.Element = CardDatabase.Element.NONE

## card id -> how many times it has been taken.
var taken: Dictionary = {}

var _add: Dictionary = {}
var _mult: Dictionary = {}
var _flags: Dictionary = {}


## Wipes the run. Call when starting a new one.
func reset() -> void:
	chosen_element = CardDatabase.Element.NONE
	taken.clear()
	_add.clear()
	_mult.clear()
	_flags.clear()
	stats_changed.emit()


## A base value with every card the player owns folded in:
##     (base + total add) * total mult
func modified(stat: String, base: float) -> float:
	return (base + _add.get(stat, 0.0)) * _mult.get(stat, 1.0)


## Whether a behaviour-switching card has been taken.
func flag(flag_name: String) -> bool:
	return _flags.get(flag_name, false)


func times_taken(card_id: String) -> int:
	return taken.get(card_id, 0)


## Records a pick and applies its effect. The single entry point - the card
## screen calls this and nothing else needs to know a card was taken.
func apply_card(card: Dictionary) -> void:
	var id := CardDatabase.card_id(card)
	taken[id] = taken.get(id, 0) + 1

	# The first element card decides the run; nothing can change it after.
	var element: CardDatabase.Element = card.get("element", CardDatabase.Element.NONE)
	if element != CardDatabase.Element.NONE and chosen_element == CardDatabase.Element.NONE:
		chosen_element = element

	var effect: Dictionary = card.get("effect", {})
	if effect.is_empty():
		push_warning("Card '%s' has no effect - it is still a placeholder." % id)
	else:
		_apply_effect(effect, id)

	stats_changed.emit()


func _apply_effect(effect: Dictionary, id: String) -> void:
	match effect.get("op", ""):
		"add":
			var stat: String = effect["stat"]
			_add[stat] = _add.get(stat, 0.0) + effect["value"]
		"mult":
			var stat: String = effect["stat"]
			_mult[stat] = _mult.get(stat, 1.0) * effect["value"]
		"flag":
			_flags[effect["flag"]] = true
		"action":
			_run_action(effect.get("action", ""))
		_:
			push_warning("Card '%s' has an unknown effect op: %s" % [id, effect])


## One-shot effects that change no stat.
func _run_action(action: String) -> void:
	match action:
		"heal_full":
			var bar: HealthBar = get_tree().get_first_node_in_group("health_bar")
			if bar == null:
				push_warning("heal_full: no node in the 'health_bar' group.")
				return
			bar.heal(bar.max_health)
		_:
			push_warning("Unknown card action: %s" % action)


## Debug dump of everything the run has accumulated.
func describe() -> String:
	var parts := []
	for stat in _add:
		parts.append("%s +%s" % [stat, _add[stat]])
	for stat in _mult:
		parts.append("%s x%.2f" % [stat, _mult[stat]])
	for f in _flags:
		parts.append("%s ON" % f)
	if parts.is_empty():
		return "no modifiers"
	return ", ".join(parts)
