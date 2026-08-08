extends CanvasLayer

## Level-up card screen. Freezes the game and offers a choice of three.
##
## PLACEHOLDER: the cards are names and descriptions only. Picking one prints,
## emits `card_chosen`, and changes nothing. Real effects hook into that signal
## once the card system exists - the names here come from docs/cards.md so the
## groups already match the plan.
##
## Opened with G for now. When XP is wired up, call open() on level-up instead
## and drop the debug key.

signal card_chosen(card: Dictionary)

const PLACEHOLDER_CARDS := [
	{"group": "Player", "name": "Iron Constitution", "desc": "+2 max health"},
	{"group": "Player", "name": "Swift Boots", "desc": "+15% move speed"},
	{"group": "Parry", "name": "Steady Hand", "desc": "+50% parry window"},
	{"group": "Parry", "name": "Shockwave", "desc": "+40% parry burst radius"},
	{"group": "Parry", "name": "Quick Recovery", "desc": "-30% parry cooldown"},
	{"group": "Parry", "name": "Reflect", "desc": "Parried shots fly back at the caster"},
	{"group": "Dash", "name": "Second Wind", "desc": "+1 dash charge"},
	{"group": "Dash", "name": "Fleet Footed", "desc": "-35% dash cooldown"},
	{"group": "Dash", "name": "Phase Step", "desc": "Dash grants invulnerability frames"},
	{"group": "Attack", "name": "Sharpened Missile", "desc": "+25% basic attack damage"},
	{"group": "Attack", "name": "Rapid Casting", "desc": "+30% cast rate"},
	{"group": "Attack", "name": "Split Bolt", "desc": "Basic attack fires an extra projectile"},
	{"group": "Element", "name": "Fire", "desc": "Basic attack explodes on impact"},
	{"group": "Element", "name": "Ice", "desc": "Basic attack slows what it hits"},
	{"group": "Element", "name": "Arcane", "desc": "Basic attack pierces one extra enemy"},
]

## How many cards to offer. Three is the design; the screen has three buttons.
@export var cards_offered: int = 3
## Debug key that opens the screen. Remove once XP drives this.
@export var open_action: String = "debug_cards"
@export var logs: bool = true

var is_open: bool = false

var _offer: Array = []

@onready var _screen: Control = $Screen
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
	_offer = _draw_cards(cards_offered)

	for i in _buttons.size():
		var button := _buttons[i]
		if i < _offer.size():
			var card: Dictionary = _offer[i]
			button.visible = true
			button.text = "%s\n\n%s\n\n( %s )" % [card["name"], card["desc"], card["group"]]
		else:
			button.visible = false

	_screen.visible = true
	is_open = true
	get_tree().paused = true
	_buttons[0].grab_focus()

	if logs:
		var names := []
		for c in _offer:
			names.append(c["name"])
		print("[CARDS] opened - game paused | offering: ", ", ".join(names))


func close() -> void:
	if not is_open:
		return
	_screen.visible = false
	is_open = false
	get_tree().paused = false
	if logs:
		print("[CARDS] closed - game resumed")


func _on_card_pressed(index: int) -> void:
	var card: Dictionary = _offer[index]
	if logs:
		print("[CARDS] picked '%s' (%s): %s | PLACEHOLDER - no effect applied"
			% [card["name"], card["group"], card["desc"]])
	card_chosen.emit(card)
	close()


## Three distinct cards. Duplicates would be confusing in a placeholder screen.
func _draw_cards(count: int) -> Array:
	var pool := PLACEHOLDER_CARDS.duplicate()
	pool.shuffle()
	return pool.slice(0, mini(count, pool.size()))
