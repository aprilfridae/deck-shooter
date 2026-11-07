# Outpost UI Stage 1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the Outpost's nav buttons, the sliding side panel with stepped motion and motion blur, and a working Settings panel saved to the player's profile.

**Architecture:** Pure rules live in shared modules with Lune tests: `CardCore/Settings.luau` and `Guns/Hud/PanelMotion.luau`. On the client, `PlayerSettings.luau` holds the live settings, `MenuPanel.luau` draws one panel, `SettingsPanel.luau` fills it, and `OutpostMenu.client.luau` owns the nav. `Input.luau` stays the only module that reads keys.

**Tech Stack:** Luau, Rojo, Lune tests, ProfileStore, Python font export.

**Spec:** `docs/specs/outpost-ui.md`

## Before starting

The Outpost roof, spawn and skylight work on `feature/outpost-tower` should be merged first, through the steps in `AGENTS.md`. Then branch `feature/outpost-ui` from `main`. The spec and this plan are committed on `feature/outpost-tower`, so they arrive with it.

Run everything from `H:\SplitDeck`, with `export PATH="$HOME/.rokit/bin:$PATH"`. Tests: `lune run tests/run.luau`. New `*_spec.luau` files must be listed in `tests/run.luau`, in the table and the require line. Never edit scripts through Studio MCP, and never start Play: River does all Play testing.

## Global Constraints

- Colours come from `Palette.luau`: Bone paper, Deep Navy ink, one Signal Acid block. No Hazard Red in this stage.
- All on-screen text uses `TypeLabel`. It has no `%` glyph, so volumes show as `0` to `100`.
- Sizes use the title screen's unit: screen width, or 16/9 of the height on wider screens.
- The nav and panels show only in the `Outpost` zone, after the title screen.
- Panels slide at 12 frames a second with fading copies between held frames.
- Ranges: volumes 0 to 1 (shown 0 to 100), default 1. Mouse sensitivity 0.1 to 3, default 1. Longscope sensitivity 0.1 to 2, default 1. Field of view 60 to 100, default 80.
- The repo is code only. Sheets stay in `assets/`, uploaded to the group.
- A change to a behaviour or number updates its spec in the same pull request.

## Review Focus

1. Binding a key that's already in use: the two actions swap, so nothing is left unbound.
2. A save with a corrupt `settings` field: bad values take their defaults, and the player still loads.
3. An old version 2 save: gains default settings and keeps everything else.
4. Dragging a slider quickly: only one `SetSettings` a second goes out, and the last value always arrives.
5. Leaving the Outpost with a panel open: the panel closes, and the nav is gone in the test room.

---

### Task 1: Fuller font sheets

**Files:**
- Modify: `tools/export_font_atlas.py:18-29`
- Modify: `src/shared/Guns/Hud/GlyphData.luau` (generated)
- Modify: `src/shared/Guns/Hud/FontImages.luau`
- Modify: `docs/specs/hud.md`

**Interfaces:**
- Produces: `Title` draws `A-Z 0-9 / _`. `Label` and `LabelBold` also draw `_`.

- [ ] **Step 1: Add the characters.** `Title` becomes `string.ascii_uppercase + string.digits + "/_"`, and `LABEL_CHARACTERS` gains `_`.
- [ ] **Step 2: Find the font folder.** Search River's drives for `KHInterference*-Bold.otf`. If it can't be found, stop and ask River.
- [ ] **Step 3: Export.** Run `python tools/export_font_atlas.py <font folder>`. If it stops with "Glyphs don't fit on the sheet", lower `Title`'s size from 180 to 150 and run it again. Title text is drawn at a chosen size, so the source size only affects sharpness. If a font lacks `_`, stop and report it.
- [ ] **Step 4: Upload.** Put `ROBLOX_GROUP_API_KEY` in the environment for that command only, then run `python tools/upload-group-assets.py <scratchpad>/fonts.json assets/hud/Title.png assets/hud/Label.png assets/hud/LabelBold.png`. Put the new ids in `FontImages.luau`.
- [ ] **Step 5: Update the table in `docs/specs/hud.md`** with the new characters and any new source size.
- [ ] **Step 6: Test.** `lune run tests/run.luau`. Expected: all pass.
- [ ] **Step 7: Commit** the script, `GlyphData.luau`, `FontImages.luau` and the spec.

### Task 2: Settings rules and save version 3

**Files:**
- Create: `src/shared/CardCore/Settings.luau`
- Modify: `src/shared/CardCore/SaveData.luau`
- Create: `tests/settings_spec.luau`
- Modify: `tests/savedata_spec.luau`, `tests/run.luau`
- Modify: `docs/specs/cards.md`, `docs/specs/outpost-ui.md`

**Interfaces:**
- Produces, in `Settings`:
  - `Settings.actions: { { id: string, label: string } }`, in list order: `sprint` SPRINT, `crouch` CROUCH, `crouchAlt` CROUCH 2, `jump` JUMP, `reload` RELOAD, `primary` PRIMARY, `sidearm` SIDEARM, `slot1` CARD 1, `slot2` CARD 2, `slot3` CARD 3, `fire` FIRE, `aim` AIM.
  - `Settings.new(): Settings`, with fields `music`, `game`, `menu`, `sensitivity`, `scopeSensitivity`, `fieldOfView`, `keys: { [string]: string }`.
  - `Settings.clean(raw: any): Settings`
  - `Settings.rebind(keys, action: string, keyName: string): { [string]: string }?`, returning a new table, or nil if the key can't be bound.
  - `Settings.range(field: string): (number, number)`
  - `Settings.keyLabel(keyName: string): string`
- Default keys, as `Enum.KeyCode` or `Enum.UserInputType` names: `LeftShift`, `C`, `LeftControl`, `Space`, `R`, `One`, `Two`, `Three`, `Four`, `Five`, `MouseButton1`, `MouseButton2`, in the order of `Settings.actions`.
- Bindable keys: letters, `Zero` to `Nine`, `F1` to `F12`, `LeftShift`, `RightShift`, `LeftControl`, `RightControl`, `LeftAlt`, `RightAlt`, `Space`, `Tab`, `Return`, `MouseButton1`, `MouseButton2`. Not bindable: `W`, `A`, `S`, `D`, and the test keys `B`, `N`, `T`, `Y`.

- [ ] **Step 1: Write the failing tests** in `tests/settings_spec.luau`:

```lua
expect(Settings.new().fieldOfView).toBe(80)
expect(Settings.new().keys.sprint).toBe("LeftShift")

-- Bad values fall back one field at a time.
local clean = Settings.clean({ music = 0.5, game = "loud", fieldOfView = 500, sensitivity = 0 / 0 })
expect(clean.music).toBe(0.5)
expect(clean.game).toBe(1)
expect(clean.fieldOfView).toBe(80)
expect(clean.sensitivity).toBe(1)
expect(Settings.clean("nonsense").menu).toBe(1)

-- An unknown key takes that action's default. Duplicates reset every key.
local defaults = Settings.new().keys
expect(Settings.clean({ keys = { reload = "Banana" } }).keys.reload).toBe("R")
expect(Settings.clean({ keys = { reload = "Q", jump = "Q" } }).keys.jump).toBe(defaults.jump)
expect(Settings.clean({ keys = { reload = "Q", jump = "Q" } }).keys.reload).toBe(defaults.reload)

-- A key in use swaps, and the input isn't changed.
local swapped = Settings.rebind(defaults, "jump", "R")
expect(swapped.jump).toBe("R")
expect(swapped.reload).toBe("Space")
expect(defaults.jump).toBe("Space")

expect(Settings.rebind(defaults, "jump", "W")).toBe(nil)
expect(Settings.rebind(defaults, "jump", "B")).toBe(nil)
expect(Settings.rebind(defaults, "nothing", "Q")).toBe(nil)

expect(Settings.keyLabel("Three")).toBe("3")
expect(Settings.keyLabel("LeftShift")).toBe("L SHIFT")
expect(Settings.keyLabel("MouseButton1")).toBe("MOUSE 1")
expect(Settings.keyLabel("Q")).toBe("Q")
```

And in `tests/savedata_spec.luau`:

```lua
expect(SaveData.CURRENT_VERSION).toBe(3)
local old = SaveData.load({ version = 2, credits = 5 })
expect(old.credits).toBe(5)
expect(old.settings.fieldOfView).toBe(80)
local odd = SaveData.load({ version = 3, settings = "broken", credits = 7 })
expect(odd.credits).toBe(7)
expect(odd.settings.music).toBe(1)
```

- [ ] **Step 2: Run them.** `lune run tests/run.luau`. Expected: fails on the missing module.
- [ ] **Step 3: Implement `Settings.luau`,** and in `SaveData.luau` set `CURRENT_VERSION = 3`, add `settings` to the type and `new()`, and set `data.settings = Settings.clean(raw.settings)` in `load`. `keyLabel` maps digit names to digits, left and right modifiers to `L SHIFT`, `R CTRL` and so on, mouse buttons to `MOUSE 1` and `MOUSE 2`, and leaves the rest uppercased.
- [ ] **Step 4: Run them.** Expected: all pass.
- [ ] **Step 5: Update docs.** In `cards.md`, version 3 fields gain `settings`. In `outpost-ui.md`, change the values path to `src/shared/CardCore/Settings.luau`, add that WASD and the test keys can't be bound, add `CROUCH 2`, and show that Longscope sensitivity multiplies mouse sensitivity.
- [ ] **Step 6: Commit.**

### Task 3: Settings remotes and the client's copy

**Files:**
- Modify: `src/server/CardCore.server.luau`
- Create: `src/client/PlayerSettings.luau`

**Interfaces:**
- Consumes: `Settings.clean`, `Settings.new`.
- Produces, in `PlayerSettings`:
  - `PlayerSettings.get(): Settings`
  - `PlayerSettings.set(change: { [string]: any })`: merges, applies at once, fires `changed`, and doesn't send.
  - `PlayerSettings.send()`: sends now, or at the end of the current 1-second window.
  - `PlayerSettings.changed: RBXScriptSignal`, from a `BindableEvent`.

- [ ] **Step 1: Add two remotes** with the `remote()` wrapper in `CardCore.server.luau`. `GetSettings` returns `{ ok = true, result = data.settings }`. `SetSettings` sets `data.settings = Settings.clean(raw)` and returns `{ ok = true }`. `remote()` already answers `NotLoaded`, rate limits, and shares the 5 calls a second.
- [ ] **Step 2: Implement `PlayerSettings.luau`.** It starts with `Settings.new()`, then calls `GetSettings` in a spawned thread, retrying every second until `ok`, then cleans and applies the result. In `send()`, the last send time is kept. Inside 1 second, one delayed send is queued, and it sends the latest settings.
- [ ] **Step 3: Compile check.** `lune run "$S/compile_all.luau"` with `S` set to the scratchpad. Expected: `compiled` with no errors. Then `lune run tests/run.luau`.
- [ ] **Step 4: Commit.**

### Task 4: Settings take effect

**Files:**
- Modify: `src/client/Input.luau`
- Modify: `src/shared/Guns/Hud/HudText.luau`, `src/client/Hud.client.luau`, `tests/hudtext_spec.luau`
- Modify: `src/client/Movement.client.luau:75-90`
- Create: `src/client/SoundGroups.luau`
- Modify: `src/client/GunAudio.luau`, `src/client/TitleScreen.client.luau`
- Create: `src/client/MouseFeel.client.luau`
- Modify: `docs/specs/movement.md`, `docs/specs/guns.md`, `docs/specs/cards.md`, `docs/specs/hud.md`

**Interfaces:**
- Consumes: `PlayerSettings.get`, `PlayerSettings.changed`, `Settings.keyLabel`.
- Produces: `SoundGroups.music`, `SoundGroups.game`, `SoundGroups.menu`, each a `SoundGroup` in `SoundService`. `HudText.key(slot: number, keyName: string?): string`.

- [ ] **Step 1: Write the failing test** in `tests/hudtext_spec.luau`:

```lua
expect(HudText.key(1)).toBe("3")
expect(HudText.key(1, "Q")).toBe("Q")
expect(HudText.key(2, "LeftShift")).toBe("L SHIFT")
```

- [ ] **Step 2: Run it.** Expected: fails on the second line.
- [ ] **Step 3: Implement it.** `HudText.key` uses `Settings.keyLabel` when given a key name. `Hud.client.luau` passes `PlayerSettings.get().keys["slot" .. index]`, and redraws the key labels on `PlayerSettings.changed`.
- [ ] **Step 4: Run it.** Expected: all pass.
- [ ] **Step 5: Read keys from settings.** In `Input.luau`, add a local `pressed(keyName: string): boolean`, which uses `IsMouseButtonPressed(Enum.UserInputType[keyName])` for names starting `Mouse`, and `IsKeyDown(Enum.KeyCode[keyName])` otherwise. `crouch` checks `crouch` and `crouchAlt`. The ability `use` reads the `fire` key. `nextClass`, `nextRifle`, `testDeck` and `testTier` stay fixed.
- [ ] **Step 6: Field of view.** In `targetFieldOfView`, the aim branch stays. Every other result gains `PlayerSettings.get().fieldOfView - FIELD_OF_VIEW`.
- [ ] **Step 7: Volumes.** `SoundGroups.luau` creates the three groups and sets `Volume` from settings, now and on `changed`. Menu music goes in `music`, the select sound in `menu`, and everything in `GunAudio` in `game`.
- [ ] **Step 8: Sensitivity.** `MouseFeel.client.luau` sets `UserInputService.MouseDeltaSensitivity` to `sensitivity`, multiplied by `scopeSensitivity` while the player's `AimFov` attribute is set. It updates on `changed` and on that attribute's change. Play must confirm this moves the camera. If the slider does nothing, stop and report it.
- [ ] **Step 9: Update docs.** The key tables in `movement.md`, `guns.md` and `cards.md` say the keys are defaults, and `hud.md` says the HUD shows the bound key.
- [ ] **Step 10: Check and commit.** Compile check and `lune run tests/run.luau`. Expected: all pass.

### Task 5: Panel motion and frame

**Files:**
- Create: `src/shared/Guns/Hud/PanelMotion.luau`
- Create: `tests/panelmotion_spec.luau`
- Modify: `tests/run.luau`
- Create: `src/client/MenuPanel.luau`

**Interfaces:**
- Produces, in `PanelMotion`:
  - `PanelMotion.FPS = 12`, `PanelMotion.FRAMES = 4`, `PanelMotion.COPIES = 3`.
  - `PanelMotion.held(elapsed: number): number`: how far along, from 0 to 1, stepped to whole frames.
  - `PanelMotion.trail(from: number, to: number): { { share: number, transparency: number } }`
- Produces, in `MenuPanel`:
  - `MenuPanel.new(parent: GuiObject): MenuPanel`
  - `panel.content: Frame`, for a page to fill, cleared with `panel:clear()`.
  - `panel:open()`, `panel:close()`, `panel:isOpen(): boolean`.

- [ ] **Step 1: Write the failing tests:**

```lua
expect(PanelMotion.held(0)).toBe(0)
expect(PanelMotion.held(0.04)).toBe(0) -- within the first held frame
expect(PanelMotion.held(1 / 12)).toBe(0.25)
expect(PanelMotion.held(10)).toBe(1)

local trail = PanelMotion.trail(0, 0.5)
expect(#trail).toBe(PanelMotion.COPIES)
expect(trail[1].share > 0 and trail[1].share < 0.5).toBe(true)
expect(trail[1].transparency < trail[#trail].transparency).toBe(true) -- nearest the panel is strongest
expect(#PanelMotion.trail(1, 1)).toBe(0)
```

- [ ] **Step 2: Run them.** Expected: fails on the missing module.
- [ ] **Step 3: Implement `PanelMotion`.** `trail` spaces copies evenly between `to` and `from`, nearest first, with transparency 0.55, 0.72 and 0.87.
- [ ] **Step 4: Run them.** Expected: all pass.
- [ ] **Step 5: Implement `MenuPanel`.** A Bone frame covering the right half and clipped by a full-screen frame. The closed position is fully off the right edge. On `RenderStepped` during a move, it places the panel at `held` and holds three plain Bone frames at the `trail` positions until the next held frame. They hide when the move ends. Closing plays the same move backwards. Calling `open` during a close reverses from the current position.
- [ ] **Step 6: Check and commit.** Compile check and tests.

### Task 6: Nav and stub pages

**Files:**
- Create: `src/client/OutpostMenu.client.luau`

**Interfaces:**
- Consumes: `MenuPanel`, `SettingsPanel.fill(content: Frame)` from Task 7, `Zones`, `MenuState`, `TypeLabel`, `SoundGroups.menu`.

- [ ] **Step 1: Build the nav.** A `ScreenGui` with `ResetOnSpawn = false`, under the title screen's `DisplayOrder` of 10. A Deep Navy block 3% from the bottom left with `PLAY`, `LOADOUT`, `PROFILE` and `SETTINGS` in `LabelBold` Bone. The open page's row turns Signal Acid with Deep Navy text.
- [ ] **Step 2: Wire the pages.** Clicking a button clears the panel, fills it and opens it. Clicking the open button closes it. A click plays the menu select sound. `PLAY`, `LOADOUT` and `PROFILE` show their name in `Title` and `SOON` in `Label` until later stages.
- [ ] **Step 3: Show and hide.** The gui shows only when `Zones.of(player) == Zones.Outpost` and `MenuState.isOpen(MenuState.shared)` is false, checked every frame. When it stops showing, the panel closes and the highlight clears.
- [ ] **Step 4: Check and commit.** Compile check and tests.

### Task 7: Settings panel

**Files:**
- Create: `src/client/SettingsPanel.luau`
- Modify: `docs/specs/outpost-ui.md`, `docs/README.md`, `docs/HANDOFF.md`

**Interfaces:**
- Consumes: `PlayerSettings`, `Settings.actions`, `Settings.range`, `Settings.rebind`, `Settings.keyLabel`.
- Produces: `SettingsPanel.fill(content: Frame)`.

- [ ] **Step 1: Draw the page,** following the Settings mockup in `.superpowers/mockups/panels.html`: `SETTINGS` in `Title`, then `SOUND` with `MUSIC`, `GAME`, `MENU`, then `CONTROLS` with `SENSITIVITY`, `LONGSCOPE`, `FIELD OF VIEW`, then the Deep Navy `KEYBINDS` bar. Each row shows its current value on the right.
- [ ] **Step 2: Sliders.** Dragging calls `PlayerSettings.set` on every move. Release calls `PlayerSettings.send`. Sensitivities show one decimal place, and field of view and volumes show whole numbers.
- [ ] **Step 3: Keybinds view.** `KEYBINDS` swaps the content for one row per `Settings.actions` entry, with `BACK` and `RESET`. Clicking a row shows `PRESS A KEY`. The next `UserInputService.InputBegan`, whether or not the game processed it, calls `Settings.rebind`. A nil result keeps the old key and shows `CANT USE THAT KEY` for 1.5s. The sheet has no apostrophe. The click that starts listening doesn't count, so start listening on that click's `InputEnded`. `RESET` restores `Settings.new().keys`.
- [ ] **Step 4: Update docs.** `outpost-ui.md` status says stage 1 is built, `docs/README.md` says partly built, and `HANDOFF.md` lists it, with the Play check still to do. Delete this plan.
- [ ] **Step 5: Check and commit.** Compile check and tests. Expected: all pass.

### Task 8: River's Play check and ship

- [ ] **Step 1: Ask River to restart Play and check:** the nav after the title screen, panels sliding in choppy with blur, walking with a panel open, each slider, a key swap, the HUD showing a new card key, the nav gone in the test room, and settings still there after rejoining.
- [ ] **Step 2: Fix what River finds,** then follow `AGENTS.md`: merge `origin/main`, test, push, open and merge the pull request, and publish the place build.
