# GameJam42

A top-down **bullet hell** with roguelite runs, built in **Godot 4.7**. High
medieval sorcery — wands, staves, grimoires, no guns.

Design doc: [`docs/game_info.md`](docs/game_info.md) ·
Cards: [`docs/cards.md`](docs/cards.md) ·
Balancing: [`docs/balancing.md`](docs/balancing.md) ·
Tasks: [`docs/task_list.md`](docs/task_list.md)

---

## Running it

Open in Godot 4.7 and press F5 — the game boots to the start menu. To iterate on
gameplay, run `game/levels/level.tscn` directly (F6) and skip the menu.

## Controls

| Input | Action |
| --- | --- |
| **W A S D** | Move — does **not** turn the character |
| **Mouse** | Facing / aim |
| **Space** | Dash (follows WASD; falls back to facing) |
| **Shift** | Parry |
| **E** | Ultimate — dead until an Ultimate I card is taken |
| **T** | Toggle aim: nearest enemy (default) ⇄ facing |
| **Esc** | Pause |
| **Q** | Ability *(bound, not implemented)* |
| *none* | Basic spell auto-fires, at the nearest enemy by default |

**Debug keys** — remove before submitting: **G** opens the card screen, **H**
toggles invincibility.

---

## Folder structure

```
├── assets/            Art, shaders and audio authored outside Godot
├── autoload/          Globals: GameManager (score/XP), RunState (cards)
├── docs/              Design doc, card list, balancing notes, task board
├── game/
│   ├── cards/         Card database + the level-up screen
│   ├── enemies/       Enemy base class, casters, chaser, enemy spells
│   ├── levels/        Arena, spawn director, camera shake, sound manager
│   ├── pickups/       Health hearts
│   ├── player/        Character, projectiles, ultimates, parry visuals
│   └── ui/            HUD, menus, bars
└── project.godot
```

**The one rule: a scene and its script live in the same folder.** `chaser.tscn`
sits beside `chaser.gd`. No hunting across parallel `Scenes/`+`Scripts/` trees.

| I'm adding… | It goes in |
| --- | --- |
| A power-up card | `game/cards/card_database.gd` — data only, nothing else to touch |
| An enemy or boss | `game/enemies/` — bosses subclass `Enemy` like everything else |
| A HUD element | `game/ui/`, then instance it in `hud.tscn` |
| Something always loaded | `autoload/` + register in Project Settings |

---

## Code layout

### Cards and run state

A run is shaped by cards. `card_database.gd` is **pure data** — adding a card
there needs no other change. `card_screen.gd` picks which three are offered,
`RunState` applies them and remembers what a run has accumulated.

Gameplay never reads a raw export. It asks for the modified value:

```gdscript
RunState.modified(CardDatabase.STAT_MOVE_SPEED, movespeed)
```

so a card can retune anything without that system knowing cards exist. `RunState`
is an autoload because it has to outlive the level reload on restart.

The first attack card **locks an element** — Arcane, Fire or Ice — and every
attack card after it comes from that school, ultimate included.

### Enemies

Every enemy, bosses included, extends one base class.

```
Enemy (game/enemies/enemy.gd)   health, damage, death, player lookup,
│                               face_player(), telegraph()
├── Caster (caster.gd)          holds range, casts spells
└── Chaser (chaser.gd)          closes to contact, wind-up → strike → recovery
```

Subclasses override four hooks and touch nothing else: `_on_enemy_ready()`,
`_behavior(delta)`, `_on_damaged()`, `_on_death()`. `_behavior()` sets
`velocity`; the base class calls `move_and_slide()`.

**All three casters are the same script**, differing only by exported values, so
a new spell colour costs a scene and zero code.

| Scene | Fires | Role |
| --- | --- | --- |
| `caster_blue.tscn` | Blue, 2-shot spread | The crowd you clear |
| `caster_green.tscn` | Green, one fast shot after a long charge | The parry bait |
| `caster_red.tscn` | Red, homing | The dash bait |

**Enemies are not placed in `level.tscn`.** `level.gd` owns the population: it
counts heads every frame and tops the arena back up to a cap that climbs by one
every `population_step` seconds, from `starting_population` to `max_population`.
Placing one by hand only puts the count over cap until it dies.

New arrivals start off screen and walk in — `Enemy.enter_from()` skips
`_behavior()` until they arrive, so nothing attacks from outside the view. A new
enemy type gets that for free as long as its logic lives in `_behavior()`.

### The colour language

The three projectile colours are the whole combat vocabulary:

- **Blue** — not parryable, but destroyed by a successful parry's burst.
- **Green** — the only parryable colour, and too fast to dodge on reaction. The
  charge aura is the warning; the answer is a parry timed off it. Parrying one
  triggers the burst and costs no cooldown.
- **Red** — homing. Not parryable, but the burst clears it. Outside the burst,
  **dashing severs its lock** and remains the answer — and severing one refunds
  the dash charge, so the counter to red is free.

Red reads `is_dashing` off the player. If the dash is ever rewritten, that flag
has to survive or red becomes unavoidable.

### HUD

Four clusters in `game/ui/hud.tscn`, each where the eye already expects it:

| Where | What |
| --- | --- |
| top left | abilities — dash, parry, ultimate |
| top centre | the run clock |
| top right | score |
| bottom centre | XP over health, the two bars read while dodging |

XP sits above health and is drawn thinner, so the one that matters in a fight is
the one the eye lands on. Both captions are drawn **inside** their bar rather
than above it, which is what lets the two stack flush.

**No panels behind any of it.** The readouts sit straight on the arena and every
caption carries its own outline instead, so the HUD costs the player no visible
floor. Each cluster fades independently while the player stands behind it — being
cornered under the vitals is no reason to dim the clock. Anything in the
`hud_cluster` group fades, so moving a cluster or adding a fifth needs no change
to `hud.gd`. Bars find what they need through groups (`health_bar`, `player`,
`run_clock`) rather than node paths, so the level needs no wiring.

> Chaser `attack_range` must stay larger than the combined collider radii of the
> chaser and the player, or it bumps into them forever without swinging.
> Re-check whenever a collider changes size.

---

## Working together

`.tscn` files merge badly. A conflicted scene looks fine in a diff and is fatal
to Godot.

- **After any merge or stash pop**, check for conflict markers before committing:
  `git diff --check`, or grep for `<<<<<<<`. This has broken the project once.
- **Commit `.uid` files.** Godot writes a `.gd.uid` beside every script; a
  missing one makes everyone else's Godot invent a different UID and scene
  references silently break.
- **Avoid two people editing `level.tscn` at once** — it's where everything is
  instanced, so it's the natural collision point.
- `.godot/` is generated and gitignored. If the editor misbehaves after files
  move, delete it and let Godot rebuild.
