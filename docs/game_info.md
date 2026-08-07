# GameJam42 — Design Doc

A top-down **bullet hell** with **ARPG** progression and **roguelite** runs.
Theme: **high medieval sorcery**. The protagonist casts spells — wands, staves,
grimoires, bare hands. **No guns, no triggers, nothing with a barrel.**

A run is **12 minutes long** and ends in a win or a death. Fixed single-screen
arena, no scrolling.

---

## 1. Core Loop

```
survive waves → kill enemies → gain XP → level up → pick 1 of 3 cards
    → boss every 3 minutes → kill the final boss at 12:00 → win
```

Everything gained is lost on death. No meta-progression in the jam build.

## 2. Player

### Inputs

| Action | Input | Behavior |
| --- | --- | --- |
| Move | WASD | 8-directional, constant speed. **Does not change facing** |
| Face | Mouse | Player always faces the cursor, independent of movement |
| Dash | Space | Short burst along **WASD direction**, ~0.4 s cooldown. **No i-frames by default** — i-frames are a card |
| Parry | Shift | Short active window (~0.15 s), ~1.5 s cooldown |
| Ability | Q | **Undecided.** Behavior not designed yet — implement late or cut |
| Ultimate | E | Fires along **facing**. **Locked** until the Ultimate card is drawn |

Movement and aim are decoupled — this is a twin-stick scheme with the mouse as
the right stick. The player can strafe, retreat, and circle while keeping the
cursor on a target.

**Dash direction is WASD, never facing.** Facing north while holding D dashes
*east*. The dash follows the keys, not the cursor.

Two reasons this matters:

- **Reaction speed.** A facing-based dash would force a look-then-dash sequence —
  aim the cursor at the escape route, *then* press dash. That's far too slow for
  red homing, which is the exact situation dash exists to solve.
- **Damage uptime.** Red can only be escaped by dashing. If dash were welded to
  aim, every escape would turn the player away from their targets and zero out
  their damage. Retreating while still shooting is the point.

If dash is pressed with **no movement key held**, it falls back to facing direction.

### Attack

The basic spell **auto-fires along facing** (toward the cursor) on a fixed
interval. "Auto" means **auto-fire, not auto-aim** — no clicking, but the player
still points.

Aiming is the only offensive decision in the kit, and it's what makes the mouse
mean one consistent thing across shooting, the ultimate, and (later) the ability.
Auto-targeting the nearest enemy was considered and rejected: it makes the mouse
matter for some actions and not others, and "nearest" reliably picks the melee
chaser at your feet over the caster across the arena that's actually threatening.

*Tuning escape hatch:* if manual aim proves too demanding alongside dodging, add a
small **snap assist** — bias shots toward an enemy within a few degrees of the
cursor. Keeps aiming meaningful without punishing imprecision.

### Parry

A successful parry (green projectiles only) triggers a **clear burst** — a small
radius around the player that destroys blue projectiles. Green is the only
parryable color and the only color that rewards parrying.

### Health

**Hearts**, not an HP bar. Discrete and readable at a glance, and hearts are the
only enemy drop, so the pickup and the resource are the same object.

## 3. Projectile Colors

The color language is the entire combat vocabulary. Keep it strict — the player
must read a full screen in a quarter second.

| Color | Behavior | Parryable | Cleared by parry burst | The answer is |
| --- | --- | --- | --- | --- |
| 🔵 **Blue** | Straight, slow, dense | No | **Yes** | Parry a green shot to clear the screen |
| 🟢 **Green** | Straight, telegraphed | **Yes** | n/a (it's the trigger) | Parry it |
| 🔴 **Red** | **Homing** | No | No | **Dash** — only dash displacement escapes it |

Red is the only projectile that chases you, which makes it the only one that
demands a dash. Blue is the crowd you clear, green is the opportunity you punish,
red is the threat that follows you home.

Red is introduced by the first boss and only becomes a normal spawn afterwards —
see §5.

**Red homing tuning — the single most important number in the game.** Red is
escaped by *displacement only*: dash displacement works, walking displacement
does not. The projectile's turn rate must sit in the window between the two.

```
turn rate too low  → player strafes away, red is harmless
turn rate correct  → walking never escapes, a dash always does
turn rate too high → dash never escapes, red is an unavoidable hit
```

Dash has no i-frames by default, so red must never be unavoidable. Tune turn rate
against walk speed and dash distance first, before touching anything else about
red. Every dash card (+distance, +charges, −cooldown) shifts this balance, so
re-check it after the card pool exists.

## 4. Progression

### XP and Cards

XP comes from kills. On level-up the game pauses and offers **3 random cards**.
Cards upgrade **spells and abilities** — they are not generic stat sticks.

| Card group | Examples |
| --- | --- |
| **Basic spell** | +damage, +fire rate, +projectile count, pierce, homing shots |
| **Dash** | **i-frames** *(keystone — weight it rare)*, +charges, −cooldown, +distance |
| **Parry** | +window duration, −cooldown, +burst radius, heal on successful parry |
| **Ultimate (E)** | **Unlock Ultimate** *(rare, appears once)*, then +charge rate |

*(Ability (Q) cards exist only if the ability ships — see §2.)*

The Ultimate is a discovery, not a starting tool. Drawing it should feel like the
run turned a corner. Once unlocked it charges by dealing and taking damage.

### Drops

Enemies rarely drop **hearts**, and nothing else. Hearts are the only healing in
the game outside the heal-on-parry card.

## 5. Enemies

Every enemy shares one base class. Bosses are subclasses of it too. What
separates enemy types is **how they position** and **what they throw**.

### Two movement archetypes

**Range-keepers (casters).** A caster holds a preferred distance from the player
rather than closing on them. If the player is further than that, it advances; if
the player closes inside it, it backs away; and while inside the tolerance band
it **strafes sideways**, reversing direction periodically so it doesn't orbit
predictably. Casters **root themselves during a cast wind-up**, which is what
makes them punishable — the player who reads the telegraph can close and kill.

**Chasers (melee).** A chaser has no preferred distance. It walks straight at the
player and attacks on contact. It is the enemy that punishes standing still, and
the reason the player can't just camp a corner and out-range the casters.

### The roster

| Enemy | Positioning | Attack | Role |
| --- | --- | --- | --- |
| **Chaser** | Closes to contact | Melee, on a cooldown with a wind-up | Denies camping, pressures position |
| **Blue caster** | Holds range | Dense blue spreads | The "clear this" enemy |
| **Green caster** | Holds range | Telegraphed green shots | The "parry me" enemy |
| **Red caster** | Holds range | Red homing | The "dash now" enemy |

**Spawn blue and green casters together.** The parry burst only means something
when there's blue on screen to clear, so pairing them is what teaches the
mechanic without a tutorial.

**Gate red casters behind the first boss (3:00).** Red is introduced by the boss,
so it should be a boss's signature before it becomes a normal spawn. Letting red
casters into the opening minutes makes red read as background noise instead of
escalation, and the player meets homing before they've had a chance to draw dash
cards.

The chaser should be in the very first wave. It's the simplest enemy to read and
it establishes movement as the core verb before any projectile appears.

### Melee attack shape

The chaser must not be an instant contact-damage blob — that punishes the player
for the enemy's pathing rather than for their own mistakes. Give it the same
shape as a cast:

1. **Wind-up** — it stops and telegraphs, ~0.4 s.
2. **Strike** — a short hitbox in front of it.
3. **Recovery** — a cooldown before it can swing again.

That makes melee dodgeable by dashing or simply walking away, which keeps every
threat in the game answerable by movement.

## 6. Run Structure

The run clock **never stops**. Bosses spawn on a fixed schedule regardless of
what's happening.

| Time | Event |
| --- | --- |
| 0:00 | Run starts, normal waves |
| 3:00 | Small boss #1 |
| 6:00 | Small boss #2 |
| 9:00 | Small boss #3 |
| 12:00 | **Final boss** |

- The clock does **not** pause during boss fights.
- If a small boss is still alive when the next one spawns, **they stack** — you
  now fight both, and potentially all three. This is intended. Slow kills are
  punished, and a run can spiral out of reach. No despawn, no mercy rule.
- After 12:00 the clock stops advancing. Normal waves keep spawning and the run
  ends only when the **final boss dies**. Killing it is the win condition.

### Difficulty Ramp

Difficulty escalates through **enemy density** — more enemies on screen, spawning
faster, as the run clock advances. Enemy stats stay flat; the crowd is the
pressure. Bosses are punctuation on top of a continuously rising baseline, not
the only escalation.

Normal waves keep spawning during boss fights and after 12:00.

### Boss implementation (jam-sized)

Build **one small boss** and reuse it three times with escalating stats, adding a
single new attack pattern each time. Then build **one final boss** with its own
fight. Four bespoke bosses is not a 48-hour task; one plus variations is.

---

## 7. 48-Hour Scope

### Must Have (this is the game)
- Player: move, mouse facing, dash, auto-fire, parry
- Blue + green projectiles with correct parry/clear rules
- Two enemy types (chaser, caster) and a density-ramping wave spawner
- XP, level-up, 3-card choice with ~10 cards
- Small boss with red homing projectiles, spawning on the 3-minute schedule
- Final boss at 12:00, and a win screen
- Death → restart

### Should Have
- Third enemy type
- Ultimate + its unlock card
- Heart drops
- Sound: shoot, hit, parry, level-up, boss spawn, death
- Run timer, kill counter, level reached on the end screen

### Cut First (in this order)
1. Scrolling / infinite arena — fixed screen ships
2. **Ability (Q)** — undesigned, and the kit reads fine without it
3. Boss variations #2 and #3 — if time is short, one small boss at 3:00 and the
   final boss at 12:00 is a complete arc
4. Ultimate — the unlock card is a nice moment, but it is not load-bearing
5. Multiple playable characters — ship one
6. Menus beyond "click to start" / "click to retry"

### Timeline

| Hours | Goal |
| --- | --- |
| 0–6 | Movement, mouse facing, dash, auto-fire. **Feel good before anything else.** |
| 6–13 | Chaser + blue caster, projectiles, damage, hearts, death. First playable loop. |
| 13–20 | Parry + clear burst. Green caster. Tune the parry window hard. |
| 20–27 | XP, level-up UI, card pool |
| 27–34 | Small boss + red homing. Boss spawn timer and stacking. |
| 34–39 | Final boss, win screen, difficulty ramp across the 12 minutes |
| 39–43 | Art pass, SFX, screen shake / hit-stop, particles |
| 43–46 | **Balance and playtest only. No new features.** |
| 46–48 | Build, upload, write the itch page. Do not skip this. |

### Rules for the jam
- **Playable build by hour 13, and a fresh uploadable build every ~8 hours after.**
  An unfinished game that's uploaded beats a finished game that isn't.
- Placeholder art the whole way. Colored shapes read fine — the color rules matter
  far more than the sprites.
- Feature freeze at hour 43, no exceptions.
- **Playtest the full 12 minutes at least twice before submitting.** A run length
  this specific has to be felt, not reasoned about.

---

## 8. Deferred Decisions

- **Ability (Q)** — no behavior designed. Build the rest of the kit first; decide
  late whether to add one or drop the input entirely. Nothing else depends on it.
- **Infinite / scrolling arena** — only if the 12-minute run ships early.
