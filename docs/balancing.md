# Balancing

## Player
- Dash distance too long (duration 0.1, dist 600 better) in movement.gd Character Settings
- Not a great feel to get hit by things that don't visually hit, we might wanna make the hitbox smaller too.
- Exp requirement is too high atm (from start) (350 start mb) GameManger.gd line 11 and 34
- Better base attack speed (try 0.7) movement.gd Character Settings (Attack)

## Green Enemy
- Attack can be parried before you see it, should be as you begin to see it (slightly later)
- Lazor doesn't always reach player, maybe its doing range wrong, but even when out of range you get hit

## Blue Enemy
- Whenever one spawns naturally an extra one (at least) should spawn. They are incredibly weak alone
- More of these makes all other mobs harder which is good

## Monsters Generally
- Needs to ramp up:
-> Attack frequency
- More should spawn faster, either per level up +1 max mobs or every 20 seconds +1 max mobs
- If there's ever only one or so mob left max mobs should be increased too
- ^ All this with a certain cap to be determined, since clutter will get bad, but does need ramping ^

## Game
- Time too long half it probably? At least * 0.66.

## Cards
- Maybe tune them to be more powerful
- More IFrames from picking it
- Parry red ammo as a card would be nice
