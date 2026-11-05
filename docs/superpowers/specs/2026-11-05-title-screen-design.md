# Title Screen Design

## Goal

Add a title screen for Split Deck. It shows when a player joins and leads into the game. It is a front door, not a full menu: the hub stays the game's home base, as the parent design spec describes.

"Split Deck" is the game's name from here on. The parent spec and repo still say Deck-Shooter.

## What's on screen

The mockup is `.superpowers/split-deck-title-v2.html`. Sizes below are shares of screen width, so the layout holds at any window size.

| Item | Place | Type | Colour |
|---|---|---|---|
| Background | Full screen | | Signal Acid |
| Navy panel | Left side, its right edge a diagonal from 68% along the top to 52% along the bottom | | Deep Navy |
| `SPLIT` | 5% from the left, 7% from the top | `Title` style, 15% tall | Bone |
| `DECK` | Directly under `SPLIT` | `Title` style, 15% tall | Signal Acid |
| Rule | Under the title, 40% wide | 1 pixel line | Bone, 35% opacity |
| Menu | Under the rule | `LabelBold`, spaced | See Buttons |
| Details | Top right, right aligned, 5% from the edge | `Label`, spaced | Deep Navy |
| Barcode | Bottom right, 18% wide | Thin bars | Deep Navy |

The details read `BUILD 0.4` and `2 GUNS / 3 CARDS`. They only state true facts; there is no made-up serial or stat. The title is all on the navy side, so the cut never crosses a letter.

There is no animation in this version.

## Buttons

| Button | State | Action |
|---|---|---|
| `PLAY` | Live | Starts the game |
| `LOADOUT` | Dimmed, small `SOON` label | None |
| `SETTINGS` | Dimmed, small `SOON` label | None |

`PLAY` is Bone. On hover it turns Signal Acid and gains the `>` marker. Dimmed buttons do not react. There is no click sound until River supplies one.

## Flow

1. A player joins. The title screen covers everything and the mouse is free.
2. While it shows, the character can't move, shoot, reload or use abilities, and the HUD is hidden.
3. `PLAY` hides the screen, shows the HUD, locks the mouse to first person and lets input through. Today this lands in the test room; later it will lead to the hub.

The screen shows once per join. Dying or respawning does not bring it back.

## How it's built

- **`tools/export_font_atlas.py`:** add a `Title` style using KH Interference Bold, with the letters `A-Z`. It lands in `GlyphData.luau` and `FontImages.luau` like the other styles, so the full-font swap covers it.
- **Title text:** drawn with the existing HUD text system. The title style needs a large source size so it stays sharp at 15% of screen width on big displays. If the sheet would pass 1024 by 1024, it gets its own sheet.
- **New client script for the screen:** builds the UI and handles `PLAY`.
- **The diagonal:** Roblox UI can't cut a slanted edge directly. A rotated navy frame reaching past the screen edges makes the cut, inside a clipping full-screen container.
- **Menu state:** one small shared module says whether the menu is open. Movement, guns, abilities and the HUD all read it, so there is one rule rather than four. New modules go in folders Rojo already maps.
- **Colours:** from `src/shared/Guns/Palette.luau`.

The parent spec lists Michroma and Roboto Mono. River's two fonts replaced those on the HUD and do so here too.

## Testing

- Lune tests for the menu state: input is blocked while open, allowed after `PLAY`, and respawning doesn't reopen it.
- A Lune test that the `Title` style has every letter the title needs.
- River checks look and feel in Play. This matters most for the cut at different window shapes.

## Not included

Matches, the hub, a pause menu, loadout and settings screens, animation, and renaming the Roblox place or repo.
