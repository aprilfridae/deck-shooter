# HUD Typography Design

## Goal

Replace the placeholder HUD with a clean, graphic, type-led one set in River's two fonts: KH Interference and PP Fraktion. Layout A from the mockups: small corner numbers, with thin labels sitting on them.

River has bought both fonts and is waiting on the full downloads. Until then we use the trial and free files. Swapping in the full versions must be a quick, repeatable step.

## The constraint that shapes this

Roblox cannot import font files, so `TextLabel` cannot show these fonts. We draw text from images instead: each font becomes a sheet of its letters, and a small text system places a piece of that sheet for each character.

## What's on screen

All sizes are at a 720-pixel-tall screen. The whole HUD scales with screen height (see Scaling).

| Item | Place | Type | Colour |
|---|---|---|---|
| Health number | Bottom left, baseline 32 from the bottom, 32 from the left | KH Bold 46 | White |
| Shield | Directly after the health number, `+40`, only while shielded | KH Light 46 | Green |
| `HEALTH` and class | 44 above the number's baseline | Mono Regular 12, spaced 3 | White |
| Ammo number | Bottom right, same baseline and margin | KH Bold 46 | White |
| Gun label | 44 above the ammo baseline, right aligned: `M57  /  30` | Mono Regular 12, spaced 3 | White |
| Reloading | Replaces the gun label: `RELOADING`. The ammo number stays | Mono Bold 12, spaced 3 | Green |
| Ability rows | Three rows above health, first row 130 above the baseline, 25 apart | See below | |

Each ability row is 220 wide, starting 34 from the left:

- Key number on the left: Mono Bold 12. Green when the ability is ready, otherwise white.
- Name after it, 18 from the row's left edge: Mono Regular 12, spaced 2.
- Tier on the right edge: Mono Regular 10, spaced 2.
- Under them, 5 below the baseline, a cooldown bar: 10 segments, 2 tall, 2 apart, filled white, empty dark grey (40, 40, 46).
- An empty slot shows nothing.

All text is capitals. Health and shield round up, so a player on 0.4 health shows 1. Green is (57, 255, 90).

Every character gets a dark copy behind it, offset by (1, 2), so text reads on bright floors.

The crosshair and the purple hit marker do not change. They stay at their current pixel size and are not scaled.

## Scaling

The HUD lives in one full-screen container with a `UIScale` of screen height / 720, held between 0.75 and 2. The container's size divides by the same scale, so the corners stay in the corners.

## How it's built

### `tools/export_font_atlas.py`

Run with Python and Pillow. It takes the folder holding the unpacked fonts and writes:

- `assets/hud/<style>.png`: one sheet per style, white glyphs on transparent, no bigger than 1024 by 1024, with padding between glyphs so neighbours don't bleed.
- `src/shared/Guns/Hud/GlyphData.luau`: generated, not hand edited. For each style: its source size and, for each character, where it sits on the sheet, its size, offset and advance width.

| Style | Font file | Characters | Source size |
|---|---|---|---|
| `Number` | KH Interference Bold | `0-9 / +` | 138 |
| `NumberThin` | KH Interference Light | `0-9 +` | 138 |
| `Label` | PP Fraktion Mono Regular | `A-Z 0-9 / : . - +` and space | 36 |
| `LabelBold` | PP Fraktion Mono Bold | `A-Z 0-9 / : . - +` and space | 36 |

Source sizes are twice the size each style shows at on a 1080p screen. If small labels look soft or shimmer in the game, the source size is the one number to change.

Font files stay out of the repo, since neither licence lets us pass the fonts on. Only the generated sheets are kept.

### `src/shared/Guns/Hud/FontImages.luau`

Hand-kept: one `rbxassetid://` per style. It stays separate from `GlyphData` so re-running the export never wipes the uploaded ids.

### `src/shared/Guns/Hud/TypeLayout.luau`

Pure layout, no Roblox instances, so Lune can test it.

`TypeLayout.lay(text, style, size, tracking)` returns the total width and a list of placed glyphs: position, size and the rectangle on the sheet. It uppercases the text. A character the style doesn't have takes up a space's width and draws nothing. Style `Number` has no space or letters, so this is what keeps a bad value from erroring.

### `src/shared/Guns/Hud/HudText.luau`

Pure formatting, tested in Lune: the health, shield, ammo, gun-label and ability strings, including rounding up and the reloading swap.

### `src/client/TypeLabel.luau`

A piece of text on screen. `TypeLabel.new(parent, options)` takes style, size, tracking, colour, and left or right alignment. `:set(text)` redraws only when the text changed, reusing its image pieces, since the HUD updates every frame. `:width()` lets the shield sit after the health number. `:setColor(color)` recolours it.

### `src/client/Hud.client.luau`

Keeps its current game logic: the hit remote, hurt sound, kill snap and hit marker. The drawing of health, ammo, class, shield and abilities moves to `TypeLabel` and `HudText`. `GothamBold`, the health bar and the old `label` helper go.

## Swapping in the full fonts

1. Unpack the full fonts into a folder.
2. Run the export tool on that folder.
3. Upload the new sheets and paste their ids into `FontImages.luau`.

If the full fonts have the same names and characters, nothing else changes.

## Uploading the sheets

The sheets go up as Roblox images. I'll try Studio's upload tool first. If that doesn't work, River uploads them through Studio's Asset Manager. Until the ids are in, the HUD's text draws nothing, so uploading happens before River's Play check.

## Testing

Lune:

- `TypeLayout`: width, tracking, uppercasing, unknown characters, empty text.
- `HudText`: rounding up, shield on and off, normal and reloading labels, ability strings.
- The export tool's output is sanity checked: every character listed for a style exists in `GlyphData`.

River in Play: normal play, reloading, shield, ability cooldown and ready, swapping guns, and a small and large window.

## Left out

- Low-health colour or animation.
- Number animation when values change.
- Anything outside this HUD, such as menus or a scoreboard.
- The crosshair and hit marker themselves.
