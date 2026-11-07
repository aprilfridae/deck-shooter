# Title screen

**Status:** built. River confirmed it in Play on 2026-11-05. Checked against the code on 2026-11-05.

**Values live in:** the constants at the top of `src/client/TitleScreen.client.luau`. The menu state is `src/shared/Guns/MenuState.luau` and the visualizer maths is `src/shared/Guns/MusicBars.luau`.

## Goal

A front door for Split Deck. It shows when a player joins and leads into the game. It isn't a full menu: the Outpost hub is the game's home base.

## Layout

Sizes are shares of a **unit**, which is the screen's width, or 16/9 of its height on screens wider than 16:9, so nothing runs off the bottom.

| Item | Place | Type | Colour |
| --- | --- | --- | --- |
| Background | Full screen | | Data Cyan |
| Navy panel | Left side. Its right edge is a diagonal at 15.9°, centred at 60% of the screen's width, which runs from 68% along the top to 52% along the bottom on a 16:9 screen | | Deep Navy |
| `SPLIT` | 5% from the left, baseline at 18.5% | `Title`, size 15% | Bone |
| `DECK` | Baseline at 31.5% | `Title`, size 15% | Data Cyan |
| Rule | At 34%, 40% wide | 1-pixel line, 65% transparent | Bone |
| Menu | First baseline at 37.5%, then every 3.6% | `LabelBold` 1.7%, tracking 0.4% | See Buttons |
| Details | Top right, right aligned 5% from the edge: `BUILD 0.4`, then `2 GUNS / 3 CARDS` | `Label` 1.25%, tracking 0.3% | Deep Navy |
| Visualizer | Bottom right, 30% wide and 13% tall | 36 bars of 15 segments | Deep Navy |
| Barcode | Above the visualizer, 18% wide and 4% tall | 12 bars | Deep Navy |

- The title is all on the navy side, so the cut never crosses a letter.
- The details state only true facts: no made-up serial numbers or stats. `BUILD 0.4` is typed in the script and isn't tied to anything.
- Roblox UI can't cut a slanted edge, so the cut is a big rotated navy frame inside a full-screen frame that clips it.

## Movement on screen

- **Cut parallax:** the cut follows the cursor. It slides up to 1.8% of the width sideways and leans up to 2° with the cursor's height, eased.
- **Visualizer:** driven by the music's `PlaybackLoudness`. Roblox gives that as one number, so the bars are a pattern scaled by loudness, not real frequencies.

## Buttons

| Button | State | Action |
| --- | --- | --- |
| `PLAY` | Live, Bone | Starts the game |
| `LOADOUT` | Dimmed, with a small `SOON` | None |
| `SETTINGS` | Dimmed, with a small `SOON` | None |

- Hovering `PLAY` turns it Data Cyan and shows `> PLAY`. The dimmed buttons don't react.
- `PLAY` is an invisible button with `Modal` on, which frees the mouse while the screen shows. It fires on release, so no stray shot follows.

## Sound

- The menu music (`menu-music-v2.mp3`) loops from the moment the player joins.
- Clicking `PLAY` plays the selection sound (`menu-select.wav`). River confirmed on click, not hover.
- After `PLAY` the music keeps playing, fading over 0.6s to volume 0.224 with the lows cut 12 dB and the mids 1 dB. It plays in the Outpost and the test room too.

## Flow

1. A player joins. The title screen covers everything and the mouse is free.
2. While it shows, the character can't move, shoot, reload or use cards, and the HUD is hidden. `MenuState` blocks every key read in `Input.luau`. W, A, S and D are blocked by turning off Roblox's default controls.
3. `PLAY` hides the screen, turns the controls back on and locks the mouse to first person. The player is already standing on the Outpost dock behind the screen.

The screen shows once per join. Dying or respawning doesn't bring it back.

## Testing

- Lune: `menustate_spec` (blocked while open, allowed after `PLAY`), `musicbars_spec`, and the `Title` style test in `hudtext_spec`.
- River in Play, especially the cut at different window shapes.

## Not built

The loadout and settings screens, a pause menu, and renaming the repo (`aprilfridae/deck-shooter`) and the Rojo project (`DeckShooter`), which still use the old name.
