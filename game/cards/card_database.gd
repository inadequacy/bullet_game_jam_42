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

# Booleans rather than numbers - they switch behaviour on, they don't scale it.
const FLAG_DASH_IFRAMES := "dash_iframes"
const FLAG_PARRY_REFLECT := "parry_reflect"

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


const CARDS := {

	# ------------------------------------------------------------------ BASIC
	# Utility. Only one entry for now, so this slot is currently a guaranteed
	# heal rather than a choice.
	Pool.BASIC: [
		{"name": "Renewal", "desc": "Restore health to full",
			"effect": {"op": "action", "action": "heal_full"}},
	],

	# ----------------------------------------------------------------- ACTION
	# "Action Modifier Cards" in docs/cards.md: mobility, dash, parry, and the
	# element-neutral basic attack upgrades. None of these are one-shot, so this
	# pool never runs dry - which is why ATTACK falls back to it.
	Pool.ACTION: [
		# Mobility
		{"name": "Swift Boots", "desc": "+15% move speed",
			"effect": {"op": "mult", "stat": STAT_MOVE_SPEED, "value": 1.15}},

		# Dash
		{"name": "Fleet Footed", "desc": "-35% dash cooldown",
			"effect": {"op": "mult", "stat": STAT_DASH_COOLDOWN, "value": 0.65}},
		{"name": "Second Wind", "desc": "+1 dash charge",
			"effect": {"op": "add", "stat": STAT_DASH_CHARGES, "value": 1}},
		# NOT WIRED: dash has no i-frames to switch on yet.
		{"name": "Phase Step", "desc": "Dash grants invulnerability frames",
			"effect": {"op": "flag", "flag": FLAG_DASH_IFRAMES}},

		# Parry
		{"name": "Steady Hand", "desc": "+50% parry window",
			"effect": {"op": "mult", "stat": STAT_PARRY_WINDOW, "value": 1.5}},
		{"name": "Shockwave", "desc": "+40% parry burst radius",
			"effect": {"op": "mult", "stat": STAT_PARRY_BURST_RADIUS, "value": 1.4}},
		{"name": "Quick Recovery", "desc": "-30% parry cooldown",
			"effect": {"op": "mult", "stat": STAT_PARRY_COOLDOWN, "value": 0.7}},
		# NOT WIRED: parried shots are destroyed, not turned around.
		{"name": "Reflect", "desc": "Parried shots fly back at the caster",
			"effect": {"op": "flag", "flag": FLAG_PARRY_REFLECT}},

		# Basic attack
		{"name": "Sharpened Missile", "desc": "+25% basic attack damage",
			"effect": {"op": "mult", "stat": STAT_ATTACK_DAMAGE, "value": 1.25}},
		{"name": "Rapid Casting", "desc": "Cast 30% faster",
			"effect": {"op": "mult", "stat": STAT_CAST_INTERVAL, "value": 0.7}},
		# NOT WIRED: the basic attack fires a single projectile.
		{"name": "Split Bolt", "desc": "Basic attack fires an extra projectile",
			"effect": {"op": "add", "stat": STAT_PROJECTILE_COUNT, "value": 1}},
	],

	# ----------------------------------------------------------------- ATTACK
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
