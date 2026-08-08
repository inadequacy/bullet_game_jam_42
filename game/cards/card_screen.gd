extends CanvasLayer

## Level-up card screen. Freezes the game and offers three cards - one BASIC,
## one MOBILITY, one ATTACK, always in that order.
##
## PLACEHOLDER: the cards are names and descriptions only. Picking one prints,
## emits `card_chosen`, and changes nothing. Real effects hook into that signal
## once the card system exists. Names come from docs/cards.md.
##
## Opened with G for now. When XP is wired up, call open() on level-up instead
## and drop the debug key.

signal card_chosen(card: Dictionary)
## Fired the first time an element is committed to. Never fires again in a run.
signal element_locked(element: Element)

## Every level-up offers exactly one card from each pool, always in this order,
## so a slot always means the same thing to the player.
enum Pool { BASIC, ACTION, ATTACK }

## The player's spell school.
##
## NONE is the starting state: plain magic missiles, no commitment made. The
## first element card taken locks the choice for the rest of the run - including
## which ultimate becomes available. ARCANE is the "stay as you are" option.
enum Element { NONE, ARCANE, FIRE, ICE }

const POOL_NAMES := {
	Pool.BASIC: "BASIC",
	Pool.ACTION: "ACTION",
	Pool.ATTACK: "ATTACK",
}

const ELEMENT_NAMES := {
	Element.NONE: "Magic Missiles",
	Element.ARCANE: "Arcane",
	Element.FIRE: "Fire",
	Element.ICE: "Ice",
}

## Slot order, left to right. One card is drawn from each.
const OFFER_ORDER := [Pool.BASIC, Pool.ACTION, Pool.ATTACK]

## Where a slot draws from once its own pool is exhausted, so the player is
## never shown a blank card. ATTACK runs dry after an element line is finished -
## the elements are one-shot chains, while ACTION cards keep coming.
const POOL_FALLBACK := {
	Pool.ATTACK: Pool.ACTION,
}

## Card keys:
##   name     - shown on the card. Not unique: every element has an "Ultimate I".
##   id       - unique key for tracking. Defaults to `name` when omitted, so it
##              is only needed where two cards share a display name.
##   element  - which school this belongs to. Absent means element-neutral and
##              always offerable.
##   locks    - taking this commits the run to `element`. Only offered while no
##              element is committed.
##   unique   - can only ever be taken once per run.
##   requires - id of a card that must already be taken. This is what makes the
##              numbered tiers arrive in order.
const CARDS := {
	# Utility. Only one entry for now, so this slot is currently a guaranteed
	# heal rather than a choice.
	Pool.BASIC: [
		{"name": "Renewal", "desc": "Restore health to full"},
	],

	# "Action Modifier Cards" in docs/cards.md: mobility, parry, dash, and the
	# element-neutral basic attack upgrades. None of these are one-shot, so this
	# pool never runs dry - which is why ATTACK falls back to it.
	Pool.ACTION: [
		# Mobility
		{"name": "Swift Boots", "desc": "+15% move speed"},
		# Dash
		{"name": "Second Wind", "desc": "+1 dash charge"},
		{"name": "Fleet Footed", "desc": "-35% dash cooldown"},
		{"name": "Phase Step", "desc": "Dash grants invulnerability frames"},
		# Parry
		{"name": "Steady Hand", "desc": "+50% parry window"},
		{"name": "Shockwave", "desc": "+40% parry burst radius"},
		{"name": "Quick Recovery", "desc": "-30% parry cooldown"},
		{"name": "Reflect", "desc": "Parried shots fly back at the caster"},
		# Basic attack
		{"name": "Sharpened Missile", "desc": "+25% basic attack damage"},
		{"name": "Rapid Casting", "desc": "+30% cast rate"},
		{"name": "Split Bolt", "desc": "Basic attack fires an extra projectile"},
	],

	# "Attack Variant Cards": elements and their ultimates, nothing else.
	Pool.ATTACK: [
		# The commitment. Exactly one of these can ever be taken, and only
		# while the run is still unelemented.
		{"id": "arcane_lock", "name": "Arcane", "element": Element.ARCANE,
			"locks": true, "unique": true,
			"desc": "Keep your missiles, refined\nLOCKS: Arcane"},
		{"id": "fire_lock", "name": "Fire", "element": Element.FIRE,
			"locks": true, "unique": true,
			"desc": "Missiles explode on impact\nLOCKS: Fire"},
		{"id": "ice_lock", "name": "Ice", "element": Element.ICE,
			"locks": true, "unique": true,
			"desc": "Missiles slow what they hit\nLOCKS: Ice"},

		# --- Arcane line. Placeholder tiers; effects TBD. ---
		{"id": "arcane_1", "name": "Arcane I", "element": Element.ARCANE,
			"unique": true, "desc": "Arcane tier 1 - TBD"},
		{"id": "arcane_2", "name": "Arcane II", "element": Element.ARCANE,
			"unique": true, "requires": "arcane_1", "desc": "Arcane tier 2 - TBD"},
		{"id": "arcane_3", "name": "Arcane III", "element": Element.ARCANE,
			"unique": true, "requires": "arcane_2", "desc": "Arcane tier 3 - TBD"},
		{"id": "arcane_ult_1", "name": "Ultimate I", "element": Element.ARCANE,
			"unique": true, "desc": "Unlocks the Arcane ultimate - TBD"},
		{"id": "arcane_ult_2", "name": "Ultimate II", "element": Element.ARCANE,
			"unique": true, "requires": "arcane_ult_1",
			"desc": "Arcane ultimate tier 2 - TBD"},
		{"id": "arcane_ult_3", "name": "Ultimate III", "element": Element.ARCANE,
			"unique": true, "requires": "arcane_ult_2",
			"desc": "Arcane ultimate tier 3 - TBD"},

		# --- Fire line. ---
		{"id": "fire_1", "name": "Fire I", "element": Element.FIRE,
			"unique": true, "desc": "Fire tier 1 - TBD"},
		{"id": "fire_2", "name": "Fire II", "element": Element.FIRE,
			"unique": true, "requires": "fire_1", "desc": "Fire tier 2 - TBD"},
		{"id": "fire_3", "name": "Fire III", "element": Element.FIRE,
			"unique": true, "requires": "fire_2", "desc": "Fire tier 3 - TBD"},
		{"id": "fire_ult_1", "name": "Ultimate I", "element": Element.FIRE,
			"unique": true, "desc": "Unlocks the Fire ultimate - TBD"},
		{"id": "fire_ult_2", "name": "Ultimate II", "element": Element.FIRE,
			"unique": true, "requires": "fire_ult_1",
			"desc": "Fire ultimate tier 2 - TBD"},
		{"id": "fire_ult_3", "name": "Ultimate III", "element": Element.FIRE,
			"unique": true, "requires": "fire_ult_2",
			"desc": "Fire ultimate tier 3 - TBD"},

		# --- Ice line. ---
		{"id": "ice_1", "name": "Ice I", "element": Element.ICE,
			"unique": true, "desc": "Ice tier 1 - TBD"},
		{"id": "ice_2", "name": "Ice II", "element": Element.ICE,
			"unique": true, "requires": "ice_1", "desc": "Ice tier 2 - TBD"},
		{"id": "ice_3", "name": "Ice III", "element": Element.ICE,
			"unique": true, "requires": "ice_2", "desc": "Ice tier 3 - TBD"},
		{"id": "ice_ult_1", "name": "Ultimate I", "element": Element.ICE,
			"unique": true, "desc": "Unlocks the Ice ultimate - TBD"},
		{"id": "ice_ult_2", "name": "Ultimate II", "element": Element.ICE,
			"unique": true, "requires": "ice_ult_1",
			"desc": "Ice ultimate tier 2 - TBD"},
		{"id": "ice_ult_3", "name": "Ultimate III", "element": Element.ICE,
			"unique": true, "requires": "ice_ult_2",
			"desc": "Ice ultimate tier 3 - TBD"},
	],
}

## Debug key that opens the screen. Remove once XP drives this.
@export var open_action: String = "debug_cards"
@export var logs: bool = true

## The committed school, or NONE while the player is still on plain missiles.
## Read this from gameplay code to decide what the basic attack and ultimate do.
var chosen_element: Element = Element.NONE
var is_open: bool = false

var _offer: Array = []
var _taken: Dictionary = {}

@onready var _screen: Control = $Screen
@onready var _hint: Label = $Screen/Center/VBox/Hint
@onready var _buttons: Array[Button] = [
	$Screen/Center/VBox/Cards/Card1,
	$Screen/Center/VBox/Cards/Card2,
	$Screen/Center/VBox/Cards/Card3,
]


func _ready() -> void:
	_screen.visible = false
	for i in _buttons.size():
		_buttons[i].pressed.connect(_on_card_pressed.bind(i))


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed(open_action):
		return
	if is_open:
		close()
	else:
		open()
	get_viewport().set_input_as_handled()


## Rolls a fresh hand, shows the screen and pauses everything else.
func open() -> void:
	if is_open:
		return
	_offer = _draw_offer()

	for i in _buttons.size():
		var button := _buttons[i]
		if i < _offer.size():
			var card: Dictionary = _offer[i]
			button.visible = true
			button.text = "[ %s ]\n\n%s\n\n%s" % [card["group"], card["name"], card["desc"]]
		else:
			button.visible = false

	if chosen_element == Element.NONE:
		_hint.text = "Magic Missiles - taking an element locks it for the whole run"
	else:
		_hint.text = "%s - locked for this run" % ELEMENT_NAMES[chosen_element]

	_screen.visible = true
	is_open = true
	get_tree().paused = true
	_buttons[0].grab_focus()

	if logs:
		var names := []
		for c in _offer:
			names.append(c["name"])
		print("[CARDS] opened (%s) | offering: %s"
			% [ELEMENT_NAMES[chosen_element], ", ".join(names)])


func close() -> void:
	if not is_open:
		return
	_screen.visible = false
	is_open = false
	get_tree().paused = false
	if logs:
		print("[CARDS] closed - game resumed")


## Clears the element lock and taken cards. Call when starting a new run.
func reset() -> void:
	chosen_element = Element.NONE
	_taken.clear()


func _on_card_pressed(index: int) -> void:
	var card: Dictionary = _offer[index]

	# Record every pick - `requires` reads this too, not just the unique check.
	_taken[card_id(card)] = true

	# The first element card taken decides the run. Nothing can change it after.
	var element: Element = card.get("element", Element.NONE)
	if element != Element.NONE and chosen_element == Element.NONE:
		chosen_element = element
		element_locked.emit(element)
		if logs:
			print("[CARDS] ELEMENT LOCKED: %s - only %s attack cards from here, ultimate included"
				% [ELEMENT_NAMES[element], ELEMENT_NAMES[element]])

	if logs:
		print("[CARDS] picked '%s' (%s) | PLACEHOLDER - no effect applied"
			% [card["name"], card["group"]])

	card_chosen.emit(card)
	close()


## One card per slot, in OFFER_ORDER. A slot whose own pool is exhausted falls
## back to POOL_FALLBACK so the player always gets three real choices.
func _draw_offer() -> Array:
	var offer := []
	# Two slots can draw from the same pool once ATTACK starts falling back to
	# ACTION, so track what this offer already contains.
	var already_offered := {}

	for slot_pool in OFFER_ORDER:
		var source: Pool = slot_pool
		var options := _available(source, already_offered)

		if options.is_empty() and POOL_FALLBACK.has(slot_pool):
			source = POOL_FALLBACK[slot_pool]
			options = _available(source, already_offered)

		if options.is_empty():
			push_warning("No card available for slot '%s' - it will be blank."
				% POOL_NAMES[slot_pool])
			continue

		var card: Dictionary = (options[randi() % options.size()] as Dictionary).duplicate()
		already_offered[card_id(card)] = true
		card["group"] = POOL_NAMES[source]
		card["pool"] = source
		offer.append(card)

	return offer


## Tracking key. Display names repeat across elements - every school has an
## "Ultimate I" - so `id` is what `unique` and `requires` actually key on.
func card_id(card: Dictionary) -> String:
	return card.get("id", card["name"])


func _available(pool: Pool, exclude: Dictionary = {}) -> Array:
	var out := []
	for card in CARDS.get(pool, []):
		if exclude.has(card_id(card)):
			continue
		if _is_available(card):
			out.append(card)
	return out


## The element rule, in one place:
##
##   no element yet -> element-neutral cards, plus the three commitment cards
##   element locked -> element-neutral cards, plus that element's own cards
##
## Other elements become permanently unreachable the moment one is chosen.
func _is_available(card: Dictionary) -> bool:
	if card.get("unique", false) and _taken.has(card_id(card)):
		return false

	# Numbered tiers arrive in order: "Fire II" waits for "Fire I".
	var prerequisite: String = card.get("requires", "")
	if prerequisite != "" and not _taken.has(prerequisite):
		return false

	var element: Element = card.get("element", Element.NONE)
	if element == Element.NONE:
		return true

	if chosen_element == Element.NONE:
		return card.get("locks", false)

	return element == chosen_element and not card.get("locks", false)
