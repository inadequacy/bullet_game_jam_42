# GameJam42

A top-down **bullet hell** with ARPG progression and roguelite runs, built in
**Godot 4.7**. High medieval sorcery — wands, staves, grimoires, no guns.

Design doc: [`docs/game_info.md`](docs/game_info.md) ·
Task board: [`docs/task_list.md`](docs/task_list.md)

---

## Running it

Open the project in Godot 4.7 and press F5. The game boots to the start menu
(`game/ui/start_menu.tscn`); the playable arena is `game/levels/level.tscn`.

To iterate on gameplay, run `game/levels/level.tscn` directly (F6) and skip the
menu.

## Controls

| Input | Action |
| --- | --- |
| **W A S D** | Move — does **not** turn the character |
| **Mouse** | Facing / aim |
| **Space** | Dash (follows WASD direction; falls back to facing) |
| **Shift** | Parry |
| **Q** | Ability *(bound, not implemented)* |
| **E** | Ultimate *(bound, not implemented)* |
| *none* | Basic spell auto-fires along facing |

---

## Folder structure

```
├── assets/                  Raw art and shaders — anything authored outside Godot
│   ├── images/              Backgrounds, sprites
│   └── shaders/             .gdshader files
│
├── autoload/                Global singletons registered in Project Settings
│   └── GameManager.gd
│
├── docs/                    Design doc and task board
│
├── game/                    Everything that makes up the game itself.
│   │                        Each scene lives NEXT TO its script.
│   ├── enemies/             Enemy base class, casters, chaser, enemy spells
│   ├── levels/              Playable arenas
│   ├── player/              Player character and player projectiles
│   └── ui/                  Menus, score display, shared button theme
│
├── icon.svg                 Project icon (also the placeholder art for everything)
└── project.godot
```

### The one rule

**A scene and its script live in the same folder.** `chaser.tscn` sits beside
`chaser.gd`. No hunting across a `Scenes/` and a `Scripts/` tree to find the two
halves of one thing.

### Where do I put a new file?

| I'm adding… | It goes in |
| --- | --- |
| A new enemy type | `game/enemies/` (scene + script together) |
| A new power-up card | `game/cards/` — create it |
| A boss | `game/enemies/` — bosses subclass `Enemy` like everything else |
| A HUD element | `game/ui/` |
| A sound effect | `assets/audio/` — create it |
| Sprites, backgrounds | `assets/images/` |
| Something global, always loaded | `autoload/` + register in Project Settings |

---

## Code layout

### Enemies

Every enemy — bosses included — extends one base class.

```
Enemy (game/enemies/enemy.gd)     health, damage, death, signals,
│                                 player lookup, face_player(), telegraph()
├── Caster (caster.gd)            holds range from the player, casts spells
└── Chaser (chaser.gd)            closes to contact, melee wind-up → strike → recovery
```

Subclasses override four hooks and never touch the rest: `_on_enemy_ready()`,
`_behavior(delta)`, `_on_damaged()`, `_on_death()`. `_behavior()` sets
`velocity`; the base class calls `move_and_slide()`.

**All three casters are the same script.** Blue, green and red differ only by
exported values in their scenes, so a new spell colour costs a scene and zero
code.

| Scene | Fires | Role |
| --- | --- | --- |
| `caster_blue.tscn` | Blue, 5-shot spread | The crowd you clear |
| `caster_green.tscn` | Green, single telegraphed shot | The parry bait |
| `caster_red.tscn` | Red, homing | The dash bait |

### Projectile colours

The colour language is the whole combat vocabulary:

- **Blue** — not parryable, but destroyed by a successful parry's burst.
- **Green** — the only parryable colour. Parrying one triggers the burst.
- **Red** — homing. Not parryable, not cleared. **Dashing severs its lock.**

Red reads `is_dashing` off the player. If the dash is ever rewritten, that flag
has to survive or red becomes unavoidable.

### Placeholder art

Everything is `icon.svg`. Enemies use `assets/shaders/invert.gdshader` to render
as the player's negative, then tint per type. All characters are scaled to 0.4.

> Chaser `attack_range` must stay larger than the combined collider radii of the
> chaser and the player, or it bumps into the player forever without swinging.
> Re-check it whenever a collider changes size.

---

## Working together

`.tscn` files merge badly. A conflicted scene file looks fine in a diff and is
fatal to Godot.

- **Before committing after any merge or stash pop**, check for conflict markers:
  `git diff --check`, or grep for `<<<<<<<`. This has already broken the project
  once.
- **Commit `.uid` files.** Godot generates a `.gd.uid` next to every script. If
  one is missing, everyone else's Godot invents a different UID and scene
  references silently fall back or break. Three UI scripts had this problem.
- **Avoid two people editing `level.tscn` at once** — it's where everything gets
  instanced, so it's the natural collision point.
- `.godot/` is generated and gitignored. If the editor behaves strangely after
  files move, delete it and let Godot rebuild.
