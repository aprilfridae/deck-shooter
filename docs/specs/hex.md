# Hex (the box 1v1 map)

**Status:** built as a free-play combat zone on 2026-11-10, from River's sketch, with a first art pass the same day (River's brief: dystopian retro-futurism and heavy brutalism, oppressive and abandoned). River has played the grey box; the art pass has not been built or seen in Studio or Play. There are no rounds or scoring (`matches.md`); two players can travel there and fight.

**Code:** `src/server/Outpost/Hex.luau` builds the map at server start with the Outpost's `Kit`. `src/server/Outpost/Outpost.server.luau` handles travel and spawns. It's reached from the `HEX 1V1` terminal in the test room, and an `OUTPOST` terminal stands by each spawn.

## Layout

A walled box, 160 studs long and 90 wide, open to the sky, with plain walls 34 high to sprint along and wall jump off. The map is point-symmetric: one side is built, then built again turned half round.

- **Spawns:** one at each end, facing the middle.
- **Spawn cover:** a slab 24 long and 11 high, 28 studs in front of each spawn.
- **Ramp:** in the corner on each spawn's right, along the side wall. It's 22 wide, rises 12 studs over 18 (about 34 degrees; River asked for steeper) toward the middle and ends on a plain flat lookout. River asked for no lip on it.
- **Ring:** six walls in a hexagon around the centre (28 studs out, 25 long, 13 high), with gaps of about 7 between them. Each wall has two windows to shoot through, 7 wide and from 3.8 to 7.4 up, around head height. A colour cap shows which side a wall is on (cyan or red).

## Look

- **Concrete:** the floor is one damp pour; walls, ring, cover and ramps are weathered concrete with grime and water streaks (`Kit:dirty`). Rusted bar ends poke out of walls and bleed stains down them.
- **Side colours:** amber for one side and a sickly green for the other, as thin lit strips on the ring and cover and as emergency lamps on the walls (three a side).
- **Dressing:** each side has a heavy analog control desk and three rusted crates in the dead corner on the spawn's left; these are solid. Dead CRT monitors lie in heaps: about half are smashed, and the intact ones still scroll code (the Outpost's screen script), some casting a small stuttering glow. Thick cables snake across the floor in slack bends, some ending in a coil, and hang slack along the walls; River wants no straight or taut cables. You walk and shoot through all of those, so the lanes are unchanged.
- **Skyline:** 16 ruined towers ring the arena, 150 to 290 studs out, with broken stepped tops, hanging floor slabs, and a few lit windows. No girders, steel frames or cables on them: River said thin parts read as string and the frames as floating letter Ms. Nothing out there collides.
- **Flicker:** `OutpostFlicker.client.luau` flickers the lamps subtly and the monitor glow hard (the light's `FlickerDepth` attribute).
- **Fog and light:** `HEX_LIGHTING` and `hexEffects` in `src/client/Outpost.client.luau`: dim dusk in dense blue-green fog.

All the sizes are constants at the top of `Hex.luau`.

## Not done

- The art pass is unseen. Check first: can you still see the other player across the arena in the fog, do the towers show over the walls, and do the floor cables or monitors look wrong to run through.
- No chipped edges or rubble on the concrete yet.
