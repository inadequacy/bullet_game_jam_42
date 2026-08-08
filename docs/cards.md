# Cards

The authoritative list is `game/cards/card_database.gd` - this file is the
*intent* behind it. When the two disagree, the code is right and this is stale.

# Basic

## Player Health cards

- Player Health
  restore to max health

# Action Modifier Cards

## Mobility Cards

- Player Speed
  increase player moving speed

## Parry Cards

- Parry Window
- Parry Destruction Size
- Parry Cooldown
- Parry Functionality on Successful Parry -> Reflect, Power, Destroy (improvement)

## Dash Cards

- Dash Amount
- Dash Cooldown
- Dash Functionality -> IFrames + Enemy Collision

## Attack Cards (basic)

- Basic Attack Damage
- Basic Attack Cast-rate
- Basic Attack Spread

# Attack Variant Cards

## Types:

Spells (element for basic)
Element: Fire (AoE), Arcane (Basic), Ice (Slow)

Taking a lock card commits the run. Each school is then a seven card chain: the
lock, three numbered spell tiers, and three ultimate tiers.

### The spell lines

| | Lock | I | II | III |
| --- | --- | --- | --- | --- |
| **Arcane** | Missiles hit harder and fly faster | **Pierce** - shots carry through one extra enemy | **Volley** - one extra projectile per cast | **Seeker** - shots curve toward their target |
| **Fire** | Missiles explode on impact, splashing neighbours | Wider blast radius | **Cinders** - hits burn over time | **Chain Reaction** - anything killed by fire explodes too |
| **Ice** | Missiles slow what they hit | Deeper, longer slow | **Shatter** - chilled enemies take extra damage | **Flash Freeze** - every Nth hit freezes solid |

Arcane is the "stay as you are" school: no new verb, just a better version of
the missiles the player already has. That is the point - committing is never
forced, and a player who likes plain missiles is rewarded for doubling down.

## Ultimate:

Bound to **E**, dead until `Ultimate I` is drawn. One per school, and which one
you get is decided by the element lock - by the time an ultimate is unlocked the
run is already Fire, Arcane or Ice.

All three start at a **3 second** duration. Tiers II and III raise damage and
duration; Ice additionally grows its pool and its freeze.

### Charge

A **flat cooldown**, 30 seconds. Taking `Ultimate I` hands over a **charged**
ultimate — the bar appears full and E works immediately — and the cooldown only
starts once it has been spent.

Tiers II and III deliberately **do not shorten it**. The ultimate is an event,
not part of a rotation, so the way to get more out of it is to make each cast
count rather than to cast it more often.

The HUD bar is hidden entirely until the unlock card is taken. A greyed-out slot
sitting there from the first second of the run would give away that the ultimate
exists and turn the card from a discovery into an inevitability.

### Fire - Rain of Fire

Screen-wide. The whole screen washes **red**, flames rain down across it, and
the camera shakes for the duration. AoE: **every enemy on screen is hit**, no
aiming and no dodging it. The falling flames reuse the flame glyph from
`assets/images/cards/fire.svg`, spawned in quantity.

*Upgrades:* damage, duration.

### Ice - Frozen Ground

A **pool of ice centred on the player**. Every enemy caught inside it is **fully
frozen** - not slowed - for 3 seconds to start with.

*Upgrades:* pool radius, ultimate duration, and how long the freeze holds.

### Arcane - Beam

A **huge purple beam** fired from the player, lasting 3 seconds. It follows
**player facing** and explicitly **does not respect auto-aim** - this one is
aimed by hand, which is what makes it the skill ultimate of the three.

*Upgrades:* damage, duration.

Weighting for each of the above.
