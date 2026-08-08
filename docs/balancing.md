# Balancing

## Done — balance patch

Everything below was found in playtesting and has since been addressed. Kept as
a record of *why* the numbers are what they are; the numbers themselves live in
the exports, not here.

### Green enemy
- **Parryable before you could see it.** The parry resolves on arrival, so a
  window opened during the caster's *charge* still ate the shot. Now a parry
  only counts if it was opened after the beam was fired (`hitscan_parry_grace`
  of slack), and `trace_speed` dropped 2500 → 1200 so the beam is actually in
  the air for the window it opens.
- **Beam fell short and hit anyway.** The trace now only damages what is within
  `hitscan_hit_radius` (40 px) of the point it was aimed at — walk out of the
  spot and it lands behind you. Green is answerable by moving *or* parrying.

### Blue enemy
- **Too weak alone.** Rolling blue now spawns a pack of 2, sometimes 3.

### Monsters generally
- **No ramp.** Two now: the population cap climbs +1 every 35 s from 3 to a hard
  ceiling of **10**, and every enemy's attack interval slides to x0.65 across the
  run via `Enemy.attack_interval_scale()`. Wind-ups are never scaled — a
  telegraph the player cannot read is not difficulty.
- **Cleared screens trickled back.** A refill more than `catch_up_gap` under the
  cap uses `catch_up_delay` (0.25 s) instead of the full `respawn_delay`.

### Game
- **Run too long.** 12 minutes → **6**. Boss beats move to every 90 s.

### Player
- **Hit by things that visually miss.** Hurtbox 50x50 → 40x40.
- **Base attack too slow.** `cast_rate` 1.0 → 0.8.
- **XP wall.** First level 400 → 200 XP, and the curve went from x2.15 per level
  to x1.6 — the old one made the fifth card effectively unreachable.

### Cards
- Every numeric card stepped up (see `card_database.gd`), ultimates hardest:
  tiers II/III now x1.8 damage and x1.5 duration, Ultimate III also cuts the
  cooldown 25%, and the base cooldown is 30 s → 22 s.
- **Phase Step** keeps its i-frames running `dash_iframe_grace` past the end of
  the dash, and is now `unique` like every other flag card — a repeat offer of a
  switch already flipped costs the player a whole slot.
- **Crimson Guard** (new): red homing shots become parryable.
- **Reflect** is wired up at last — a landed parry fires a full cast back at the
  nearest enemy. It used to be an inert card in the live pool.

## Open

- Dash distance may still be too long. Left alone deliberately: `dash_speed` x
  `dash_duration` is what `break_lock_radius` on red homing is sized against, so
  shortening it means retuning that too.
- Bosses are still unimplemented, so the 90 s beats above are a schedule with
  nothing on it yet.
- Needs a full 6-minute playtest at the new curve to confirm the closing minute
  (10 enemies at x0.65 attack interval) is hard rather than hopeless.
