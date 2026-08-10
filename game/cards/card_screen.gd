extends CanvasLayer

## Level-up card screen. Freezes the game and offers three cards - one BASIC,
## one ACTION, one ATTACK, always in that order.
##
## Holds the selection rules only: which three cards a hand contains. The cards
## themselves live in card_database.gd, drawing one lives in card_view.gd, and
## applying one lives in RunState - so a new card needs no change here.
##
## Opened by level.gd on GameManager.level_up; `open_action` is a debug key that
## opens it on demand.

signal card_chosen(card: Dictionary)
## Fired the first time an element is committed to. Never fires again in a run.
signal element_locked(element: CardDatabase.Element)

## Debug key that opens the screen on demand, alongside the normal level-up.
@export var open_action: String = "debug_cards"
## How long a fresh hand is dealt for before it will accept a pick.
##
## The screen opens mid-fight, on a frame the player did not choose, with their
## hands already on the keys - and Space is both dash and Godot's ui_accept, so
## a dash tapped as the cards arrive would otherwise pick one outright. This beat
## swallows whatever was queued for the fight, and every key keeps doing in the
## menu exactly what it does everywhere else. Long enough to eat a keypress
## already on its way, short enough that a player who knows what they want never
## feels held up.
@export var arm_delay: float = 0.5
## What the hand fades in from while it is being dealt. Not zero - the cards are
## there to be read during the wait, they are just not pickable yet.
@export_range(0.0, 1.0, 0.05) var dealing_alpha: float = 0.45
@export var logs: bool = true

var is_open: bool = false

var _offer: Array = []
## False while a fresh hand is still being dealt. See arm_delay.
var _armed: bool = false
## Bumped every open(), so the deal-in of a hand that has since been closed and
## re-opened cannot arm the one now on screen.
var _open_id: int = 0


## The committed school. Lives in RunState, not here - this node dies with the
## level, and the lock has to outlive that.
var chosen_element: CardDatabase.Element:
	get: return RunState.chosen_element

@onready var _screen: Control = $Screen
@onready var _hint: Label = $Screen/Center/VBox/Hint
@onready var _row: Control = $Screen/Center/VBox/Cards
## Three card_view.tscn instances. They draw themselves from a card dictionary -
## see card_view.gd - so this file never touches a label or a texture.
@onready var _cards: Array[CardView] = [
	$Screen/Center/VBox/Cards/Card1,
	$Screen/Center/VBox/Cards/Card2,
	$Screen/Center/VBox/Cards/Card3,
]


func _ready() -> void:
	_screen.visible = false
	add_to_group("card_screen")
	for i in _cards.size():
		_cards[i].pressed.connect(_on_card_pressed.bind(i))
	# The three views are re-used rather than rebuilt each hand, so their hover
	# and click sounds only need wiring once.
	SoundManager.attach_button_sounds(self)


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

	for i in _cards.size():
		var view := _cards[i]
		view.visible = i < _offer.size()
		if view.visible:
			view.show_card(_offer[i])

	if chosen_element == CardDatabase.Element.NONE:
		_hint.text = "Magic Missiles - taking an element locks it for the whole run"
	else:
		_hint.text = "%s - locked for this run" % CardDatabase.element_name(chosen_element)

	_screen.visible = true
	is_open = true
	get_tree().paused = true
	_deal_in()

	if logs:
		var names := []
		for c in _offer:
			names.append(c["name"])
		print("[CARDS] opened (%s) | offering: %s"
			% [CardDatabase.element_name(chosen_element), ", ".join(names)])


## Fades the hand up and holds it unpickable for arm_delay, then arms it and
## gives the first card focus.
##
## The cards are disabled rather than merely ignored, so a click that lands early
## does not light a card up or play its sound - a card that reacts and then does
## nothing reads as a dropped input rather than as "not yet".
##
## The timer and the tween both keep running while the tree is paused: this node
## is PROCESS_MODE_ALWAYS, and SceneTree.create_timer() ticks through a pause by
## default. Without that they would never fire - the screen pauses the game.
func _deal_in() -> void:
	_armed = false
	_open_id += 1
	var opening := _open_id

	for view in _cards:
		view.disabled = true
	_row.modulate.a = dealing_alpha
	create_tween().tween_property(_row, "modulate:a", 1.0, arm_delay)

	await get_tree().create_timer(arm_delay).timeout
	# Closed, or a different hand has been dealt since.
	if not is_open or opening != _open_id:
		return

	for view in _cards:
		view.disabled = false
	_armed = true
	_cards[0].grab_focus()


func close() -> void:
	if not is_open:
		return
	_screen.visible = false
	is_open = false
	_armed = false
	get_tree().paused = false
	if logs:
		print("[CARDS] closed - game resumed")


## Clears the element lock and taken cards. Call when starting a new run.
func reset() -> void:
	RunState.reset()


func _on_card_pressed(index: int) -> void:
	# Belt and braces behind the disabled cards in _deal_in(): a pick is
	# irreversible and can lock the run's element, so it is worth being sure.
	if not _armed:
		return

	var card: Dictionary = _offer[index]
	var was_unelemented := RunState.chosen_element == CardDatabase.Element.NONE

	# RunState records the pick and applies the effect. This screen does not
	# track anything itself - it only presents.
	RunState.apply_card(card)
	GameManager.experience = 0
	GameManager.exp_changed.emit(GameManager.experience, GameManager.exp_threshold)

	if was_unelemented and RunState.chosen_element != CardDatabase.Element.NONE:
		element_locked.emit(RunState.chosen_element)
		if logs:
			var label := CardDatabase.element_name(RunState.chosen_element)
			print("[CARDS] ELEMENT LOCKED: %s - only %s attack cards from here, ultimate included"
				% [label, label])

	if logs:
		print("[CARDS] picked '%s' (%s) | %s"
			% [card["name"], card["group"], RunState.describe()])

	card_chosen.emit(card)
	close()


## One card per slot, in CardDatabase.OFFER_ORDER. A slot whose own pool is
## exhausted falls back per POOL_FALLBACK, so the player always gets three real
## choices.
func _draw_offer() -> Array:
	var offer := []
	# Two slots can draw from the same pool once ATTACK starts falling back to
	# ACTION, so track what this offer already contains.
	var already_offered := {}

	for slot_pool in CardDatabase.OFFER_ORDER:
		var source: CardDatabase.Pool = slot_pool
		var options := _available(source, already_offered)

		if options.is_empty() and CardDatabase.POOL_FALLBACK.has(slot_pool):
			source = CardDatabase.POOL_FALLBACK[slot_pool]
			options = _available(source, already_offered)

		if options.is_empty():
			push_warning("No card available for slot '%s' - it will be blank."
				% CardDatabase.pool_name(slot_pool))
			continue

		var card: Dictionary = (options[randi() % options.size()] as Dictionary).duplicate()
		already_offered[CardDatabase.card_id(card)] = true
		card["group"] = CardDatabase.pool_name(source)
		card["pool"] = source
		offer.append(card)

	return offer


func _available(pool: CardDatabase.Pool, exclude: Dictionary = {}) -> Array:
	var out := []
	for card in CardDatabase.cards_in(pool):
		if exclude.has(CardDatabase.card_id(card)):
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
	if card.get("unique", false) and RunState.times_taken(CardDatabase.card_id(card)) > 0:
		return false

	# Numbered tiers arrive in order: "Fire II" waits for "Fire I".
	var prerequisite: String = card.get("requires", "")
	if prerequisite != "" and RunState.times_taken(prerequisite) == 0:
		return false

	var element: CardDatabase.Element = card.get("element", CardDatabase.Element.NONE)
	if element == CardDatabase.Element.NONE:
		return true

	if chosen_element == CardDatabase.Element.NONE:
		return card.get("locks", false)

	return element == chosen_element and not card.get("locks", false)
