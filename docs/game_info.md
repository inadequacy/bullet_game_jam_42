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
| Dash | Space | Short burst along **WASD direction**, ~0.4 s cooldown. **No i-frames by default** — i-frames are a card. **Refunded in full when it severs a red lock** |
| Parry | Shift | Short active window (~0.2 s), 0.4 s cooldown — **refunded in full if the parry connects** |
| Ability | Q | **Undecided.** Behavior not designed yet — implement late or cut |
| Ultimate | E | Fires along **facing**. **Locked** until the Ultimate card is drawn |
| Toggle aim | T | Switches the basic spell between auto-aim and facing |

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

The basic spell fires on a fixed interval with no button held. It has **two aim
modes**, flipped with **T**:

| Mode | Shots go | |
| --- | --- | --- |
| **Auto** | At the nearest enemy | **Default** |
| **Manual** | Along facing (the cursor) | |

Auto-aim frees the whole hand for movement, which is the right default in a
bullet hell where dodging is the skill. Manual exists because "nearest" is a
crude heuristic — it will happily pick the chaser at your feet over the caster
across the arena that is actually killing you. When target priority matters, the
player takes the wheel.

Both modes fall back to facing when there is no enemy in range, so the player is
never left firing at nothing.

*If auto-aim proves too strong,* the middle ground is **snap assist**: fire along
facing but bias toward an enemy within a few degrees of the cursor. Keeps aiming
meaningful without punishing imprecision.

### Parry

A successful parry (green projectiles only) triggers a **clear burst** — a small
radius around the player that destroys **every other colour inside it, blue and
red alike**. Green is the only parryable color and the only color that rewards
parrying.

The green ring drawn on a parry is **a promise, not decoration**: the clear field
is held open at exactly the ring's radius for exactly the ring's lifetime, so
everything the circle covers dies, including shots that fly into it after the
parry landed. Do not let the two drift apart — an instantaneous burst under an
animated ring reads as broken, because the player watches the circle sweep over
survivors.

Card upgrades to `parry_burst_radius` scale the ring as well as the field, and
the stroke thickens with it so a bigger burst reads as heavier rather than just
wider.

A parry that connects also **refunds its own cooldown instantly** — the bar is
full again the moment it lands. The lockout exists to punish a wild press, so
reading the screen correctly costs nothing and parries can be chained. Miss, and
the normal cooldown runs.

### Health

**Hearts**, not an HP bar. Discrete and readable at a glance, and hearts are the
only enemy drop, so the pickup and the resource are the same object.

## 3. Projectile Colors

The color language is the entire combat vocabulary. Keep it strict — the player
must read a full screen in a quarter second.

| Color | Behavior | Parryable | Cleared by parry burst | The answer is |
| --- | --- | --- | --- | --- |
| 🔵 **Blue** | Straight, slow, dense | No | **Yes** | Parry a green shot to clear the screen |
| 🟢 **Green** | **Hitscan** after a charge | **Yes** | No — it's the trigger | Parry the charge |
| 🔴 **Red** | **Homing** | No | **Yes** | **Dash** — dashing severs its lock, and refunds the charge |

Red is the only projectile that chases you, which makes it the only one that
demands a dash. Blue is the crowd you clear, green is the opportunity you punish,
red is the threat that follows you home.

The burst clears red as well as blue, but that does not make the dash redundant:
the burst only reaches `parry_burst_radius`, and it needs a green shot on screen
to trigger at all. Red at range is still a dash problem. What the burst buys is
that a landed parry is never a consolation prize — it does not leave the one shot
that was actually chasing you still in the air.

Red is introduced by the first boss and only becomes a normal spawn afterwards —
see §5.

### Green: parry the charge, not the shot

Green fires a **fast travelling trace** after a visible charge. Three stages:

| Stage | Duration | What the player sees |
| --- | --- | --- |
| **Charge** | `charge_time` — 0.6 s | Caster roots itself. A green aura swells around it, growing in size and opacity the whole time, while the caster's own sprite brightens |
| **Shot** | ~0.18 s over 400 px | A green streak crosses the gap at `trace_speed` (2200 px/s) |
| **Impact** | — | Damage, or nothing if a parry is active |

**The streak is visible but not reactable** — under a fifth of a second in
flight. The reaction window is the *aura*, which is why it builds gradually
rather than popping on: how bright it is tells you how close the shot is.

The shot is **committed** — it aims where the player stood at fire time and does
not track. Green is not answered by dodging; it's answered by parrying.

Damage and the parry check resolve **on arrival, not on firing**. So the real
window from first glow to impact is ~0.78 s, comfortably reactable, and a parry
pressed slightly late still catches the shot in flight.

That makes green the one enemy that trains rhythm rather than reflex. Blue and
red are objects in flight you respond to; green is a clock you learn.

### Red: how the dash actually escapes it

**Dashing severs the projectile's lock.** The shot stops tracking, continues in
a straight line, and dims so the player can see the dash worked. Red also gives
up tracking after ~3 seconds regardless, so no shot chases forever.

This replaces the original plan, which was to tune the *turn rate* into a window
where walking is too slow to escape but a dash is fast enough. **That window does
not exist**, and it was measured rather than guessed:

- Swept projectile speeds 600–900 against turn rates 90–400. In every
  combination, either both walking and dashing escaped, or neither did.
- Raising dash speed made things *worse*, not better — at turn rate 120,
  increasing dash speed from 800 to 1600 moved the closest approach from 47px
  to 0.9px, i.e. from a clean miss to a direct hit.

The reason is structural: a rate-limited pursuit re-aims every frame, so a dash
is only *walking, briefly faster* — a quantitative difference, not a qualitative
one. Displacement alone can never be the counter. With break-lock, walking is hit
by 1–14px and dashing escapes by 140–157px across the whole tested range.

Turn rate is now set high (220°/s) precisely so walking cannot escape. The dash
is the only answer, which is exactly the intent — reached by a different route.

> **Dependency:** this reads a boolean `is_dashing` on the player, set for the
> duration of the dash in `Scripts/movement.gd`. If the dash is ever rewritten,
> that flag has to survive or red becomes unavoidable.

## 4. Progression

### XP and Cards

XP comes from kills. On level-up the game pauses and offers **3 cards — one from
each pool**, always in the same left-to-right order. The slots are fixed so the
player learns where to look instead of re-reading three random cards under
pressure.

| Slot | Pool | Contents |
| --- | --- | --- |
| 1 | **Basic** | Utility. Currently only *Renewal* (restore to full health) |
| 2 | **Action** | Mobility, dash, parry, and basic attack damage / cast rate / spread |
| 3 | **Attack** | Elements and their ultimates, nothing else |

Slot 3 is the only one that can run out — the element lines are one-shot chains,
seven cards deep. When it does, **slot 3 falls back to an Action card**, so the
player always gets three real choices and never a blank. The fallback never
repeats whatever slot 2 already offered.

### Element lock

The player starts with plain **magic missiles** — no school committed. The Attack
slot offers three one-time commitment cards:

| Card | Commits to | Effect |
| --- | --- | --- |
| **Arcane** | Arcane | Keep your missiles, refined |
| **Fire** | Fire | Missiles explode on impact |
| **Ice** | Ice | Missiles slow what they hit |

**Taking one locks the run.** From that point the Attack slot only ever offers
element-neutral upgrades (damage, cast rate, spread) plus that element's own
cards — and the **ultimate is that element's ultimate**. The other two schools
become permanently unreachable.

Arcane is the "stay as you are" option, which matters: it means committing is
never forced, and a player who likes plain missiles gets rewarded for doubling
down rather than punished for not switching.

Element-specific cards **do not appear before a commitment**, so the choice is
never pre-empted by a card the player can't use yet.

### Element tiers

Each school has two numbered chains, offered strictly in order — tier II only
appears once tier I is taken:

```
Fire  →  Fire I  →  Fire II  →  Fire III          (spell line)
      →  Ultimate I  →  Ultimate II  →  Ultimate III   (ultimate line)
```

`Ultimate I` is the unlock; II and III upgrade it. That means the ultimate is
still a discovery — it can't be upgraded before it's found — and the E key stays
dead until the player draws it.

A commitment card plus six tiers is seven Attack-slot cards per run. Once that
line is spent the slot falls back to Action cards, which is the intended tail
rather than a gap.

*Names are placeholders.* Display names repeat across schools — every element has
an `Ultimate I` — so cards are tracked internally by `id`, not by name.

Because the Basic pool holds a single card, slot 1 is currently a **guaranteed
heal** rather than a choice. That is fine early — it means a level-up always
offers a way out of trouble — but the pool needs more entries before the slot
feels like a decision.

Cards upgrade **spells and abilities** — they are not generic stat sticks.

| Card group | Examples |
| --- | --- |
| **Basic spell** | +damage, +fire rate, +projectile count, pierce, homing shots |
| **Dash** | **i-frames** *(keystone — weight it rare)*, +charges, −cooldown, +distance |

**Dash i-frames (Phase Step)** make the player invulnerable for the length of
the dash only — it is not a standing shield. Blocked shots **pass through**
rather than being destroyed, so invulnerability never doubles as a screen clear;
clearing bullets stays the parry's job. The player goes translucent and cold
during an invulnerable dash so the card is visibly doing something.
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
when there's something on screen to clear, so pairing them is what teaches the
mechanic without a tutorial. Green must always be paired with *something* — a
parry with an empty screen around it is a refunded cooldown and nothing else.

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

`level.gd` holds the arena at a **fixed head count per tier**, stepping up on the
same three-minute beat as the bosses:

| Clock | Tier | Enemies alive |
| --- | --- | --- |
| 12:00 – 9:00 | 1 | 3 |
| 9:00 – 6:00 | 2 | 4 |
| 6:00 – 3:00 | 3 | 5 |
| 3:00 – 0:00 | 4 | 6 |

It is a **cap that is always met**, not a spawn budget: kill one and the arena
tops itself back up after `respawn_delay`, so the pressure never sags. Which
enemy arrives is random from `ENEMY_SCENES`. The refill is driven by a head count
rather than by death signals, so a tier stepping up, several kills landing at
once, or an enemy lost some other way all resolve identically without anything
having to report them.

**Enemies never appear in the arena.** They spawn `spawn_offscreen_margin` past
the nearest edge and walk in, and `_behavior()` is skipped until they arrive — a
caster that could fire from outside the view would be attacking from somewhere
the player cannot see, let alone answer.

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
- **Leaderboard** - image if I wrote like AI.
