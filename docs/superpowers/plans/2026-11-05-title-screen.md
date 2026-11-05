# Title Screen Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Show a Split Deck title screen on join, with `PLAY` leading into the game.

**Architecture:** A pure `MenuState` module holds whether the menu is open. `Input`, the only module that reads keys, returns nothing pressed while it's open, so guns, abilities and movement all stop in one place. A new client script draws the screen with the existing `TypeLabel`.

**Tech Stack:** Luau, Rojo, Lune tests, Python with Pillow for the font sheet.

**Spec:** `docs/superpowers/specs/2026-11-05-title-screen-design.md`

## Global Constraints

- Colours come from `src/shared/Guns/Palette.luau`.
- New modules go in folders Rojo already maps (`src/shared/Guns`, `src/client`).
- Never edit scripts through Studio MCP. River does all Play testing.
- Commit only when River asks. The commit steps below wait for that.
- Tests: `export PATH="$HOME/.rokit/bin:$PATH"; lune run tests/run.luau`. New specs must be listed in `tests/run.luau`.

## Review Focus

- Keys held when `PLAY` is pressed: a click on `PLAY` must not fire a shot. Task 3 keeps fire blocked until the mouse button is released.
- A character respawning: the menu must stay closed. Pinned in Task 1.
- WASD on the menu: default Roblox controls don't go through `Input`, so Task 3 disables them directly.
- A narrow or very wide window: the title and the cut must stay on screen. Task 3 redraws on resize; River checks in Play.
- The mouse in first person: it must be free on the menu and locked after. Task 3 uses a `Modal` button.

---

### Task 1: Menu state

**Files:**
- Create: `src/shared/Guns/MenuState.luau`
- Modify: `src/client/Input.luau`, `tests/run.luau`
- Test: `tests/menustate_spec.luau`

**Interfaces:**
- Produces: `MenuState.new(): State`, `MenuState.isOpen(state): boolean`, `MenuState.play(state)`, `MenuState.filter(state, keys: { [string]: boolean }): { [string]: boolean }` (a copy with every value false while open, otherwise `keys`), and `MenuState.shared: State`, the one the game uses. A new state starts open. Nothing reopens it.

- [ ] **Step 1: Write failing tests**

`starts open`; `play closes it`; `play twice stays closed`; `filter makes every key false while open`; `filter passes keys through after play`. Each test uses its own `MenuState.new()`.

- [ ] **Step 2: Run tests, expect FAIL** (module missing)
- [ ] **Step 3: Implement `MenuState`, then wrap each of `Input.read`, `Input.readGun`, `Input.readAbility` returns with `MenuState.filter(MenuState.shared, ...)`**
- [ ] **Step 4: Run tests, expect all passing**
- [ ] **Step 5: Commit when River asks**

### Task 2: Title font style

**Files:**
- Modify: `tools/export_font_atlas.py`, `src/shared/Guns/Hud/GlyphData.luau` (generated), `src/shared/Guns/Hud/FontImages.luau`, `tests/hudtext_spec.luau`
- Create: `assets/hud/Title.png`

**Interfaces:**
- Produces: text style `"Title"`, usable as `TypeLabel.new(parent, { style = "Title", ... })`.

- [ ] **Step 1: Write failing test** `has every title letter`: for each character of `SPLITDECK`, `GlyphData.Title.glyphs[character]` exists.
- [ ] **Step 2: Run, expect FAIL**
- [ ] **Step 3: Add `"Title": ("KHInterference*-Bold.otf", string.ascii_uppercase, 180)` to `STYLES` and run the exporter on River's font folder.** The path wasn't found in a quick search, so ask River for it if needed. If glyphs don't fit at 180, lower the size in steps of 10. Check with `git status` that the other sheets didn't change.
- [ ] **Step 4: Upload `assets/hud/Title.png` with the Studio upload tool and add `Title = "rbxassetid://..."` to `FontImages.luau`**
- [ ] **Step 5: Run tests, expect all passing**
- [ ] **Step 6: Commit when River asks**

### Task 3: The screen

**Files:**
- Create: `src/client/TitleScreen.client.luau`
- Modify: `src/client/Hud.client.luau`

**Interfaces:**
- Consumes: `MenuState.shared`, `MenuState.play`, `TypeLabel.new(parent, options)`, `:set(text)`, `Palette`.

- [ ] **Step 1: Build the UI**

A `ScreenGui` with `IgnoreGuiInset = true`, `ResetOnSpawn = false` and a `DisplayOrder` above the HUD. A full-screen Signal Acid frame with `ClipsDescendants = true` holds everything. The navy panel is a Deep Navy frame rotated 15.9 degrees, which gives the spec's 68% to 52% cut on a 16:9 screen; its centre sits on the cut at 60% of screen width, with its right edge on that line and enough size to pass every screen edge.

All sizes and places are from the spec's table, as shares of `AbsoluteSize.X`. Redraw on `AbsoluteSize` change. `SIZE` for `SPLIT` and `DECK` is .15 of width, in Bone and Signal Acid. `BUILD 0.4` and `2 GUNS / 3 CARDS` go top right, right aligned. The barcode is 12 thin navy frames of varied widths.

- [ ] **Step 2: Add buttons**

`PLAY` is a transparent `TextButton` with empty text over its `TypeLabel`, with `Modal = true` so the mouse is free in first person. `MouseEnter` sets it to Signal Acid with `> PLAY`; `MouseLeave` restores Bone. `LOADOUT` and `SETTINGS` are plain `TypeLabel`s at 40% opacity colour with a small `SOON` beside them, and no button.

- [ ] **Step 3: Block default controls and handle PLAY**

On start, call `require(player.PlayerScripts:WaitForChild("PlayerModule")):GetControls():Disable()`.

`PLAY`'s `Activated` calls `MenuState.play` only once the mouse button is up, then `Enable()`s the controls and destroys the `ScreenGui`. `Activated` fires on release, so no extra wait is needed; confirm in Play that no shot fires.

- [ ] **Step 4: Hide the HUD**

In the `RenderStepped` loop at `Hud.client.luau:214`, set `gui.Enabled = not MenuState.isOpen(MenuState.shared)`.

- [ ] **Step 5: Run tests and the compile check, expect all passing**
- [ ] **Step 6: River checks in Play**

Menu covers the screen, mouse free, can't move or shoot; hovering `PLAY` turns it acid; `PLAY` leaves no stray shot and locks the mouse; HUD returns; dying doesn't reopen it; the cut looks right when the window is resized.

- [ ] **Step 7: Commit when River asks**
