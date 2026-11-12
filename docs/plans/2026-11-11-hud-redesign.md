# Outpost and HUD Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the Outpost menu, its Credits readout, the page buttons and the match HUD look like the fourth-pass mockup, and call kill streaks out to the whole server.

**Architecture:** A Python tool bakes three shapes from River's pack plus two cut-corner button images to white PNGs, which are uploaded and tinted in game. `NavButton`, `IncomeLine`, `PanelKit.button` and `Hud.client` are restyled in place. Streak calls add one pure function, one server event and one client script.

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

- A streak reached by a shot that earns two streak lines at once (cannot happen with 3/5/10, but `streakOf` must return the highest if it did). Tested in Task 6.
- A kill that pays nothing (kill trading) must never call a streak. Tested in Task 6.
- A player who leaves mid-call: the client must show a name it was sent, never look the player up. Covered by sending the display name as text.
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

### Task 6: Streak calls

**Files:**
- Modify: `src/shared/Guns/KillRewards.luau`
- Modify: `tests/killrewards_spec.luau`
- Modify: `src/server/GunServer.server.luau`
- Create: `src/client/StreakCalls.client.luau`

**Interfaces:**
- Produces: `KillRewards.streakOf(lines: { Line }): string?` returning the streak's `name` (`"KILLING SPREE"`, `"RAMPAGE"`, `"UNSTOPPABLE"`) or nil; RemoteEvent `StreakCall` fired to all clients as `(userId: number, displayName: string, streak: string)`.

- [ ] **Step 1: Write the failing tests** in `tests/killrewards_spec.luau`:
  - `streakOf` of lines with no streak id is nil.
  - Three paying kills in a row: the third shot's lines give `"KILLING SPREE"`.
  - A streak line whose `amount` is nil gives nil.
  - Lines holding both `spree` and `rampage` give `"RAMPAGE"`.
- [ ] **Step 2:** Run `lune run tests/run.luau | grep -E "^FAIL|expected|passed"`. Expected: the new tests fail because `streakOf` is nil.
- [ ] **Step 3:** Implement `KillRewards.streakOf` from the `STREAKS` table, highest `kills` first, counting only lines with an amount.
- [ ] **Step 4:** Run the tests. Expected: all pass.
- [ ] **Step 5:** In `GunServer.server.luau`, create the `StreakCall` remote beside `KillReward`. After `forShot`, if `streakOf(lines)` is not nil, `FireAllClients(player.UserId, player.DisplayName, streak)`. Clients send nothing on it.
- [ ] **Step 6:** Write `StreakCalls.client.luau`: its own `ScreenGui` above the HUD and below the menu page. Lines right-aligned on a 32 pixel margin from the top right, newest on top, `Label` size 12 in the HUD's units: the name (or `YOU` when `userId` is the local player's) in Bone, two spaces, the streak in SignalAcid. Each stays 5 seconds then fades over 0.4; at most 4, the oldest dropped first. Ignore arguments of the wrong type and names longer than 40 characters are cut.
- [ ] **Step 7:** Run the checks. Commit. River checks in a match by getting 3 kills on bots; another player's call needs a second player.

### Task 7: Docs, review, PR

- [ ] **Step 1:** Update `docs/specs/hud-redesign.md` status and an "as built" section; add to `docs/HANDOFF.md`; touch `docs/specs/outpost-ui.md`, `hud.md` and `kill-rewards.md` where they describe what changed.
- [ ] **Step 2:** Fresh review of the branch with the `roblox-dev:roblox-reviewer` agent. Fix what matters.
- [ ] **Step 3:** After River approves in Play: PR into main, merge on River's word, release build.
