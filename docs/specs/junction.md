# Junction (free-for-all arena)

**Status:** grey box built on 2026-11-10, not yet seen in Play. Shapes and flow first; textures come later.

**Code:** `src/server/Outpost/Junction.luau` builds it, `src/shared/Guns/SpawnPick.luau` picks spawns (tested), `Outpost.server.luau` wires it in. Reached from the **JUNCTION FFA** terminal in the test room (right of the spawn); every corner house has an **OUTPOST** terminal back.

## Brief

River asked for a free-for-all map that plays like a fast arena shooter from a reference video (about ten players, a death every few seconds, four colour-coded areas around an open middle). It is an original layout built for Split Deck's movement, not a copy of that map.

## Layout

- A walled square, 192 studs inside, centred at (0, 100, -4000). Four-way symmetric: one quarter is built and turned three times.
- **Hub:** a 24 x 24 block, 7 high, in the middle. Four ramps up its sides laid like a pinwheel, and a cover block on top per quarter.
- **Corner houses:** 32 x 32, 12 high, each in its quarter's colour (DataCyan, SignalAcid, HazardRed, FieldGreen). Two doorways on one inner face, a long window on the other, a crate and a pillar inside, a ramp up the outside to a flat roof with a waist-high parapet.
- **Catwalks:** from each house roof's inner corner, sloping down to the hub's corner, with a colour strip.
- **Cover in each quarter:** a crate stack you can climb, a low crouch wall, a 4.5-high block to jump onto (with a lip of cover), two tall walls 8 apart for wall jumping, a block and a low block breaking the edge lane between houses, and a short wall in the open diagonal.

## Spawns

Three per quarter (twelve in all), facing the middle. On entering and on every death, a player comes back at the spawn whose nearest living player in the arena is furthest away; ties are picked at random.

## Not done

- Not seen in Play. Ramp directions, heights and gaps are worked out on paper only.
- No lighting of its own: it uses the default lighting, like the test room.
- No textures, no match rules (score, timer). Kills pay as they do anywhere else.
