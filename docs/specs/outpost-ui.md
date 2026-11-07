# Outpost UI

**Status:** stage 1 is built: the nav, the panel and Settings. Play, Loadout and Profile are placeholders. Not yet checked in Play. Layout and mockups approved by River on 2026-11-06.

**Values will live in:** the constants at the top of each panel's script, and `src/shared/CardCore/Settings.luau` for setting ranges. Colours come from `src/shared/Guns/Palette.luau`.

## Goal

A menu for the Outpost, styled like a Swiss poster. It gives players four things without leaving the hub: start a match, change their loadout, see a profile, and change settings. Players can keep walking while it's open, so the Outpost stays a place to hang out.

## Style

Taken from River's poster references.

- One huge word or number leads each panel, with small labels around it.
- Thin rules and strict columns, with small blocks of data in the corners.
- One loud block per panel. Barcodes, tick marks and simple circles and squares are the decoration.
- **Colour:** Bone is the paper, Deep Navy is the ink, and Signal Acid is the loud block. Tier colours appear only on cards. Hazard Red stays for threats and purchases.
- **Truth:** every number on a panel is real, or the panel leaves it out. No made-up serials or stats, as on the title screen.
- **Motion:** panels move at 30 frames a second over 0.5s and feel heavy. Opening, a panel swings a little past its mark and settles. Closing, it pulls back a touch and then drops away. Roblox UI has no blur, so each frame leaves fading copies of the panel between it and the last frame, like the smear on the guns. The copies are gone once the panel stops.

## Layout

Sizes use the title screen's **unit**: the screen's width, or 16/9 of its height on wider screens.

| Item | Place |
| --- | --- |
| Nav | Bottom left, 3% from the edge: `PLAY`, `LOADOUT`, `PROFILE`, `SETTINGS` stacked on a Deep Navy block. The open page's button is Signal Acid. |
| Panel | Right half of the screen, full height, Bone. |

- The nav and panels show only in the `Outpost` zone, after the title screen. Leaving the zone closes the panel.
- One panel is open at a time. Clicking another button swaps it, and clicking the open button closes it.
- WASD, jump, sprint and crouch keep working while a panel is open. The mouse works the panel.
- Opening a panel moves the centre of the view left in step with the sheet, frame for frame, swing and all, so the character sits a quarter of the way across the screen, beside the panel, with no stretching. The camera itself doesn't move: its CFrame is sheared for each frame drawn, then put back so controls read the true camera. Closing moves it back the same way. While it moves, the 3D view blurs and leans with the speed of each frame, and the panel and interface stay sharp. The world blooms with the same speed. The panel's left edge glows Signal Acid. When a closing panel lands, the view shakes for 7 frames, fading out.
- Typing in a text box stops movement, as `Input.luau` already does.

## Panels

### Play

`PLAY` in full size, then the launch queues from `matches.md`: Elimination 1V1, 2V2 and 3V3, and Tower 5V5. Each says `SOON` and does nothing until matches exist.

### Loadout

- `LOAD OUT`, with the player's real Deck Power Rating in the acid block.
- Three card slots, each with its number, name and tier colour. Clicking a slot lists the owned cards and tiers. Choosing one calls the existing `SetDeck`. A deck can't hold the same card twice, so cards already in the deck are greyed out.
- Class and rifle sit below the slots, with the guns they give. Changing them sends the same loadout message as the B and N test keys, and follows the same rule for when the change applies.
- A deck change reaches abilities on the next respawn, as `cards.md` says, so the panel shows `NEXT RESPAWN` after a change until then.

### Profile

- Roblox headshot, name, Credits and DPR, then two tabs: `CARD INDEX` and `COMMENTS`.
- **Card index:** a grid of every card at every tier, 4 cards by 3 tiers for now. Owned ones show their copy count and tier colour, and the rest are ghosted. A large `04/12` shows how many are owned.
- **Other players:** left clicking a player in the Outpost opens this page for them, within 40 studs. The click uses the cursor, or the screen's centre if the mouse is locked. Fusion and any other editing stay out of Profile.
- The server sends another player's public data on request, through a new `GetProfile` function. Only players in the same server can be viewed.

### Comments

- Each player can leave one comment on a profile, up to 140 characters, and can edit it. A profile keeps the 50 newest. Players can't comment on their own profile.
- The owner can delete any comment on their page, and can turn comments off for everyone.
- Anyone can report a comment. A report saves the comment, its author and the reporter for River to review.
- Text goes through `TextService` when it's posted and again each time it's shown, for the player reading it. If filtering fails, the comment isn't posted or isn't shown. Players whose accounts can't chat can't post.
- Comments are stored in their own DataStore, `ProfileComments_v1`, by the profile owner's user ID. ProfileStore locks each save to its owner's session, so another player's save can't be written from here.
- Comments use a built-in Roblox font. The image fonts have no lowercase or full punctuation.
- Posting is limited to one comment every 10 seconds per player, and is checked on the server.

### Settings

| Setting | Range | Default |
| --- | --- | --- |
| Music, Game and Menu volume | 0 to 100% | 100% |
| Mouse sensitivity | 0.1 to 3 times | 1 |
| Longscope sensitivity | 0.1 to 2 times mouse sensitivity | 1 |
| Field of view | 60 to 100 | The current base view |
| Keybinds | Any keyboard key, or Mouse 1 and 2 | The current keys |

- Settings apply at once and save to the player's profile.
- Sprint, jump and slide widen the view as they do now, kept the same amount above the chosen base. Scoping in ignores the setting.
- `KEYBINDS` opens a list of actions, including `CROUCH 2` so C and Left Control both stay. Clicking one waits for the next key. A key already in use swaps with the other action. `RESET` restores the defaults.
- W, A, S and D can't be bound, because Roblox moves the player with them. Nor can the test keys B, N, T and Y, or `/`, which opens chat.
- Space is only a default: Roblox's own jump is switched off, and the game jumps from the player's binding.
- Keys stay in `Input.luau`, which reads them from the settings. The B, N and Studio test keys aren't listed.
- Sounds move into three new `SoundGroup`s, one per volume.

## Save data

Save version 3 adds `settings`: the volumes, sensitivities, field of view and keybinds. Loading fills a missing or bad value with its default one field at a time, as the rest of the save does. Saves also gain `commentsOff`.

A new `SetSettings` remote takes the whole settings table, and the server checks it with `Settings.luau`. It's limited to 1 call a second, and sliders send when released.

## Fonts

`Title` only has capitals, so `1V1`, `300` and `04/12` can't be drawn in it. The font export gains `0-9`, `/` and `_` for `Title`, and `_` for `Label` and `LabelBold` so names draw correctly. The new sheets are uploaded to the group, and their ids go in `FontImages.luau`. Player names are drawn in capitals.

## Build stages

Each stage is its own plan and pull request, tested by River in Play before the next starts.

1. Fonts, the nav, the panel frame and Settings, with save version 3.
2. Loadout and Play.
3. Profile, the card index and clicking a player.
4. Comments.

## Testing

Pure rules go in shared modules with Lune tests: setting ranges and repair, key swaps, card index counts, and comment rules such as length, one per player and the 50 limit. Panels and clicks are tested by River in Play.

## Not in this spec

- Working queues, which need `matches.md` built.
- Fusion, the Market and a Credits HUD.
- A tool for reading reports.
- Touch and controller support.
- Viewing players who aren't in the server.
