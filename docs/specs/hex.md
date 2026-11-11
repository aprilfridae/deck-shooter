# Hex (the box 1v1 map)

**Status:** built as a grey-box free-play combat zone on 2026-11-10, from River's sketch. Not seen in Play yet. There are no rounds or scoring (`matches.md`); two players can travel there and fight.

**Code:** `src/server/Outpost/Hex.luau` builds the map at server start with the Outpost's `Kit`. `src/server/Outpost/Outpost.server.luau` handles travel and spawns. It's reached from the `HEX 1V1` terminal in the test room, and an `OUTPOST` terminal stands by each spawn.

## Layout

A walled box, 160 studs long and 90 wide, open to the sky, with plain walls 34 high to sprint along and wall jump off. The map is point-symmetric: one side is built, then built again turned half round.

- **Spawns:** one at each end, facing the middle.
- **Spawn cover:** a slab 24 long and 11 high, 28 studs in front of each spawn.
- **Ramp:** in the corner on each spawn's right, along the side wall. It's 22 wide, rises 8 studs toward the middle and ends on a plain flat lookout. River asked for no lip on it.
- **Ring:** six walls in a hexagon around the centre (20 studs out, 9 high), with gaps of about 6 between them. Each wall has two holes at chest-to-head height to shoot through. A colour cap shows which side a wall is on (cyan or red).

All the sizes are constants at the top of `Hex.luau`.

## Not done

- River hasn't seen it in Play. Sizes, heights and hole positions are first guesses to tune.
- Grey box only: no textures, lights or lighting profile of its own (it uses the test room's lighting).
