# Outpost Design (step 1: the space)

## Goal

The Outpost is Split Deck's hub. Players idle there to earn Credits, buy packs and cards at the Market, and manage their loadout. This step builds the place itself and the way in and out. The Market station is built and signed but doesn't work yet. Loadout will be a GUI button, not a room, and Credits will be on the HUD.

PLAY now drops players at the Outpost instead of the test room. The test room stays, reachable by a door in the Outpost and back by a terminal beside its spawn.

Reference board: `H:\outpost inspiration\aprilfridaethe-outpost` (River's Pinterest board "the-outpost").

## Look

A concrete sea outpost on a rock, in thick fog.

- **Fog:** dense teal-grey `Atmosphere`. Distant shapes fade out within a few hundred studs.
- **Light:** cold, washed-out daylight. Warm amber lamps, bulbs and doorways are the main warm light.
- **Surfaces:** weathered concrete, rusted orange steel, cracked tile, wet ground with puddles. Each floor is one smooth slab, so it reads as a single pour, with grime, hairline cracks and puddles drawn over it at a large scale so nothing visibly repeats, plus worn paint: walkway lines from the dock to the hall, hazard bands, a box around the screen tower, a red queue box at the Market, drains, covers and oil stains. Walls are cut into panels with grime and water-streak overlays, and mix in plaster.
- **Detail:** cables strung overhead, a catwalk, stairs, antennas and dishes.
- **Weather:** drips under the hall's skylight and low mist over the water. Rain around the camera was tried and removed, because the drops passing the camera looked wrong.

Colours: amber is for world lights only. Signs and screens use the palette in `src/shared/Guns/Palette.luau`. The Market sign is Hazard Red, because red is for threats and purchases.

Roblox has no screen-space reflections, so puddles look wet and shiny but don't mirror the signs.

## Layout

All positions are local to the Outpost origin, which sits far from the test room. Sea level is 0 and the main deck is at 6.

| Area | Reference | What's there |
|---|---|---|
| Dock (spawn) | Image 4 | Concrete pier on pillars, amber lamp posts, railings. Players spawn at its far end facing the Outpost. |
| Gantry | Image 3 | Rusted orange steel frames over the end of the dock, with cables and a lightbox sign. |
| Yard | Image 6 | Open deck with the screen tower: a column with a big screen head, lamps and cables. The front screen shows SPLIT DECK and the west side shows your Deck Power Rating. |
| Market Hall | Image 2 | Barrel-vaulted concrete hall with a skylight, a catwalk with stairs and cables across. |
| Market | Image 2 | Kiosk at the far end of the hall under a red MARKET sign, the only booth. Prompt: "Soon". |
| Test Range corridor | Image 5 | Flooded tiled corridor off the east side, fluorescent ceiling lights, a TEST RANGE sign and lift doors. The doors' prompt takes you to the test room. |
| Comms tower | Image 4 | Stacked block tower with lit windows, AC units, antenna masts and dishes. Backdrop only. |
| Bunker | Image 1 | Concrete block standing in the water by the dock, with a glowing door, ladder and small lights. Backdrop only. |

Movement still matters here: parapets to vault, a catwalk to climb, stairs and ramps to slide down.

## Zones and travel

- Each player has a `Zone` attribute set by the server: `Outpost` or `TestRoom`. It starts as `Outpost`.
- Each zone has a spawn. A player respawns in their current zone.
- Travel prompts move the player to the other zone's spawn. The server gives movement grace first, so the cheat check doesn't flag the jump.
- Falling into the sea, or going too far out, puts the player back on the dock.

## Safe zone

In the Outpost, guns and ability cards are off. The gun and cards are put away, the combat HUD is hidden, and the server refuses shots, reloads and card use. Everything works as before in the test room.

## How it's built

- **Map:** built by a server script at startup out of parts and terrain, like the test room already is. Modules go in `src/server/Outpost/`, which Rojo already maps, so no project change or Rojo restart is needed.
- **Sea and rocks:** terrain water, with basalt, rock and slate boulders. The sea and the island's rock are filled voxel by voxel, so their surfaces are exact. The island's rock stops at sea level, and the floors are solid concrete down to it, because terrain blurs a filled block's edge by up to half a voxel. Boulders near the dock, bunker, yard, hall, corridor and comms tower are sunk so they stay at least 3 studs under those floors.
- **Cables and the skylight's light shaft:** `Beam`s, which cost no parts.
- **Sign and screen text:** drawn on the client with the HUD's image fonts (`TypeLabel`), on parts tagged by the server.
- **Lighting:** a client script applies the Outpost preset (fog, sky, colour grade, bloom) while you're in the Outpost, and restores the place's own lighting in the test room.
- **Textures:** the drip streak, grime, water-streak, crack and puddle overlays are Fridae Studios group assets, with their ids in `OutpostAssets.luau`. Puddles and paint are drawn on the floor rather than built from parts, so they can't z-fight with it. Floor slabs are turned so their front face points up, which fixes where painted marks land.
- **Zones:** one small shared module says which zone allows combat. Input, the gun view, cards, the HUD and the servers all read it.

## Testing

- Lune tests for the zone rules: the Outpost blocks combat, the test room allows it, and a missing or unknown zone counts as the Outpost.
- River checks look, feel and travel in Play.

## Not included

Working Market screen, the Loadout and Credits HUD features, pack rolling, ambient sound (no rain, sea or hum sounds yet), Blender props, matches, and seating.

## Open items

- Ambient sounds: River to supply rain, sea and hum loops.
- Lighting technology: check in Studio that the place uses Future lighting, which the lamp shadows need.
