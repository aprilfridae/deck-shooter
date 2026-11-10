# HUD and image fonts

**Status:** built. River has the Pro font downloads, and `LabelLarge` is made from them. The other sheets match their old metrics, so they weren't re-uploaded. KH Interference's Pro file still names itself `KH Interference TRIAL`, which River should check. Checked against the code on 2026-11-07.

**Values live in:** the constants at the top of `src/client/Hud.client.luau`. Colours come from `src/shared/Guns/Palette.luau`.

## Goal

A clean, graphic HUD led by type, set in River's two fonts: KH Interference for numbers and PP Fraktion Mono for labels. Small corner numbers with thin labels on them (layout A from the mockups).

## Image fonts

Roblox can't import font files, so `TextLabel` can't use these fonts. Text is drawn from images instead: each font style becomes a sheet of its letters, and `TypeLabel` places a piece of the sheet for each character. The HUD, the title screen and the Outpost's signs and screens all use it.

| Style | Font | Characters | Source size |
| --- | --- | --- | --- |
| `Number` | KH Interference Bold | `0-9 / +` | 138 |
| `NumberThin` | KH Interference Light | `0-9 +` | 138 |
| `Label` | PP Fraktion Mono Regular | `A-Z 0-9 / : . - > + _` | 36 |
| `LabelBold` | PP Fraktion Mono Bold | `A-Z 0-9 / : . - > + _` | 36 |
| `LabelLarge` | PP Fraktion Mono Bold, for big text on cards | `A-Z 0-9 / : . - > + _` | 180 |
| `Title` | KH Interference Bold | `A-Z 0-9 / _` | 180 |

- For the HUD styles, source sizes are about twice the size they show at on a 1080p screen. If small text looks soft or shimmers, the source size is the one number to change.
- A space isn't a glyph. Each style stores a space width, and any character a style doesn't have takes that width and draws nothing. That's what stops a bad value from erroring in the `Number` style, which has no letters.

### The pieces

| File | Does |
| --- | --- |
| `tools/export_font_atlas.py` | Run with Python and Pillow on a folder of font files. Writes one 1024 by 1024 sheet per style to `assets/hud/<style>.png` (local only, 4 pixels between glyphs) and generates `src/shared/Guns/Hud/GlyphData.luau`. Never edit `GlyphData.luau` by hand. |
| `src/shared/Guns/Hud/FontImages.luau` | One group image id per style, kept by hand, so a re-export never wipes the ids. |
| `src/shared/Guns/Hud/TypeLayout.luau` | Pure layout: `lay(text, style, size, tracking)` returns the width and the placed glyphs. Uppercases the text. Tracking goes between characters only. |
| `src/shared/Guns/Hud/HudText.luau` | Pure formatting: health, shield, ammo, gun label, ability key and how much of a card's colour is back, and the HUD's scale. |
| `src/client/TypeLabel.luau` | Text on screen. `new(parent, options)` takes style, size, tracking, colour and left or right alignment. `:set(text)` redraws only when the text changes. Also `:width()`, `:setColor()`, `:setPosition()` and `:setVisible()`. |

- Every character has a Deep Navy shadow behind it, offset by (1, 2). `:setColor()` recolours the glyph, not the shadow.
- Glyphs sit on whole sheet pixels, so small text doesn't drift.
- The font files stay out of the repo, because neither licence lets us pass the fonts on. The sheets are Fridae Studios group assets and aren't in the repo either.

### Swapping in the full fonts

1. Unpack the full fonts into a folder.
2. Run `python tools/export_font_atlas.py <font folder>`.
3. Upload the new sheets to the group with `tools/upload-group-assets.py`, then put their ids in `FontImages.luau`.

If the full fonts have the same names and characters, nothing else changes. The file patterns (`KHInterference*-Bold.otf` and so on) match both the trial and the full file names.

## What's on screen

Sizes are in pixels on a 720-pixel-tall screen. All text is capitals.

| Item | Place | Style | Colour |
| --- | --- | --- | --- |
| Health | Bottom left, baseline 32 from the bottom, 32 from the left | `Number` 46 | Data Cyan at full, running to Hazard Red at none |
| Shield `+40` | 8 after the health number, only while shielded | `NumberThin` 46 | Bone |
| `HEALTH` | 44 above the baseline, 34 from the left | `LabelBold` 12, tracking 3 | Bone |
| Ammo | Bottom right, same baseline and margin | `Number` 46 | Data Cyan with a full magazine, running to Hazard Red at empty |
| Gun label `M57  /  30` | 44 above the ammo baseline, right aligned 34 from the edge | `LabelBold` 12, tracking 3 | Bone |
| `RELOADING` | Replaces the gun label. The ammo number stays. | `LabelBold` 12, tracking 3 | Bone |
| Card spread | The equipped cards fanned out above `HEALTH` | See below | |

The spread shows each equipped card's face, 82.5 by 132 (it was 60 by 96), drawn by `CardFace` with its name and rarity printed on it. There are no keys or bars:

- To start, slot 1 is on top, slot 2 under it and slot 3 under that. A card taken in hand glitches out of the spread and back in on top of the others, in 0.42s (`HudText.glitch`), and stays on top after. First half: it flickers lit Data Cyan and jumps up to 8 sideways, harder as it goes, while a Data Cyan and a Hazard Red copy of its shape pull up to 9 apart behind it and 3 lines of static jump about over it; then it's gone, with only the copies taking turns. Second half: it snaps back in over the others 1.2 times its size with a white flash, drops out for one more beat, and settles as the copies close up. Slot 2 stands upright in the middle, its bottom 26 above the `HEALTH` line. Slots 1 and 3 sit 34 to its left and right, lean 14 degrees outward and sit 6 lower.
- A card on cooldown is greyed out: a grey lies over it. The colour comes back evenly over the cooldown (`HudText.colour`), and is all back when the card is ready.
- The card in hand slides up 10, and back down when it's put away (most of the way in 0.07s).
- An empty slot shows nothing.

Health and shield round up, so a player on 0.4 health shows 1.

**Health and ammo colour:** each number is blended between Data Cyan and Hazard Red by how much is left (health out of 100, ammo out of the magazine), and the colour eases to its new place over about a quarter of a second instead of snapping.

**Crosshair and hit marker:** the crosshair is a Bone plus, two bars 12 long and 2 wide. A hit shows 4 Signal Acid (green) dashes in an X around it for 0.3s. It starts 1.6 times bigger and shrinks, and a kill's marker is 1.5 times bigger. Neither is scaled with the rest of the HUD.

## Scaling

The HUD sits in one full-screen frame with a `UIScale` of screen height / 720, held between 0.75 and 2. The frame's size is divided by the same scale, so the corners stay in the corners.

## When it shows

The whole HUD, crosshair included, is hidden while the title screen is open and in the Outpost, where combat is off. It shows in the test room.

## Testing

- Lune: `typelayout_spec`, `hudtext_spec` (including that the `Title` style has the letters of SPLIT DECK) and `glyphdata_spec`, which checks the characters it lists exist and that glyphs stay inside the sheet and apart. Its list leaves out the Label styles' `>` and the `Title` style.
- River in Play: normal play, reloading, the shield, ability cooldowns, swapping guns, and small and large windows.

## Not built

- A low-health colour or animation.
- Numbers animating when they change.
- A scoreboard.
