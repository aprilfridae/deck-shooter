# Hex (the box 1v1 map)

**Status:** built as a free-play combat zone on 2026-11-10, from River's sketch, with a first art pass the same day (River's brief: dystopian retro-futurism and heavy brutalism, oppressive and abandoned). River has played the grey box; the art pass has not been built or seen in Studio or Play. There are no rounds or scoring (`matches.md`); two players can travel there and fight.

**Code:** `src/server/Outpost/Hex.luau` builds the map at server start with the Outpost's `Kit`. `src/server/Outpost/Outpost.server.luau` handles travel and spawns. It's reached from the Play page's area list in the Outpost menu (`PlayPanel.luau`; it had a terminal in the test room until 2026-11-10). An `OUTPOST` terminal stands by each spawn for the way back.

## Layout

A walled box, 184 studs long and 104 wide, with plain walls 39 high and a barrel-vault roof over it (River had the whole map made 15% bigger on 2026-11-10; the windows stayed at head height) to sprint along and wall jump off. The map is point-symmetric: one side is built, then built again turned half round.

- **Spawns:** one at each end, facing the middle.
- **Spawn cover:** a slab 28 long and 12.5 high, 32 studs in front of each spawn.
- **Ramp:** on each spawn's right, along the side wall, its foot 14 studs clear of the end wall so there is room to run onto it. It's 25 wide, rises 14 studs over 21 (about 34 degrees; River asked for steeper) toward the middle and ends on a plain flat lookout. River asked for no lip on it.
- **Ring:** six walls in a hexagon around the centre (32 studs out, 29 long, 15 high), with gaps of about 8 between them. Each wall has two windows to shoot through, 7 wide and from 3.8 to 7.4 up, around head height. A lit strip on top shows which side a wall is on (orange or teal).

## Look

- **Concrete:** the floor is one damp pour; walls, ring, cover and ramps are weathered concrete with grime and water streaks (`Kit:dirty`). Rusted bar ends poke out of walls and bleed stains down them.
- **Side colours:** orange for one side and teal for the other (River, 2026-11-10: no green; every map keeps a teal and orange look), as thin lit strips on the ring and cover and as emergency lamps on the walls (three a side).
- **Dressing:** each side has a heavy analog control desk and three rusted crates in the dead corner on the spawn's left; these are solid. Dead CRT monitors lie in heaps: about half are smashed, and the intact ones still scroll code (the Outpost's screen script), some casting a small stuttering glow. Thick cables snake across the floor in slack bends, some ending in a coil, and hang slack along the walls; River wants no straight or taut cables. You walk and shoot through all of those, so the lanes are unchanged.
- **Skyline:** since the roof went on, this shows only through the hole in it. 16 ruined towers ring the arena, 172 to 310 studs out, with broken stepped tops, hanging floor slabs, and a few lit windows. No girders, steel frames or cables on them: River said thin parts read as string and the frames as floating letter Ms. Nothing out there collides.
- **Flicker:** `OutpostFlicker.client.luau` flickers the lamps subtly and the monitor glow hard (the light's `FlickerDepth` attribute).
- **Roof:** a concrete barrel vault springs from the side walls' tops (39) and arches half a circle across, 91 high at its crown, with eight darker ribs along it and the half circles above the end walls filled in. A round hole 26 across in the crown, with a collar round it, sits over the middle of the ring (`roof`; River asked for a tall arching roof with a hole for the light).
- **Roof damage:** the vault is laid in blocks of uneven length. Up to nine ragged breaks (5 to 12 studs in radius, more on one side than the other, none over the crown hole) are open to the fog; blocks round each break hang lower and askew, many are cracked, short bent bars hang from the edges, ribs are broken off there, and rubble lies underneath (it doesn't collide). The bigger breaks near the top let a thin fall of light through. River asked for it to feel like it is falling apart.
- **Windows are for bullets only (2026-11-11, not tried in Play):** an unseen block fills each ring-wall window (`WindowBlock`, collides but can't be queried), so bodies can't jump into or through them while shots and other rays pass. River was getting stuck inside the walls after they were thickened to 3.5.
- **Light from above:** a pale warm shaft falls from 190 studs up onto the middle of the ring, with a steady spotlight pooling on the floor (`heavenLight`). River asked for "a spotlight from the heavens".
- **Fog and light:** `HEX_LIGHTING` and `hexEffects` in `src/client/Outpost.client.luau`: dim dusk in dense blue-green fog.

All the sizes are constants at the top of `Hex.luau`.

## Not done

- The art pass is unseen. Check first: can you still see the other player across the arena in the fog, do the towers show over the walls, and do the floor cables or monitors look wrong to run through.
- No chipped edges or rubble on the concrete yet.
