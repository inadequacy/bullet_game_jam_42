class_name CardDatabase
extends RefCounted

## THE CARD DATABASE. Edit this file to add, remove or retune cards.
##
## Never instantiated - it is a namespace for the card data and the enums that
## describe it. `card_screen.gd` only presents whatever it finds here, so adding
## a card needs no changes anywhere else.
##
## Card keys:
##   name     - shown on the card. NOT unique: every element has an "Ultimate I".
##   desc     - the line under the name. "\n" works.
##   id       - unique tracking key. Defaults to `name`, so it is only needed
##              where two cards share a display name.
##   icon     - which ICON_* badge to show. Absent falls back to the element's
##              icon, so element cards only need it to override (the ultimates).
##   element  - which school this belongs to. Absent means element-neutral and
##              offerable at any point in the run.
##   locks    - taking this commits the run to `element`. Only offered while no
##              element is committed yet.
##   unique   - can only ever be taken once per run. Omit for stacking upgrades.
##   requires - id of a card that must already be taken. This is what makes the
##              numbered tiers arrive in order.
##   effect   - what the card actually DOES. See below. Omit for a card that is
##              still a placeholder.
##
## To add a card: drop a dictionary in the right pool below. To add a tier, give
## it `requires` pointing at the id of the tier before it.
##
## EFFECT SHAPES - this is the bit to edit when tuning a card:
##
##   {"op": "mult",   "stat": STAT_MOVE_SPEED,   "value": 1.15}
##       Scales the stat. 1.15 = +15%, 0.7 = -30%. Stacks multiplicatively.
##
##   {"op": "add",    "stat": STAT_DASH_CHARGES, "value": 1}
##       Adds a flat amount before any mult is applied. Stacks additively.
##
##   {"op": "flag",   "flag": FLAG_DASH_IFRAMES}
##       Switches a behaviour on. Taking it twice changes nothing.
##
##   {"op": "action", "action": "heal_full"}
##       Fires once when picked, changes no stat. See RunState._run_action.
##
## The final value is (base + total add) * total mult.
##
## A card that does two things gives `effect` an ARRAY of those shapes:
##
##   "effect": [{"op": "mult", "stat": STAT_ATTACK_DAMAGE, "value": 1.25},
##              {"op": "mult", "stat": STAT_PROJECTILE_SPEED, "value": 1.2}]

## Every level-up offers exactly one card per pool, so pools ARE the three slots.
enum Pool { BASIC, ACTION, ATTACK }

# --------------------------------------------------------------- stat keys ---
# What a card's `effect` can modify. Gameplay never reads a raw export - it asks
# RunState for the modified value, e.g.
#
#     RunState.modified(CardDatabase.STAT_MOVE_SPEED, movespeed)
#
# Use these constants rather than bare strings so a typo is a parse error.

const STAT_MOVE_SPEED := "move_speed"
const STAT_DASH_COOLDOWN := "dash_cooldown"
const STAT_DASH_CHARGES := "dash_charges"
const STAT_PARRY_WINDOW := "parry_window"
const STAT_PARRY_COOLDOWN := "parry_cooldown"
const STAT_PARRY_BURST_RADIUS := "parry_burst_radius"
const STAT_CAST_INTERVAL := "cast_interval"
const STAT_ATTACK_DAMAGE := "attack_damage"
const STAT_PROJECTILE_COUNT := "projectile_count"
const STAT_PROJECTILE_SPEED := "projectile_speed"
## Extra enemies a shot carries through before dying. 0 = stops at the first.
const STAT_PIERCE := "pierce"

# --- Element stats. Only ever non-default once that element is locked. ---
const STAT_EXPLOSION_RADIUS := "explosion_radius"
const STAT_EXPLOSION_DAMAGE := "explosion_damage"
const STAT_BURN_DAMAGE := "burn_damage"
const STAT_BURN_DURATION := "burn_duration"
## Enemy speed WHILE CHILLED, as a fraction. Lower is a stronger slow, so the
## cards that deepen it multiply by less than 1.
const STAT_SLOW_FACTOR := "slow_factor"
const STAT_SLOW_DURATION := "slow_duration"
const STAT_FREEZE_DURATION := "freeze_duration"
## How many hits it takes to land a freeze. Cards lower it; see FLAG_FLASH_FREEZE.
const STAT_FREEZE_EVERY := "freeze_every"
## Extra damage taken by a chilled enemy, as a multiplier. See FLAG_SHATTER.
const STAT_SHATTER_BONUS := "shatter_bonus"

# --- Ultimate (E). Which one you get is decided by the element lock. ---
## Seconds between casts. Deliberately long - the ultimate is an event, not a
## rotation - so Ultimate II and III do NOT shorten it.
const STAT_ULTIMATE_COOLDOWN := "ultimate_cooldown"
const STAT_ULTIMATE_DAMAGE := "ultimate_damage"
const STAT_ULTIMATE_DURATION := "ultimate_duration"
## Frozen Ground only: how wide the pool spreads.
const STAT_ULTIMATE_RADIUS := "ultimate_radius"
## Frozen Ground only: how long a caught enemy stays frozen.
const STAT_ULTIMATE_FREEZE := "ultimate_freeze"

# Booleans rather than numbers - they switch behaviour on, they don't scale it.
const FLAG_DASH_IFRAMES := "dash_iframes"
const FLAG_PARRY_REFLECT := "parry_reflect"
## Set by the element locks. The basic attack reads these to decide what it does
## on impact beyond dealing damage - see player_projectile.gd.
const FLAG_EXPLOSIVE_SHOTS := "explosive_shots"
const FLAG_CHILLING_SHOTS := "chilling_shots"
const FLAG_HOMING_SHOTS := "homing_shots"
const FLAG_BURN := "burn"
const FLAG_CHAIN_EXPLOSION := "chain_explosion"
const FLAG_SHATTER := "shatter"
const FLAG_FLASH_FREEZE := "flash_freeze"
## Unlocks E. Until an Ultimate I card is taken the key does nothing at all -
## the ultimate is a discovery, not a starting tool.
const FLAG_ULTIMATE := "ultimate"

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

# ------------------------------------------------------------------- icons ---
# Each card shows one badge from assets/images/cards/. The badges are all cut
# from the same template - a rounded square in the category colour with a white
# glyph on it - so a new one is `template.svg` with a new fill and a new glyph.
#
# The kind decides the SHAPE, the element decides the ACCENT COLOUR of the card
# frame. That is why the three ultimates share one starburst badge and still
# read as fire / ice / arcane on screen.

const ICON_HEALTH := "health"
const ICON_MOVE := "move"
const ICON_DASH := "dash"
const ICON_PARRY := "parry"
const ICON_ATTACK := "attack"
const ICON_ARCANE := "arcane"
const ICON_FIRE := "fire"
const ICON_ICE := "ice"
const ICON_ULTIMATE := "ultimate"

const ICON_DIR := "res://assets/images/cards/"

## Kind -> the colour baked into that badge. The card frame, title and pool tag
## are tinted with this, so a badge and its card always agree.
const ICON_COLORS := {
	ICON_HEALTH: Color("35c46e"),
	ICON_MOVE: Color("9bd32b"),
	ICON_DASH: Color("f2c230"),
	ICON_PARRY: Color("5b8dd9"),
	ICON_ATTACK: Color("d94fa0"),
	ICON_ARCANE: Color("9a5ce8"),
	ICON_FIRE: Color("f0602e"),
	ICON_ICE: Color("3fd0e0"),
	ICON_ULTIMATE: Color("ffd24a"),
}

## Fallback badge for a card that names an element but no icon.
const ELEMENT_ICONS := {
	Element.ARCANE: ICON_ARCANE,
	Element.FIRE: ICON_FIRE,
	Element.ICE: ICON_ICE,
}

## Slot order, left to right. One card is drawn from each.
const OFFER_ORDER := [Pool.BASIC, Pool.ACTION, Pool.ATTACK]

## Where a slot draws from once its own pool is exhausted, so the player is
## never shown a blank card. ATTACK runs dry after an element line is finished -
## the elements are one-shot chains, while ACTION cards keep coming.
const POOL_FALLBACK := {
	Pool.ATTACK: Pool.ACTION,
}


const CARDS := {

	# ------------------------------------------------------------------ BASIC
	# Utility. Only one entry for now, so this slot is currently a guaranteed
	# heal rather than a choice.
	Pool.BASIC: [
		{"name": "Renewal", "desc": "Restore health to full",
			"icon": ICON_HEALTH,
			"effect": {"op": "action", "action": "heal_full"}},
	],

	# ----------------------------------------------------------------- ACTION
	# "Action Modifier Cards" in docs/cards.md: mobility, dash, parry, and the
	# element-neutral basic attack upgrades. None of these are one-shot, so this
	# pool never runs dry - which is why ATTACK falls back to it.
	Pool.ACTION: [
		# Mobility
		{"name": "Swift Boots", "desc": "+15% move speed",
			"icon": ICON_MOVE,
			"effect": {"op": "mult", "stat": STAT_MOVE_SPEED, "value": 1.15}},

		# Dash
		{"name": "Fleet Footed", "desc": "-35% dash cooldown",
			"icon": ICON_DASH,
			"effect": {"op": "mult", "stat": STAT_DASH_COOLDOWN, "value": 0.65}},
		{"name": "Second Wind", "desc": "+1 dash charge",
			"icon": ICON_DASH,
			"effect": {"op": "add", "stat": STAT_DASH_CHARGES, "value": 1}},
		{"name": "Phase Step", "desc": "Dash grants invulnerability frames",
			"icon": ICON_DASH,
			"effect": {"op": "flag", "flag": FLAG_DASH_IFRAMES}},

		# Parry
		{"name": "Steady Hand", "desc": "+50% parry window",
			"icon": ICON_PARRY,
			"effect": {"op": "mult", "stat": STAT_PARRY_WINDOW, "value": 1.5}},
		{"name": "Shockwave", "desc": "+40% parry burst radius",
			"icon": ICON_PARRY,
			"effect": {"op": "mult", "stat": STAT_PARRY_BURST_RADIUS, "value": 1.4}},
		{"name": "Quick Recovery", "desc": "-30% parry cooldown",
			"icon": ICON_PARRY,
			"effect": {"op": "mult", "stat": STAT_PARRY_COOLDOWN, "value": 0.7}},
		# NOT WIRED: parried shots are destroyed, not turned around.
		{"name": "Reflect", "desc": "Parried shots fly back at the caster",
			"icon": ICON_PARRY,
			"effect": {"op": "flag", "flag": FLAG_PARRY_REFLECT}},

		# Basic attack
		{"name": "Sharpened Missile", "desc": "+25% basic attack damage",
			"icon": ICON_ATTACK,
			"effect": {"op": "mult", "stat": STAT_ATTACK_DAMAGE, "value": 1.25}},
		{"name": "Rapid Casting", "desc": "Cast 30% faster",
			"icon": ICON_ATTACK,
			"effect": {"op": "mult", "stat": STAT_CAST_INTERVAL, "value": 0.7}},
		# NOT WIRED: the basic attack fires a single projectile.
		{"name": "Split Bolt", "desc": "Basic attack fires an extra projectile",
			"icon": ICON_ATTACK,
			"effect": {"op": "add", "stat": STAT_PROJECTILE_COUNT, "value": 1}},
	],

	# ----------------------------------------------------------------- ATTACK
	# "Attack Variant Cards": elements and their ultimates, nothing else.
	Pool.ATTACK: [

		# The commitment. Exactly one of these can ever be taken, and only
		# while the run is still unelemented. Each turns on the flag its whole
		# school is built around, so the lock is a real upgrade on its own.
		{"id": "arcane_lock", "name": "Arcane", "element": Element.ARCANE,
			"locks": true, "unique": true,
			"desc": "Missiles hit harder and fly faster\nLOCKS: Arcane",
			"effect": [{"op": "mult", "stat": STAT_ATTACK_DAMAGE, "value": 1.25},
				{"op": "mult", "stat": STAT_PROJECTILE_SPEED, "value": 1.25}]},
		{"id": "fire_lock", "name": "Fire", "element": Element.FIRE,
			"locks": true, "unique": true,
			"desc": "Missiles explode on impact\nLOCKS: Fire",
			"effect": {"op": "flag", "flag": FLAG_EXPLOSIVE_SHOTS}},
		{"id": "ice_lock", "name": "Ice", "element": Element.ICE,
			"locks": true, "unique": true,
			"desc": "Missiles slow what they hit\nLOCKS: Ice",
			"effect": {"op": "flag", "flag": FLAG_CHILLING_SHOTS}},

		# --- Arcane line: no new verb, just better missiles. ---
		{"id": "arcane_1", "name": "Piercing Bolt", "element": Element.ARCANE,
			"unique": true,
			"desc": "Shots carry through one extra enemy",
			"effect": {"op": "add", "stat": STAT_PIERCE, "value": 1}},
		{"id": "arcane_2", "name": "Arcane Volley", "element": Element.ARCANE,
			"unique": true, "requires": "arcane_1",
			"desc": "One extra projectile every cast",
			"effect": {"op": "add", "stat": STAT_PROJECTILE_COUNT, "value": 1}},
		{"id": "arcane_3", "name": "Seeker Missiles", "element": Element.ARCANE,
			"unique": true, "requires": "arcane_2",
			"desc": "Shots curve toward their target",
			"effect": {"op": "flag", "flag": FLAG_HOMING_SHOTS}},
		# ARCANE: a huge purple beam from the player. Follows FACING and
		# deliberately ignores auto-aim - this one is aimed by hand.
		{"id": "arcane_ult_1", "name": "Ultimate I", "element": Element.ARCANE,
			"icon": ICON_ULTIMATE, "unique": true,
			"desc": "Unlocks Beam (E)\nA huge purple beam along your facing",
			"effect": {"op": "flag", "flag": FLAG_ULTIMATE}},
		{"id": "arcane_ult_2", "name": "Ultimate II", "element": Element.ARCANE,
			"icon": ICON_ULTIMATE,
			"unique": true, "requires": "arcane_ult_1",
			"desc": "Beam hits harder and lasts longer",
			"effect": [{"op": "mult", "stat": STAT_ULTIMATE_DAMAGE, "value": 1.5},
				{"op": "mult", "stat": STAT_ULTIMATE_DURATION, "value": 1.35}]},
		{"id": "arcane_ult_3", "name": "Ultimate III", "element": Element.ARCANE,
			"icon": ICON_ULTIMATE,
			"unique": true, "requires": "arcane_ult_2",
			"desc": "Beam hits harder and lasts longer again",
			"effect": [{"op": "mult", "stat": STAT_ULTIMATE_DAMAGE, "value": 1.5},
				{"op": "mult", "stat": STAT_ULTIMATE_DURATION, "value": 1.35}]},

		# --- Fire line: the blast gets wider, then lingers, then spreads. ---
		{"id": "fire_1", "name": "Wider Blast", "element": Element.FIRE,
			"unique": true,
			"desc": "+40% explosion radius\n+25% explosion damage",
			"effect": [{"op": "mult", "stat": STAT_EXPLOSION_RADIUS, "value": 1.4},
				{"op": "mult", "stat": STAT_EXPLOSION_DAMAGE, "value": 1.25}]},
		{"id": "fire_2", "name": "Cinders", "element": Element.FIRE,
			"unique": true, "requires": "fire_1",
			"desc": "Anything you burn keeps burning",
			"effect": {"op": "flag", "flag": FLAG_BURN}},
		{"id": "fire_3", "name": "Chain Reaction", "element": Element.FIRE,
			"unique": true, "requires": "fire_2",
			"desc": "Anything killed by fire explodes too",
			"effect": {"op": "flag", "flag": FLAG_CHAIN_EXPLOSION}},
		# FIRE: the screen washes red, flame rains across all of it, the camera
		# shakes. Hits EVERY enemy on screen - no aiming, no dodging.
		{"id": "fire_ult_1", "name": "Ultimate I", "element": Element.FIRE,
			"icon": ICON_ULTIMATE, "unique": true,
			"desc": "Unlocks Rain of Fire (E)\nFire falls on the whole screen",
			"effect": {"op": "flag", "flag": FLAG_ULTIMATE}},
		{"id": "fire_ult_2", "name": "Ultimate II", "element": Element.FIRE,
			"icon": ICON_ULTIMATE,
			"unique": true, "requires": "fire_ult_1",
			"desc": "Rain of Fire hits harder and lasts longer",
			"effect": [{"op": "mult", "stat": STAT_ULTIMATE_DAMAGE, "value": 1.5},
				{"op": "mult", "stat": STAT_ULTIMATE_DURATION, "value": 1.35}]},
		{"id": "fire_ult_3", "name": "Ultimate III", "element": Element.FIRE,
			"icon": ICON_ULTIMATE,
			"unique": true, "requires": "fire_ult_2",
			"desc": "Rain of Fire hits harder and lasts longer again",
			"effect": [{"op": "mult", "stat": STAT_ULTIMATE_DAMAGE, "value": 1.5},
				{"op": "mult", "stat": STAT_ULTIMATE_DURATION, "value": 1.35}]},

		# --- Ice line: the slow deepens, then it pays off, then it stops them. ---
		{"id": "ice_1", "name": "Deep Chill", "element": Element.ICE,
			"unique": true,
			"desc": "A far heavier slow, and it lasts longer",
			"effect": [{"op": "mult", "stat": STAT_SLOW_FACTOR, "value": 0.6},
				{"op": "mult", "stat": STAT_SLOW_DURATION, "value": 1.5}]},
		{"id": "ice_2", "name": "Shatter", "element": Element.ICE,
			"unique": true, "requires": "ice_1",
			"desc": "Chilled enemies take +40% damage",
			"effect": {"op": "flag", "flag": FLAG_SHATTER}},
		{"id": "ice_3", "name": "Flash Freeze", "element": Element.ICE,
			"unique": true, "requires": "ice_2",
			"desc": "Every 4th hit freezes solid",
			"effect": {"op": "flag", "flag": FLAG_FLASH_FREEZE}},
		# ICE: a pool of ice centred on the player. Everything caught inside is
		# FULLY FROZEN, not slowed. Tiers grow the pool, the ultimate's own
		# duration, and how long the freeze holds - three knobs, not two.
		{"id": "ice_ult_1", "name": "Ultimate I", "element": Element.ICE,
			"icon": ICON_ULTIMATE, "unique": true,
			"desc": "Unlocks Frozen Ground (E)\nFreezes everything around you",
			"effect": {"op": "flag", "flag": FLAG_ULTIMATE}},
		{"id": "ice_ult_2", "name": "Ultimate II", "element": Element.ICE,
			"icon": ICON_ULTIMATE,
			"unique": true, "requires": "ice_ult_1",
			"desc": "Frozen Ground spreads wider and holds longer",
			"effect": [{"op": "mult", "stat": STAT_ULTIMATE_RADIUS, "value": 1.35},
				{"op": "mult", "stat": STAT_ULTIMATE_DURATION, "value": 1.35},
				{"op": "mult", "stat": STAT_ULTIMATE_FREEZE, "value": 1.35}]},
		{"id": "ice_ult_3", "name": "Ultimate III", "element": Element.ICE,
			"icon": ICON_ULTIMATE,
			"unique": true, "requires": "ice_ult_2",
			"desc": "Frozen Ground spreads wider and holds longer again",
			"effect": [{"op": "mult", "stat": STAT_ULTIMATE_RADIUS, "value": 1.35},
				{"op": "mult", "stat": STAT_ULTIMATE_DURATION, "value": 1.35},
				{"op": "mult", "stat": STAT_ULTIMATE_FREEZE, "value": 1.35}]},
	],
}


## Tracking key for a card. Display names repeat across elements - every school
## has an "Ultimate I" - so `id` is what `unique` and `requires` key on.
static func card_id(card: Dictionary) -> String:
	return card.get("id", card["name"])


static func cards_in(pool: Pool) -> Array:
	return CARDS.get(pool, [])


static func pool_name(pool: Pool) -> String:
	return POOL_NAMES.get(pool, "?")


static func element_name(element: Element) -> String:
	return ELEMENT_NAMES.get(element, "?")


## The badge kind for a card: its own `icon`, else the one its element implies,
## else the neutral attack badge. Never returns "" - every card gets a picture.
static func icon_kind(card: Dictionary) -> String:
	var kind: String = card.get("icon", "")
	if kind != "":
		return kind
	var element: Element = card.get("element", Element.NONE)
	return ELEMENT_ICONS.get(element, ICON_ATTACK)


static func icon_path(card: Dictionary) -> String:
	return ICON_DIR + icon_kind(card) + ".svg"


## The card's accent colour, used for its frame, title and pool tag.
##
## An element card takes its element's colour even when its badge is the shared
## ultimate starburst - that is what keeps "Ultimate I" reading as fire or ice.
static func card_color(card: Dictionary) -> Color:
	var element: Element = card.get("element", Element.NONE)
	var kind: String = ELEMENT_ICONS.get(element, icon_kind(card))
	return ICON_COLORS.get(kind, Color.WHITE)
