# The Outpost

**Status:** step 1, the place itself, is built. River confirmed the floors, textures and lamp shadows in Play on 2026-11-05. The Market, the Loadout button and the Credits HUD aren't built. Checked against the code on 2026-11-05.

**Code:** `src/server/Outpost/` builds it when the server starts: `Kit.luau` has the building helpers, `Map.luau` the layout, and `Outpost.server.luau` the zones and travel. `src/client/Outpost.client.luau` applies the lighting and draws the sign and screen text.

## Goal

The Outpost is Split Deck's hub. Players idle there to earn Credits, buy packs and cards at the Market, and manage their loadout. PLAY lands players on its dock. The test room stays, reached through a door in the Outpost.

Reference board: River's Pinterest board "the-outpost", downloaded to `H:\outpost inspiration\aprilfridaethe-outpost` (6 images, not in the repo).

## Decisions from River

- Amber is for world lights only. Signs and screens use the palette (`Palette.luau`).
- The Market kiosk is the only booth. Its sign is Hazard Red, because red is for threats and purchases.
- Loadout and Credits will be HUD or GUI features, not places.
- Rain around the camera was tried and removed, because the drops passing the camera looked wrong.

## Look

A concrete sea outpost on a rock, in thick fog.

- **Fog:** dense teal-grey. Distant shapes fade out within a few hundred studs.
- **Light:** cold, washed-out daylight, with warm amber lamps, bulbs and doorways as the main warm light.
- **Surfaces:** weathered concrete, rusted orange steel, cracked tile and wet ground. Each floor is one smooth slab with grime, hairline cracks and (on wet floors) puddles drawn over it at a large scale, so nothing visibly repeats. Worn paint: Bone walkway dashes from the dock to the hall, Signal Acid hazard bands, a Signal Acid box around the screen tower, a Hazard Red queue box at the Market, drains, covers and oil stains. Walls are cut into panels with grime and water-streak overlays, mixed with plaster.
- **Detail:** cables strung overhead, a catwalk, stairs, antennas and dishes.
- **Weather:** drips under the hall's skylight and low mist over the water at 3 spots.
- Roblox has no screen-space reflections, so puddles look wet and shiny but don't mirror the signs.

## Layout

The Outpost is built at (4000, 0, 0), far from the test room at the world's origin. Positions here are local to that point. Local +Z runs from the dock toward the hall. Sea level is 0, the pier's top is 4 and the main deck is 6.

| Area | What's there |
| --- | --- |
| Dock (spawn) | Concrete pier on pillars, amber lamp posts, railings. Players spawn at its far end, at x 0 and z -104, facing the Outpost. A ramp joins it to the yard. |
| Gantry | 4 rusted orange steel frames over the end of the dock, with cables and a `DOCK 3` lightbox sign. |
| Yard | Open deck with parapets low enough to vault, crates, oil drums and a power cable. The screen tower in the middle has a big screen head: the front shows SPLIT DECK, and the west side shows your Deck Power Rating (`DPR`, the number in Data Cyan, `DECK POWER`). |
| Market Hall | Barrel-vaulted concrete hall with an `OUTPOST 07` sign over the entrance, a skylight, a catwalk along the east wall with stairs, and cables across. |
| Market | Kiosk at the far end of the hall under a red `MARKET` sign, with shelves of tier-coloured cards. Its prompt says "Soon" and does nothing yet. |
| Test Range corridor | Flooded tiled corridor off the hall's east side, with fluorescent ceiling lights, a `TEST RANGE >` sign and lift doors. The doors' prompt (hold 0.4s) takes you to the test room. |
| Comms tower | Stacked block tower with lit windows, AC units, antenna masts and dishes. Backdrop only. |
| Bunker | Concrete block standing in the water by the dock, with a glowing door, a `07` sign, a ladder and small lights. Backdrop only. |

Movement matters here too: parapets to vault, a catwalk to climb, stairs and ramps to slide down.

## Zones and travel

- Each player has a `Zone` attribute set by the server: `Outpost` or `TestRoom`. It starts as `Outpost`. A missing or unknown value counts as the Outpost, so a late attribute never allows shooting (`src/shared/Guns/Zones.luau`).
- Each zone has a spawn, and a player respawns in their current zone. A new character more than 60 studs from its zone's spawn is moved there.
- The lift doors lead to the test room. A Deep Navy terminal 9 studs from the test room's spawn, with an `OUTPOST` sign, leads back.
- Travel has a 1s cooldown. The server gives the movement check 1s of grace first, then moves the player to the other spawn.
- Falling into the sea or going more than 320 studs out sends the player back to the dock. The server checks every 0.25s.

## Safe zone

In the Outpost, guns and cards are off:

- The client clears every combat key (fire, aim, reload, gun swaps, class and rifle keys, card keys and the test keys). Movement keys still work.
- The gun is put away, any card is put away, and the whole HUD is hidden.
- The server refuses shots, reloads and card use.

Everything works as normal in the test room.

## How it's built

- **Map:** parts and terrain, built by a server script at startup, like the test room.
- **Sea and rock:** terrain water, with basalt, rock and slate boulders. The sea and the island's rock are filled voxel by voxel, so their surfaces are exact. The island's rock stops at sea level, and the floors are solid concrete down to it, because terrain blurs a filled block's edge by up to half a voxel. Boulders near the built areas are sunk so they never come up through a floor (`KEEP_CLEAR` in `Map.luau`).
- **Cables and the skylight's light shaft:** `Beam`s, which cost no parts.
- **Sign and screen text:** the server tags parts `OutpostSign` and `OutpostScreen` with attributes (text, style, colours). The client draws them with the HUD's image fonts on a `SurfaceGui` that ignores the scene's light.
- **Lighting:** while you're in the Outpost, the client applies its preset (fog, sky, colour correction, bloom) and takes out the place's own Atmosphere, Sky, Bloom, Blur, ColorCorrection, DepthOfField and SunRays effects, including the group place's `Bloom`. In the test room it puts them back. The group place's `ColorGrading` isn't on that list, so it stays on in the Outpost; that's going by the local export in `assets/models/`, which is a `ColorGradingEffect`. The group's place uses `LightingStyle` Soft (read on 2026-11-05, recorded in `tools/build-place.luau`), and River confirmed the lamp shadows work.
- **Textures:** the drip, grime, water-streak, crack and puddle images are Fridae Studios group assets, with their ids in `src/shared/Guns/OutpostAssets.luau`. Puddles and paint are drawn on the floor rather than built from parts, so they can't flicker against it. Floor slabs are turned so their front face points up, which fixes where painted marks land.
- **Lights with shadows:** only a few cast shadows: the middle dock lamp, one yard lamp, the skylight, the middle corridor panel and the bunker door.

## Testing

- Lune: `zones_spec` (the Outpost blocks combat, the test room allows it, and a missing or unknown zone counts as the Outpost).
- River checks look, feel and travel in Play.

## Not built

- The Market (needs pack rolling), the Loadout button and the Credits HUD.
- Ambient sound: waits on River's rain, sea and hum loops.
- Blender props, seating, and matches.
