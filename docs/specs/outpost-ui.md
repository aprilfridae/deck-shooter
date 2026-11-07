# Outpost UI

**Status:** all four stages are built, and River approved them in Play on 2026-11-06. Comments haven't been tested with two players or on a live server. Layout and mockups approved by River on 2026-11-06.

**Values will live in:** the constants at the top of each panel's script, and `src/shared/CardCore/Settings.luau` for setting ranges. Colours come from `src/shared/Guns/Palette.luau`.

## Goal

A menu for the Outpost, styled like a Swiss poster. It gives players four things without leaving the hub: start a match, change their loadout, see a profile, and change settings. Players can keep walking while it's open, so the Outpost stays a place to hang out.

## Style

Taken from River's poster references.

- One huge word or number leads each panel, with small labels around it.
- Thin rules and strict columns, with small blocks of data in the corners.
- One loud block per panel. Barcodes, tick marks and simple circles and squares are the decoration.
- **Colour:** Bone is the paper, Deep Navy is the ink, and whatever is selected or under the mouse inverts to Deep Navy with Bone text. A solid Deep Navy block is the loud element. Signal Acid and Data Cyan are kept off the menus and HUD; Signal Acid is reserved for later. Cards are blank for now, with no tier colours, until River's custom card art is made. Hazard Red stays for threats and purchases.
- **Truth:** every number on a panel is real, or the panel leaves it out. No made-up serials or stats, as on the title screen.
- **Motion:** panels move at the full frame rate and feel heavy. Opening takes 0.5s and closing 0.3s, on the same curve: the panel goes at full speed straight away, swings a little past its mark and settles. Roblox UI has no blur, so each frame leaves eight fading copies of the panel, stretching back past the last frame, like the smear on the guns. The nav's wipes and its rows sliding in leave the same copies. The copies are gone once the panel stops. Closing, the blur, copies and glow fade from 15% of the way through and are gone by 40%, so the panel leaves clean.

## Layout

Sizes use the title screen's **unit**: the screen's width, or 16/9 of its height on wider screens.

| Item | Place |
| --- | --- |
| Nav | Bottom left, 3% from the edge: `PLAY`, `LOADOUT`, `PROFILE`, `SETTINGS` stacked, each with its number. The rows are Bone with Deep Navy text, like the panels. Under the mouse a Deep Navy wipe crosses the row in 40 fps steps with fading Deep Navy copies behind it and a Deep Navy glow ahead that spills past the row, the name kicks right and the number becomes `>`. A thin Bone outline runs round the whole nav. The open page's row wipes Deep Navy. Rows slide in one after another when the nav appears. |
| Panel | Right half of the screen, full height, Bone. |

- The nav and panels show only in the `Outpost` zone, after the title screen. Leaving the zone closes the panel.
- One panel is open at a time. Clicking another button swaps it, and clicking the open button closes it.
- WASD, jump, sprint and crouch keep working while a panel is open. The mouse works the panel.
- Opening a panel moves the centre of the view left over the same 0.5s at the full frame rate, not in steps. It eases in over the first quarter of the move and then follows the sheet, swing and all, so the character sits a quarter of the way across the screen, beside the panel, with no stretching. The camera itself doesn't move: its CFrame is sheared and scaled to 0.75 for each frame drawn, because Roblox straightens a larger shear at a limit that depends on where the camera faces, then put back so controls read the true camera. Closing moves it back the same way over 0.3s. While it moves, the 3D view blurs and leans with the speed of each frame, and the panel and interface stay sharp. The world blooms with the same speed. The panel's left edge glows Deep Navy. A closing panel sways the view gently for 0.4s in a smooth wave that swells and dies away, not in steps, starting 35% of the way through the close, when the panel is nearly gone.
- Typing in a text box stops movement, as `Input.luau` already does.

## Panels

### Play

`PLAY` in full size, then the launch queues from `matches.md`: Elimination 1V1, 2V2 and 3V3, and Tower 5V5. Each says `SOON` and does nothing until matches exist. Under the mouse a row opens downward smoothly, pushing the rows below it, and two lines of small `Label` text saying how the queue plays decode in from left to right at 20 fps, with a front of random characters ahead of the settled text. Its tick grows to run alongside them. Only one row is open at a time, and its text clears as soon as the mouse leaves.

### Loadout

- `LOAD OUT`, with the player's real Deck Power Rating in the navy block beside the card slots.
- Three card slots shaped like playing cards, each with its number, name and tier. Clicking a slot lists the owned cards and tiers. Choosing one calls the existing `SetDeck`. A deck can't hold the same card twice, so cards already in the deck are greyed out.
- Class sits below the slots, with the guns it gives, and a rifle choice shows if the class has more than one. Changing them sends the same loadout message as the B and N test keys, and follows the same rule for when the change applies.
- A deck change reaches abilities on the next respawn, as `cards.md` says, so the panel shows `NEXT RESPAWN` after a change until then.

### Profile

- Roblox headshot, name, Credits and DPR, then two tabs: `CARD INDEX` and `COMMENTS`.
- **Card index:** a grid of playing card shapes, one for every card at every tier, 4 cards by 3 tiers for now. Owned ones show their copy count in full ink, and the rest are ghosted. A large `04/12` shows how many are owned.
- **Other players:** left clicking a player in the Outpost, the player included, opens this page for them, within 40 studs. The click uses the cursor, or the screen's centre if the mouse is locked. Fusion and any other editing stay out of Profile.
- The server sends another player's public data on request, through a new `GetProfile` function. Only players in the same server can be viewed.

### Comments

- Each player can leave one comment on a profile, up to 140 characters, and can edit it. A profile keeps the 50 newest. Players can't comment on their own profile.
- The owner can delete any comment on their page, and can turn comments off for everyone.
- Anyone can report a comment. A report saves the comment, its author and the reporter for River to review.
- Text goes through `TextService` when it's posted and again each time it's shown, for the player reading it. The filter only takes players on the server and an author may have left, so the save holds the text filtered for everyone, and it's filtered again with the reader as the sender. If filtering fails, the comment isn't posted or isn't shown. Players whose accounts can't chat can't post.
- Comments are stored in their own DataStore, `ProfileComments_v1`, by the profile owner's user ID. Reports go in `ProfileCommentReports_v1`. In Studio without API access, comments last until Play stops and reports aren't saved. ProfileStore locks each save to its owner's session, so another player's save can't be written from here.
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
