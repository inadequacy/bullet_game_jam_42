extends Node

## Everything a run accumulates from cards: which were taken, which element is
## locked, and the resulting stat modifiers.
##
## An autoload - the card screen lives inside level.tscn and end_menu.gd
## restarts with change_scene_to_file, so run state has to outlive the level.
## Gameplay never reads a raw export, it asks for the modified value:
##
##     RunState.modified(CardDatabase.STAT_MOVE_SPEED, movespeed)

## Emitted whenever a card lands. Anything caching a modified value should
## recompute here.
signal stats_changed

## Played by the "heal_full" card action. Same sample the heart pickup uses.
const HEALING_SOUND := preload("res://assets/sounds/healing1.wav")

## The committed spell school, or NONE while the player is on plain missiles.
var chosen_element: CardDatabase.Element = CardDatabase.Element.NONE

## card id -> how many times it has been taken.
var taken: Dictionary = {}

var _add: Dictionary = {}
var _mult: Dictionary = {}
var _flags: Dictionary = {}

## Basic-attack hits landed this run, counted so Flash Freeze can fire on every
## Nth one. Deterministic rather than a roll, so the player can plan around it.
var _hits_landed: int = 0


## Wipes the run. Call when starting a new one.
func reset() -> void:
	chosen_element = CardDatabase.Element.NONE
	taken.clear()
	_add.clear()
	_mult.clear()
	_flags.clear()
	_hits_landed = 0
	stats_changed.emit()


## Counts one landed hit and reports whether it is a freezing one. Always call
## it on a hit, even without the card - the count has to keep running or taking
## Flash Freeze mid-run would start the cycle over.
func count_hit_and_check_freeze() -> bool:
	_hits_landed += 1
	if not flag(CardDatabase.FLAG_FLASH_FREEZE):
		return false
	var every := maxi(1, int(round(modified(CardDatabase.STAT_FREEZE_EVERY, 4.0))))
	return _hits_landed % every == 0


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

	# `effect` is one shape or an array of them, so a card can do two things.
	var effect: Variant = card.get("effect", {})
	var steps: Array = effect if effect is Array else [effect]
	var applied := 0
	for step in steps:
		if step is Dictionary and not (step as Dictionary).is_empty():
			_apply_effect(step, id)
			applied += 1

	if applied == 0:
		push_warning("Card '%s' has no effect - it is a placeholder." % id)

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
			SoundManager.play_sfx(HEALING_SOUND, 0, 0.9, 1.0, 0)
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
