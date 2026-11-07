# The Outpost

**Status:** step 1, the place itself, is built. River confirmed the floors, textures and lamp shadows in Play on 2026-11-05. The Market, the Loadout button and the Credits HUD aren't built. Checked against the code on 2026-11-05.

**Code:** `src/server/Outpost/` builds it when the server starts: `Kit.luau` has the building helpers, `Map.luau` the layout, and `Outpost.server.luau` the zones and travel. `src/client/Outpost.client.luau` applies the lighting and draws the sign and screen text.

## Goal

The Outpost is Split Deck's hub. Players idle there to earn Credits, buy packs and cards at the Market, and manage their loadout. PLAY lands players in its main hall. The test room stays, reached through a door in the Outpost.

Reference board: River's Pinterest board "the-outpost", downloaded to `H:\outpost inspiration\aprilfridaethe-outpost` (6 images, not in the repo).

## Decisions from River

- Amber is for world lights only. Signs and screens use the palette (`Palette.luau`).
- Every sign in the Outpost is Deep Navy with Bone text and no outline. No other colours.
- The stalls have no neon. Their strips and signs are matte, lit by ordinary lights that stay steady. A walk-up flicker and a distance fade were tried and removed. Anything laid over a sign's face has to be drawn with its text: thin strips 0.08 studs off the face vanished into it at a distance, which was the real cause of the glow cutting off.
- Loadout and Credits will be HUD or GUI features, not places.
- Rain around the camera was tried and removed, because the drops passing the camera looked wrong.

## Look

A concrete building at sea. Everything you can walk through is indoors, and windows look out on grey water and rocks fading into the fog.

- **Air:** a teal-grey haze inside the building.
- **Light:** cold, washed-out daylight, with warm amber lamps, bulbs and doorways as the main warm light.
- **Surfaces:** weathered concrete, rusted orange steel, cracked tile and wet ground. Each floor is one smooth slab with grime, hairline cracks and (on wet floors) puddles drawn over it at a large scale, so nothing visibly repeats. Worn paint: drains, covers and oil stains. Walls are cut into panels with grime and water-streak overlays, mixed with plaster.
- **Detail:** cables strung overhead, a catwalk.
- Roblox has no screen-space reflections, so puddles look wet and shiny but don't mirror the signs.

## Layout

The Outpost is built at (4000, 0, 0), far from the test room at the world's origin. Positions here are local to that point and at full size: the whole place is built at 75% of them, set by `src/server/Outpost/OutpostScale.luau`. Local +Z runs along the main hall toward the Market, and X along the side halls. The floors are at 6.

| Area | What's there |
| --- | --- |
| Market Hall | Barrel-vaulted concrete hall with a round skylight open to the rain over the middle of the crossing, a catwalk along the east wall, cut across the East Hall's mouth with two hanging plates to jump between (7 studs apart at walking-jump reach, with white take-off edges), and cables across. The gable walls stop just under the roof's outer face, so their stepped corners stay hidden in the shell. The vault's look changes band by band along the hall, not segment by segment, so overlapping segments can't flicker on the end faces. |
| West and East Halls | Players spawn in the East Hall at x 45 and z 66, facing the main hall. The main hall's shape again, turned sideways and joined to either side of it at z 66, with their barrel vaults meeting the main vault on clean diagonal creases. Each has low walls to vault, crates and oil drums. The East Hall has a door in its far end wall to the test range corridor. |
| Windows | 12 glazed steel-framed windows: 4 in the main hall and 4 in each side hall, each letting in a little grey light. The glass is solid. |
| Outside | Terrain sea with its surface at 0 and a ring of rocks at least 35 studs from the building. Seen only through the windows. |
| Matchmaking booth | A market stall against the main hall's south wall, opposite the Market: scaffold frame, corrugated walls, a ragged navy and Bone awning, junk on a railed roof, cables to the walls and warm light inside. Three screens on its back wall, a `MATCHMAKING` sign and a short `PLAY` sign hung off its corner. Its prompt says "Soon" and does nothing yet. |
| Market | The same stall at the far end of the hall, with shelves of blank navy and Bone cards, a `MARKET` sign and a short `CARDS` sign. Its prompt says "Soon" and does nothing yet. |
| Test Range corridor | Flooded tiled corridor off the far end of the East Hall, with fluorescent ceiling lights and lift doors. The doors' prompt (hold 0.4s) takes you to the test room. |

Movement matters here too: low walls to vault, a catwalk to climb up to.

## Zones and travel

- Each player has a `Zone` attribute set by the server: `Outpost` or `TestRoom`. It starts as `Outpost`. A missing or unknown value counts as the Outpost, so a late attribute never allows shooting (`src/shared/Guns/Zones.luau`).
- Each zone has a spawn, and a player respawns in their current zone. A new character more than 60 studs from its zone's spawn is moved there.
- The lift doors lead to the test room. A Deep Navy terminal 9 studs from the test room's spawn, with an `OUTPOST` sign, leads back.
- Travel has a 1s cooldown. The server gives the movement check 1s of grace first, then reloads the character at the other spawn.
- You wear your own Roblox avatar in the Outpost and the game's body everywhere else. The server moves `StarterCharacter` to `ServerStorage` at startup, turns off `CharacterAutoLoads`, and puts it back in `StarterPlayer` only while loading a character outside the Outpost. It also handles respawns.
- You leave a soft glowing blur in the Outpost that only you can see: up to 24 barely visible neon copies of your whole body, one every frame at 60 fps while you move, each nudged up to 0.12 studs so their edges melt together, fading from Deep Navy to Bone over 0.22s.
- Getting below the floors or more than 320 studs out sends the player back to the spawn. The server checks every 0.25s.

## Safe zone
The camera is third person here, and the body turns to face the way it walks. That holds from the moment a character spawns.

In the Outpost, guns and cards are off:

- The client clears every combat key (fire, aim, reload, gun swaps, class and rifle keys, card keys and the test keys). Movement keys still work.
- The gun is put away, any card is put away, and the whole HUD is hidden.
- The server refuses shots, reloads and card use.

Everything works as normal in the test room.

## How it's built

- **Map:** parts and terrain, built by a server script at startup, like the test room.
- **Cables and the skylight's light shaft:** `Beam`s, which cost no parts. The shaft is a round cone of soft columns.
- **Skylight rain:** rain streaks that always stand upright, whichever way you look.
- **Sign and screen text:** the server tags parts `OutpostSign` and `OutpostScreen` with attributes (text, style, colours). The client draws them with the HUD's image fonts on a `SurfaceGui` that ignores the scene's light.
- **Lighting:** while you're in the Outpost, the client applies its preset (fog, sky, colour correction, bloom) and takes out the place's own Atmosphere, Sky, Bloom, Blur, ColorCorrection, DepthOfField and SunRays effects, including the group place's `Bloom`. In the test room it puts them back. The group place's `ColorGrading` isn't on that list, so it stays on in the Outpost; that's going by the local export in `assets/models/`, which is a `ColorGradingEffect`. The group's place uses `LightingStyle` Soft (read on 2026-11-05, recorded in `tools/build-place.luau`), and River confirmed the lamp shadows work.
- **Textures:** the drip, grime, water-streak, crack and puddle images are Fridae Studios group assets, with their ids in `src/shared/Guns/OutpostAssets.luau`. Puddles and paint are drawn on the floor rather than built from parts, so they can't flicker against it. Floor slabs are turned so their front face points up, which fixes where painted marks land.
- **Lights with shadows:** only a few cast shadows: the skylight and the middle corridor panel.

## Testing

- Lune: `zones_spec` (the Outpost blocks combat, the test room allows it, and a missing or unknown zone counts as the Outpost).
- River checks look, feel and travel in Play.

## Not built

- The Market (needs pack rolling), the Loadout button and the Credits HUD.
- Ambient sound: waits on River's hum loops.
- Blender props, seating, and matches.
