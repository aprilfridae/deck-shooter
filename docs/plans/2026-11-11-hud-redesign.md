# Outpost and HUD Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the Outpost menu, its Credits readout, the page buttons and the match HUD look like the fourth-pass mockup, and show every kill on the server in a feed at the top right.

**Architecture:** A Python tool bakes three shapes from River's pack plus two cut-corner button images to white PNGs, which are uploaded and tinted in game. `NavButton`, `IncomeLine`, `PanelKit.button` and `Hud.client` are restyled in place. The kill feed adds one pure module, one server event and one client script.

**Tech Stack:** Luau, Rojo, Lune tests, Python with Pillow for the bake, `tools/upload-group-assets.py` for uploads.

**Spec:** `docs/specs/hud-redesign.md`

## Global Constraints

- River does all Play testing. Never start or stop Play through tools. Never edit scripts through Studio; Rojo syncs from the repo.
- Never commit `assets/`, place files or keys. Upload only with the group key in `ROBLOX_GROUP_API_KEY`; never print it.
- Colours come from `Palette`: Bone, DeepNavy, SignalAcid. Sizes are shares of `MenuPanel.unit()` in the Outpost and the HUD's own 720-tall units in a match.
- After every task: `lune run "$TEMP/sd/compile.luau" | tail -1`, `globals.luau`, `consts.luau` all report 0, and `lune run tests/run.luau | grep -E "^FAIL|expected|passed"` reports 0 failed.
- Do not upload anything until River confirms the pack's licence (Task 1, step 1).
- Each look task ends with River checking in Play before the next starts.

## Review Focus

- A burst of kills (a collateral, or many players at once): the feed must cap at five and never grow. Tested in Task 6.
- A very long or odd display name must not push the feed off the screen. `clean` cuts it; tested in Task 6.
- A player who leaves right after a kill: the client shows the names it was sent and never looks the player up.
- Menu rebuilt on a window resize: plates, header and readout must rebuild at the new size without leaving old ones behind. River checks by resizing in Task 2 and 3.
- Disabled page buttons must still look greyed and not react. River checks `SOON` on `PACKS` in Task 4.

---

### Task 1: Bake and upload the shapes

**Files:**
- Create: `tools/make-hud-shapes.py`
- Create: `src/shared/Guns/Hud/HudShapes.luau`
- Output (not committed): `assets/hud/shapes/*.png`

**Interfaces:**
- Produces: `HudShapes.Plate`, `HudShapes.PlateOutline`, `HudShapes.Stripe`, `HudShapes.CutFill`, `HudShapes.CutOutline` (each a `rbxassetid://` string); `HudShapes.CUT = 24` (the cut's size in image pixels) and `HudShapes.CUT_SLICE = Rect.new(28, 28, 36, 36)` for the 64 by 64 cut images; `HudShapes.PLATE_RATIO = 966 / 316`, `HudShapes.STRIPE_RATIO = 1826 / 199`.

- [ ] **Step 1:** Ask River to confirm the pack may be used in a published game. Stop here until they do.
- [ ] **Step 2:** Write `tools/make-hud-shapes.py <pack folder>`. It writes white-on-clear copies of pack assets 94 (`Plate.png`), 108 (`PlateOutline.png`) and 91 (`Stripe.png`) at 512 wide, keeping each alpha. It draws `CutFill.png` and `CutOutline.png` at 64 by 64: a square with the top right and bottom left corners cut 24 pixels at 45 degrees, filled, and as a 2 pixel outline.
- [ ] **Step 3:** Run it. Expected: five files in `assets/hud/shapes/`, each opening as a white shape on a clear background.
- [ ] **Step 4:** Upload the five with `tools/upload-group-assets.py`, as the font sheets were. Put the ids in `HudShapes.luau`.
- [ ] **Step 5:** Run the checks. Commit the tool and the module only.

### Task 2: Menu buttons

**Files:**
- Modify: `src/client/NavButton.luau` (rewrite the drawing; keep `new`, `step`, `setActive`, `enter`, `destroy`)
- Modify: `src/client/OutpostMenu.client.luau` (the `NAV_*` constants and `buildNav`)

**Interfaces:**
- Consumes: `HudShapes.Plate`, `HudShapes.PlateOutline`, `HudShapes.Stripe`.
- Produces: `NavButton.new(options)` with the same options plus `gap: number`; the methods `OutpostMenu` already calls keep their names.

- [ ] **Step 1:** In `OutpostMenu.client.luau` set `NAV_WIDTH = 0.109`, `NAV_ROW = 0.022`, a new `NAV_GAP = 0.0025`, `NAV_TEXT = 0.0095`, and a header `NAV_HEAD = 0.012`. Remove the Bone block's background and outline: the stack is now separate plates on a clear holder, still anchored bottom left at `HUD_MARGIN`.
- [ ] **Step 2:** In `buildNav`, draw the header: an `ImageLabel` of `HudShapes.Stripe` in Bone, `NAV_WIDTH` wide, above the first plate, with `OUTPOST` in `LabelBold`, DeepNavy.
- [ ] **Step 3:** Rewrite `NavButton` drawing. Each row is a clear `TextButton` holding a `Plate` image and a `PlateOutline` image. At rest: plate Bone, outline hidden, text DeepNavy. Hovered or active: plate DeepNavy, outline Bone and shown, text Bone. Delete the wipe, glow, halo, smear and rule code and their constants. Keep the name's sideways kick on hover and the staggered slide-in of `enter` (ghost frames go; the plate itself slides).
- [ ] **Step 4:** Run the checks. Expected: 0 errors, 0 undeclared, tests pass.
- [ ] **Step 5:** Commit. River checks in Play: six small solid plates, header, hover flip, open page's plate stays navy, resize rebuilds cleanly.

### Task 3: Credits and rebirths

**Files:**
- Modify: `src/client/IncomeLine.luau`
- Modify: `src/client/RadioHud.luau` only to read where the strip ends, if a constant must be shared

**Interfaces:**
- Consumes: `CardData.get()` snapshot fields `credits`, `ratePerSecond`, `rebirths`; `PackText.credits`, `PackText.income`.
- Produces: `IncomeLine.new(parent): Frame`, unchanged for `OutpostMenu`.

- [ ] **Step 1:** Move the readout to the left: `HUD_MARGIN` pixels in, starting under the radio strip (the strip is 48 tall at 14 from the top on a 1080 screen, so start at 0.07 of the unit). Three lines: `CREDITS` in `Label`; the Credits in `Number` at 0.027 of the unit with the income in `Label`, grey `Color3.fromRGB(170, 176, 182)`, to its right; then `REBIRTH` and the count zero-padded to two digits in `LabelBold`.
- [ ] **Step 2:** The income label's position follows the number's width on every redraw.
- [ ] **Step 3:** Update the file's header comment: it is no longer top right.
- [ ] **Step 4:** Run the checks. Commit. River checks in Play: readout under the radio, nothing top right, hides while inspecting a card and while a pack opens.

### Task 4: Cut-corner page buttons

**Files:**
- Modify: `src/client/PanelKit.luau` (`PanelKit.button`)
- Modify: `src/client/MarketPanel.luau` only if its text boxes need a matching edge (they stay square unless River asks)

**Interfaces:**
- Consumes: `HudShapes.CutFill`, `HudShapes.CutOutline`, `HudShapes.CUT_SLICE`.
- Produces: `PanelKit.button(...)` with the same arguments and return.

- [ ] **Step 1:** In `PanelKit.button`, make the `TextButton` itself clear and remove its `UIStroke`. Add two nine-slice `ImageLabel`s filling it: `CutFill` for the background and `CutOutline` for the border, both `ScaleType = Slice`, `SliceCenter = CUT_SLICE`, with `SliceScale` chosen so the cut is a third of the button's height and never more than 0.006 of the unit.
- [ ] **Step 2:** Map the existing states onto them: rest is fill PAPER and outline INK; filled or hovered is fill INK; `quiet` thickens by showing a second outline inset one pixel; `disabled` is fill INK at 0.9 transparency and outline at 0.7, with clicks off as now.
- [ ] **Step 3:** Run the checks. Commit. River checks every page in Play: `PACKS` (including a `SOON` button), `MARKET` tabs and sorts, `LOADOUT`, `PROFILE`, `SETTINGS`, and the bid box.

### Task 5: HUD bars

**Files:**
- Modify: `src/client/Hud.client.luau`

**Interfaces:**
- Consumes: `HudShapes.Stripe`, `HudShapes.STRIPE_RATIO`.

- [ ] **Step 1:** Add two `ImageLabel`s in Bone, 150 wide in the HUD's units: one with its left edge on `MARGIN` under the health number, one mirrored (`Size` X negative is not allowed, so flip with `ImageRectOffset` and `ImageRectSize`) with its right edge on the right margin under the ammo number. Raise `BASELINE` and everything hung from it by the bar's height plus a 6 unit gap so nothing overlaps.
- [ ] **Step 2:** Run the checks. Commit. River checks in a match: bars under both numbers, cards and labels not crowded.

### Task 6: Kill feed

**Files:**
- Create: `src/shared/Guns/Hud/KillFeed.luau`
- Create: `tests/killfeed_spec.luau` (add to both lists in `tests/run.luau`)
- Modify: `src/server/GunServer.server.luau`
- Modify: `tools/make-hud-shapes.py` and `HudShapes.luau` (one more image, `Gun`)
- Create: `src/client/KillFeed.client.luau`

**Interfaces:**
- Produces: `KillFeed.MAX = 5`, `KillFeed.SECONDS = 6`, `KillFeed.FADE = 0.4`; `KillFeed.push(list, entry, now)` appends `{ killer, victim, mine, at }` and drops the oldest past `MAX`; `KillFeed.prune(list, now)` removes entries older than `SECONDS + FADE` and returns whether any went; `KillFeed.fade(entry, now): number` is 0 while shown, rising to 1 over `FADE`; `KillFeed.clean(name: any): string?` returns an upper-case name cut to 20 characters, or nil if it isn't a non-empty string. RemoteEvent `KillFeed` fired to all clients as `(killerUserId: number, killerName: string, victimUserId: number, victimName: string)`, with 0 for a victim that isn't a player.

- [ ] **Step 1: Write the failing tests** in `tests/killfeed_spec.luau`:
  - `push` on an empty list gives one entry with the names it was given.
  - Six pushes leave five, and the first one pushed is gone.
  - `prune` at `SECONDS + FADE + 0.1` after a push empties the list and returns true; at `SECONDS - 1` it leaves it and returns false.
  - `fade` is 0 at `SECONDS - 1`, 0.5 at `SECONDS + FADE / 2`, 1 at `SECONDS + FADE`.
  - `clean("marrow")` is `"MARROW"`; a 30-letter name comes back 20 long; `clean("")`, `clean(5)` and `clean(nil)` are nil.
- [ ] **Step 2:** Run the tests. Expected: the new file fails because the module doesn't exist.
- [ ] **Step 3:** Implement `KillFeed.luau`.
- [ ] **Step 4:** Run the tests. Expected: all pass.
- [ ] **Step 5:** In `GunServer.server.luau`, create the `KillFeed` remote beside `KillReward`. Where a target is killed, `FireAllClients(player.UserId, player.DisplayName, victimUserId, victimName)`: a player victim's `UserId` and `DisplayName`, otherwise 0 and the model's `Name`. Clients send nothing on it.
- [ ] **Step 6:** Add a drawn pistol silhouette, `Gun.png` at 96 by 64, to the bake tool; upload it; add `HudShapes.Gun`.
- [ ] **Step 7:** Write `KillFeed.client.luau`: its own `ScreenGui` above the HUD and below the menu page. Each line is right-aligned on a 32 pixel margin from the top right, in `Label` size 12 of the HUD's units: killer, the gun icon, victim. `mine` is true when either id is the local player's: those lines draw Bone on a Deep Navy strip at 0.5 transparency; others draw grey `Color3.fromRGB(170, 176, 182)` with no strip. Newest at the bottom. Names go through `KillFeed.clean`; a call with a bad name is ignored. Redraw on a new line and when `prune` reports a change; fade with `KillFeed.fade`.
- [ ] **Step 8:** Run the checks. Commit. River checks in a match by killing the dummy; another player's kills need a second player.

### Task 7: Docs, review, PR

- [ ] **Step 1:** Update `docs/specs/hud-redesign.md` status and an "as built" section; add to `docs/HANDOFF.md`; touch `docs/specs/outpost-ui.md`, `hud.md` and `kill-rewards.md` where they describe what changed.
- [ ] **Step 2:** Fresh review of the branch with the `roblox-dev:roblox-reviewer` agent. Fix what matters.
- [ ] **Step 3:** After River approves in Play: PR into main, merge on River's word, release build.
