# Relay (the 1v1 map)

**Status:** built as a free-play combat zone. River has been through it in Play twice on 2026-11-07, and each look led to a clean-up pass. The latest pass (one central ladder with big floor holes, no flats balcony, a wider way onto the flats stair) hasn't been checked in Play yet. Checked against the code on 2026-11-07. There are no rounds or scoring yet (`matches.md`); two players can travel there and fight.

**Code:** `src/server/Outpost/Relay.luau` builds the map at server start, using the Outpost's `Kit`. `src/server/Outpost/Outpost.server.luau` handles travel, spawns and falls. `src/client/Outpost.client.luau` applies the fog and lighting. `tests/relay_spec.luau` builds the map under Lune and checks its shape.

## The idea

Two identical relay towers stand in thick teal fog, facing each other across an open bridge. They are cold and weathered, with snow on the ledges, a lattice mast and dish on each roof's stair house, and a lit lightbox over each entrance. A block of flats hangs under the bridge, with barred windows and air conditioners; one wide, plain dark steel stair leads down into it from each side.

River wants it clean and easy to move around: rooms are left empty, props stay off the roofs and the bridge, and there's no extra structure on the towers' sides. Don't add clutter back without asking.

## Layout

The map is point-symmetric. One side is built, then the same build runs again turned 180 degrees about the centre with the same seed, so both sides match exactly. In a side's own axes the tower is toward -X, the bridge runs along X to the centre at X = 0, and the bridge deck is at Y = 0. The map's centre is at (-4000, 300, 0) in the world.

| Level | Height | What's there |
| --- | --- | --- |
| Roof | 34 | Low lip and railing, and the stair house with a mast and a dish on it (its roof at 42 can be reached with a jump and parry). Nothing else stands on the roof. |
| Top floor | 24 | An empty room with a long open window over the bridge, split by a door onto a walkable balcony (4.5 deep, the facade's full width, under the roof's edge). A door leads onto the round wing's terrace. Stairs (6 wide) go up to the roof's stair house. |
| Operations | 12 | An empty room with three facade windows (the middle one open, so you can drop to the bridge). The central ladder passes through. |
| Lobby and bridge | 0 | Spawn, the `OUTPOST` terminal, the lit entrance, and the foot of the central ladder. Then the open 80-stud bridge. |
| Undercity | -16 | A platform at the flats' door, reached by one wide flight from the bridge's edge by the tower. |

- **Tower:** 36 deep and 28 wide, from the facade at X = -40 to the back wall at X = -76. One ladder stands in the middle of the tower (X = -58, Z = 0), rungs toward the bridge, and climbs from the lobby through 8-by-8 holes in operations and the top floor. Only the top floor has stairs, up to the roof.
- **Round wing:** a 12-sided drum (radius 8) on the tower's north side, with rooms at the lobby and operations levels and a terrace on top at 24. Posts cover the seams between its wall panels.
- **Bridge:** 14 wide. Railings run down both edges, with a 7-stud gap on the north edge, by the tower, onto the landing at the top of the stairs to the flats. Nothing stands in the middle. The only cover is a crate stack and a cable spool on each half.
- **Undercity:** the flight (7 wide) ends on a dark steel platform (diamond plate on a truss) at the flats' west door. The flats have no balcony; the platform stops at their corner. Each side enters the flats from its own end, and a partition makes the way through bend. The flats' roof (at -6, outside the girder) can be dropped onto from the bridge.

## Rules the map follows

- **Railings** are 3.6 studs. An invisible wall keeps feet in, while bullets and the edge check pass through it, so you can't parry off a railing into the fog. You can still jump over one on purpose.
- **Windows** over the fog have invisible panes that stop falls but not bullets. The barred windows on the flats also have iron bars.
- **How walls let bullets through:** Roblox ignores `CanQuery = false` on a part that collides, so the invisible walls and panes sit in the `WalkOnly` collision group instead. Shots on the server and the edge check cast with the `Shots` group, which doesn't collide with `WalkOnly` (`src/shared/Guns/Collision.luau`). Before this, River's first Play test showed bullet holes hanging on a pane.
- **Ladders** are an invisible `TrussPart` (what Roblox's Humanoid climbs, from any side) in the `WalkOnly` group, with rails, rungs and a post drawn over it. The central one runs 4 studs past the top floor, so you can climb over.
- **Stairs** walk on an invisible ramp under the treads (at most about 39.4 degrees, on the flats stair; the spec checks under 40).
- **Decoration** (pipes, cables, dishes, masts, signs, snow) never collides and never stops bullets (`Kit.decor`).
- **No z-fighting:** no two visible faces may share a plane. Slabs end at the walls' inside faces, trims and painted-on windows stand at least 0.1 clear of the wall behind them, railing posts are thinner than their rails and drawn once per spot, and the round wing's panels meet only at their inside corners. Floors that sit under another floor are 0.12 lower. A checker in the build session found every face pair in the same plane; check new parts against these rules.
- **Falling:** below 60 studs under the deck, the server kills the player and they respawn in their tower.

## Spawns and travel

- The zone is `Relay` (`Zones.luau`). Combat is on, the camera is locked first person, and you wear the soldier body, as in the test room.
- The test room has a `RELAY 1V1` terminal 9 studs from its spawn, opposite the `OUTPOST` one. Each tower's lobby has an `OUTPOST` terminal by its spawn.
- Each player is given a tower when they enter the zone: the one with fewer players in it. They keep it for every respawn until they leave the zone.
- Spawns are in each lobby, facing the bridge.

## Look

- **Lighting while you're on the map:** a dense teal Atmosphere (Density 0.55, Haze 2.4), no sun or sky, morning light at clock time 9.5, a cool colour grade and bloom so the lightboxes glow. All of it is in `RELAY_LIGHTING` and `relayEffects` at the top of `Outpost.client.luau`, and it's the first thing to tune if the far tower is too clear or too hidden.
- **Particles:** slow fog wisps drift under the bridge and snow falls over each tower.
- **Signs** are drawn by the client like the Outpost's: lightbox `RELAY` signs over the entrances, a `RELAY 04` banner on each stem.

## Numbers

| What | Value |
| --- | --- |
| Tower to tower (facades) | 80 studs; spawn to spawn about 132 |
| Bridge deck to undercity | 16 |
| Parts | About 2,700 for the whole map, most of them decoration. The spec allows up to 9,000. |
| Lights | 46 |

## Not done

- Not checked in Play: climbing the ladders with the soldier body (only its root part touches the world), the fog density, the light levels, parrying onto the stair house, and how sightlines feel on the open bridge with the M57 and Longscope.
- No rounds, score or match flow. That waits on `matches.md`.
- No sounds of its own yet: wind, hum and creaking would fit.
