# HUD and image fonts

**Status:** built, with the trial and free font files. The full fonts are still to come. Checked against the code on 2026-11-05.

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
| `Title` | KH Interference Bold | `A-Z 0-9 / _` | 180 |

- For the HUD styles, source sizes are about twice the size they show at on a 1080p screen. If small text looks soft or shimmers, the source size is the one number to change.
- A space isn't a glyph. Each style stores a space width, and any character a style doesn't have takes that width and draws nothing. That's what stops a bad value from erroring in the `Number` style, which has no letters.

### The pieces

| File | Does |
| --- | --- |
| `tools/export_font_atlas.py` | Run with Python and Pillow on a folder of font files. Writes one 1024 by 1024 sheet per style to `assets/hud/<style>.png` (local only, 4 pixels between glyphs) and generates `src/shared/Guns/Hud/GlyphData.luau`. Never edit `GlyphData.luau` by hand. |
| `src/shared/Guns/Hud/FontImages.luau` | One group image id per style, kept by hand, so a re-export never wipes the ids. |
| `src/shared/Guns/Hud/TypeLayout.luau` | Pure layout: `lay(text, style, size, tracking)` returns the width and the placed glyphs. Uppercases the text. Tracking goes between characters only. |
| `src/shared/Guns/Hud/HudText.luau` | Pure formatting: health, shield, ammo, gun label, ability key and cooldown segments, and the HUD's scale. |
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
| Health | Bottom left, baseline 32 from the bottom, 32 from the left | `Number` 46 | Bone |
| Shield `+40` | 8 after the health number, only while shielded | `NumberThin` 46 | Signal Acid |
| `HEALTH` | 44 above the baseline, 34 from the left | `Label` 12, tracking 3 | Bone |
| Class | Same line, 108 from the left | `Label` 12, tracking 3 | Bone |
| Ammo | Bottom right, same baseline and margin | `Number` 46 | Bone |
| Gun label `M57  /  30` | 44 above the ammo baseline, right aligned 34 from the edge | `Label` 12, tracking 3 | Bone |
| `RELOADING` | Replaces the gun label. The ammo number stays. | `LabelBold` 12, tracking 3 | Signal Acid |
| Ability rows | 3 rows above health, the first 130 above the baseline, 25 apart | See below | |

Each ability row is 220 wide, starting 34 from the left, with tracking 2 throughout:

- The key (3, 4 or 5) in `LabelBold` 12. Signal Acid when the card is ready, otherwise Bone.
- The card name, 18 from the row's left edge, in `Label` 12.
- The tier on the right edge in `Label` 10, in its tier colour: Field Green, Data Cyan or Signal Acid.
- 5 below the baseline, a cooldown bar of 10 segments, 2 tall and 2 apart. Filled segments are Bone, empty ones Deep Navy.
- An empty slot shows nothing.

Health and shield round up, so a player on 0.4 health shows 1.

**Crosshair and hit marker:** the crosshair is a 4 by 4 Bone square. A hit shows 4 Signal Acid dashes in an X around it for 0.3s. It starts 1.6 times bigger and shrinks, and a kill's marker is 1.5 times bigger. Neither is scaled with the rest of the HUD.

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
