# Outpost and HUD redesign

**Status:** designed with River on 2026-11-11, not built. The agreed look is the fourth-pass mockup, `assets/preview/hud-redesign.html` (built by a throwaway script, not kept in the repo).

**Covers:** the look of the Outpost's menu buttons, its Credits and rebirth readout, the buttons on the menu pages, a striped bar under health and ammo, and a server-wide kill feed. No rules or saves change. The only server change is sending the feed.

## The idea

River supplied a pack of 112 HUD shapes (`H:\graphj\assets\hudassets\hudassets\PNG (telegram - @all4designer)`) and asked for the Outpost and HUD to be redesigned around them. Over four mockups the design settled on using very few of them: cut-corner plates for the things you click, and plain type for the things you read.

River's words along the way: "i like the nav buttons and the way you redesigned the menus", "the nav buttons need to have a solid background", "scale down the nav buttons by quite a bit", "the hud is perfect", and for Credits, take A "just get rid of the bar asset".

Success is River opening the game and seeing the mockup: the same plates, sizes and places, in the Outpost and in a match.

## Shapes used

Three shapes from the pack, each baked to white so the game can tint it:

| Pack asset | What it is | Used for |
| --- | --- | --- |
| 94 | Solid slanted plate | A menu button at rest; the back of the open one |
| 108 | The same plate as a thin outline | The outline on the open menu button |
| 91 | Solid bar with three slashes at one end | The `OUTPOST` header; the bars under health and ammo |

**Licence:** the pack's file names say it came from a Telegram channel. River needs to confirm it may be used in a published game before these are uploaded. If it can't, the three shapes are simple enough to redraw.

## Outpost

### Menu buttons

- Six plates stacked bottom left, where the menu block is now: `PLAY`, `PACKS`, `MARKET`, `LOADOUT`, `PROFILE`, `SETTINGS`, each with its number on the right.
- **Size:** each plate is about 0.109 of the unit wide and 0.022 tall, with a small gap between them. Today's rows are 0.124 by 0.032, so the whole stack is noticeably smaller.
- **At rest:** solid Bone plate, Deep Navy text.
- **Open:** Deep Navy plate with a Bone outline and Bone text.
- **Under the mouse:** the plate flips to the open colours, and the name still kicks sideways as it does now.
- **Header:** a short striped bar above the stack reading `OUTPOST` in navy.
- **What goes:** the wipe that sweeps across a row, and its glow. They are drawn as rectangles and can't follow a slanted plate. The slide-in when the menu appears stays.

### Credits and rebirths

- Top left, under the radio strip, on the same left margin. Plain type, no shape.
- Three lines: a thin `CREDITS` label; the Credits as a big number with the income (`+4.2 CR/S`) small and grey beside it; then `REBIRTH 03`.
- The Credits number uses the HUD's number font, about three quarters the size of the health number.
- The readout at the top right of the Outpost is removed. This replaces it.
- It hides with the menu buttons, as the old one did: while a card is inspected, and while a pack opens.

### Menu pages

- The Bone page, the big title and its rule stay exactly as they are.
- **Buttons get cut corners:** the top right and bottom left corners are clipped at 45 degrees. This is every `PanelKit.button`, so it reaches all six pages at once, the market's tabs included.
- The inverted look under the mouse, the dip when pressed, and the greyed-out look all stay.
- **Not changed:** the pack art on `PACKS`. The mockup drew the packs as cut-corner blocks only as placeholders.

## Match HUD

- Health, shield, ammo, the gun's name, the card fan, the crosshair and the hit marker stay where and how they are. The mockup's match screen is today's HUD.
- **One addition:** a short striped bar under the health number and a mirrored one under the ammo number, in Bone.

### Kill feed

River, 2026-11-11: "Kills server wide show up in the top right not kill streaks. just like 'player' (gun emoji) 'player' you feel me like counter strike".

- Every kill on the server shows as a line at the top right for everyone: the killer's name, a small gun icon, the victim's name. Like `MARROW (gun) KESTREL`.
- A line you are part of, as killer or victim, is brighter: Bone names on a faint Deep Navy strip. Other lines are plain grey names.
- Lines are right-aligned on the HUD's margin, newest at the bottom as in Counter-Strike, in the small label font. Each stays 6 seconds and fades. At most 5 show; a sixth pushes the oldest off.
- Bots and the test dummy are listed by their model's name, so the feed can be seen when testing alone.
- The gun icon is one drawn pistol shape for every gun. An icon per gun, and a headshot mark, are left for later.
- They show in a match and in the Outpost. An open menu page covers them.
- Your own kills still pop up beside the crosshair with what they paid, as they do now.

## How it's built

- **A tool bakes the shapes.** It reads the three pack files, writes white copies into `assets/hud/`, and they are uploaded with the group key like the other HUD images. Their ids go in one small module. The pack itself is not copied into the repo.
- **Cut-corner buttons** use two small white images made by the same tool, a filled one and an outlined one, stretched from their middles (nine-slice) so the corner stays 45 degrees at any button size. `PanelKit.button` draws these in place of its square background and border.
- **`NavButton.luau`** is rewritten around a plate image: colour flip for hover and open, the kick, and the slide-in. `OutpostMenu.client.luau` lays out the stack and header at the new sizes.
- **`IncomeLine.luau`** becomes the top-left readout, and gains the rebirth line. It already listens for the player's Credits; rebirths arrive in the same snapshot.
- **`Hud.client.luau`** gains the two bars.
- **Kill feed:** `GunServer.server.luau` already knows each kill as it applies a shot's damage. It sends the killer's and victim's names to every client on a new `KillFeed` event. A small pure module keeps the list (newest last, at most five, each for six seconds) and a new client script draws it. Nothing is taken from a client.

## Order of work

1. Bake and upload the shapes. River confirms the licence first.
2. Menu buttons and header. River checks in Play.
3. Credits and rebirths. River checks in Play.
4. Cut-corner page buttons. River checks every page in Play.
5. The two HUD bars. River checks in a match.
6. Kill feed. River checks in a match by killing the dummy; another player's kills need a second player.

## What could go wrong

- **Text fit.** `SETTINGS` and its number have to fit a plate a third narrower than today's row. If they don't at the mockup's size, the text shrinks before the plate grows.
- **Slanted ends.** A plate's slanted ends are see-through, so the clickable area is its bounding rectangle, slightly larger than what's drawn.
- **Stretched corners.** If nine-slice images blur at small sizes, small buttons fall back to a fixed-size image per height.
- **Small screens and phones** aren't designed here, as with the other menu work.

## Tests

New Lune tests cover the feed's list: adding, the cap of five, and lines expiring. The rest changes no rules, and the existing suite must still pass. The look is River's to judge in Play at each step above.
