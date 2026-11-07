# Card Art in the Menus Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Show the new card art, with its motion, in the Loadout slots and the Profile card index, and rename Black-Site to Redline for players.

**Architecture:** A pure rules module decides names, rarity text and which look a card takes. A Python tool bakes the images, which become group assets listed in `CardArt.luau`. A client module, `CardFace.luau`, stacks an image and live parts into a card, and the two panels use it. Serials are a placeholder until step 3 of the spec.

**Tech Stack:** Luau, Lune tests, Python with Pillow, Roblox UI, Rojo.

**Spec:** `docs/specs/card-art.md`

## Global Constraints

- Work on `feature/card-art-menus`, and finish with the steps in `AGENTS.md`: merge `origin/main`, run tests, PR, merge, place build and release.
- Tests: `export PATH="$HOME/.rokit/bin:$PATH"; lune run tests/run.luau`. A new `*_spec.luau` is listed in `tests/run.luau` twice: the `listed` table and a require line.
- The repo is code only. Art and fonts stay in `assets/`, which git ignores. Never commit images or API keys.
- River does all Play testing. Never start Play through tools, and never edit scripts through Studio MCP.
- The `BlackSite` id doesn't change. Only the name shown changes.
- Chromatic and Redacted get their rarity text only. Their effects wait until River has seen them drawn.
- Delete this plan in the pull request that finishes the work.

## Review Focus

- A Zero-Day serial past two digits shrinks to fit (`bigSerialSize`, Task 1).
- A long rarity like `PROTOTYPE ZERO-DAY` drops the set code and doesn't collide with it (`showsSetCode`, Task 1).
- A card with no art uploaded, such as a new card, draws its plain background and doesn't error (`CardArt.base`, Task 2).
- An unowned card in the index is ghosted and never animates (`CardFace` options, Task 3, checked by River).
- Closing the panel or redrawing a page stops the motion and leaves nothing running (`CardFace.step`, Task 3, checked by River).

---

### Task 1: Card rules

**Files:**
- Create: `src/shared/CardCore/CardLook.luau`, `src/shared/Guns/Hud/CardMotion.luau`
- Test: `tests/cardlook_spec.luau`, `tests/cardmotion_spec.luau`
- Modify: `tests/run.luau`

**Interfaces:**
- Produces, in `CardLook`:
  - `monogram(cardId: string): string`
  - `tierName(tier: string): string`, giving `FIELD`, `REDLINE`, `PROTOTYPE`
  - `rarityText(tier: string, variant: string): string`
  - `showsSetCode(tier: string, variant: string): boolean`
  - `look(tier: string, variant: string): string`, giving `Field`, `Redline`, `Prototype` or `ZeroDay`
  - `serialText(serial: number?): string`
  - `bigSerialSize(text: string): number`, as a share of the 58 used for two digits
- Produces, in `CardMotion`:
  - `SHINE_TIME = 2.6`, `PULSE_TIME = 1.8`, `PING_TIME = 2`, `SCRAMBLE_TIME = 2.4`
  - `shineOffset(elapsed: number): number`, the gradient's offset, from -1 to 1 over the first 55% and held off the card for the rest
  - `pulse(elapsed: number): (number, number)`, scale from 1 to 1.14 and transparency from 0.3 to 1
  - `ping(elapsed: number): (number, number)`, radius from 7 to 30 and transparency from 0.1 to 1
  - `scramble(serial: string, elapsed: number): string`

- [ ] **Step 1: Write the failing tests**

```lua
expect(CardLook.monogram("phase_dash")).toBe("PD")
expect(CardLook.monogram("aegis_shell")).toBe("AS")
expect(CardLook.tierName("BlackSite")).toBe("REDLINE")
expect(CardLook.rarityText("Field", "Base")).toBe("FIELD")
expect(CardLook.rarityText("BlackSite", Variant.ZeroDay)).toBe("REDLINE ZERO-DAY")
expect(CardLook.rarityText("Prototype", Variant.Chromatic)).toBe("PROTOTYPE CHROMATIC")
expect(CardLook.showsSetCode("Field", "Base")).toBe(true)
expect(CardLook.showsSetCode("Prototype", Variant.ZeroDay)).toBe(false)
expect(CardLook.look("BlackSite", "Base")).toBe("Redline")
expect(CardLook.look("Field", Variant.ZeroDay)).toBe("ZeroDay")
expect(CardLook.look("Field", Variant.Redacted)).toBe("Field")
expect(CardLook.serialText(7)).toBe("07")
expect(CardLook.serialText(1284)).toBe("1284")
expect(CardLook.serialText(nil)).toBe("--")
expect(CardLook.bigSerialSize("01")).toBe(1)
expect(CardLook.bigSerialSize("1284")).toBe(0.5)
```

Every id in `Cards.ids` has a monogram of two letters, and no two match.

In `cardmotion_spec`: `shineOffset(0)` is -1, `shineOffset(SHINE_TIME * 0.55)` is 1 and stays 1 until `SHINE_TIME`, then repeats. `pulse` and `ping` start at their first values and end at their last. `scramble("01", 2)` is `"01"`, because the scramble runs only in the first 0.8s of each 2.4s, and `scramble("01", 0.1)` has the same length as `"01"`, never blank.

- [ ] **Step 2: Run them and watch them fail**

Expected: FAIL, the modules don't exist.

- [ ] **Step 3: Write `CardLook.luau` and `CardMotion.luau`**

`CardLook` uses `Variant` ids from `Variant.luau`. `showsSetCode` is false when the rarity text is over 14 characters, which is what fits beside `S01`. `bigSerialSize` is `math.min(1, 2 / #text)`. `scramble` uses `PanelMotion.decode` with the time scaled so the text finishes by 0.8s, and pads any unreached places with characters from the next frame's noise, so the length never changes.

- [ ] **Step 4: Run all tests**

Expected: `0 failed`.

- [ ] **Step 5: Commit**

### Task 2: Baked art

**Files:**
- Create: `tools/make-card-art.py`, `src/shared/CardCore/CardArt.luau`
- Test: `tests/cardart_spec.luau`
- Modify: `src/shared/Guns/Palette.luau`, `tests/run.luau`

**Interfaces:**
- Consumes: `CardLook.monogram`
- Produces: `CardArt.base(cardId: string, look: string): string?`, `CardArt.outline(cardId: string): string?`, `CardArt.STRIPES: string`
- Produces: `Palette.ZeroDayBack = Color3.fromRGB(14, 16, 24)`, and `Palette.Tiers` set to `Field = DeepNavy`, `BlackSite = HazardRed`, `Prototype = SignalAcid`. Nothing reads `Palette.Tiers` today.

- [ ] **Step 1: Write the failing test**

`CardArt.base("phase_dash", "Field")` is a string starting `rbxassetid://`. So is every card with every look. `CardArt.base("no_such_card", "Field")` is nil. `CardArt.outline("recon_pulse")` is a string.

- [ ] **Step 2: Fetch the font**

Download Jost's variable font from the `google/fonts` repo (`ofl/jost/`) into `assets/fonts/`. Its Open Font License allows commercial use. Set the weight axis to 600.

- [ ] **Step 3: Write `tools/make-card-art.py`**

Draw at 4x, 600 by 960, into `assets/cards/`:

- `{monogram}_{look}.png` for 4 monograms by 4 looks: background, rounded corners of 10 units, glow, monogram, crosshair, ticks, slashes and rule.
- `{monogram}_outline.png`: the monogram's outline only, in white, for Prototype's pulse.
- `stripes.png`: one tile of white hazard stripes, tinted in the game.

The monogram is both letters with a -0.06em gap, cropped to its ink, then stretched to the 146 by 92 box and turned 90 degrees anticlockwise, so it fills left 12 to 104, top 12 to 158 exactly. The glow is a copy blurred with `GaussianBlur(20)` under the sharp letters. Hairlines bake at 1.2 units so they survive small sizes. The colours are the spec's Rarities table.

- [ ] **Step 4: Look at the output**

Compare the 16 images with the last mockups, and send River a contact sheet with `SendUserFile` before uploading.

- [ ] **Step 5: Upload and record**

`python tools/upload-group-assets.py build/card-art.json assets/cards/*.png`, with the key in `ROBLOX_GROUP_API_KEY`. Put the ids in `CardArt.luau`.

- [ ] **Step 6: Run all tests, then commit**

Expected: `0 failed`.

### Task 3: The card face

**Files:**
- Create: `src/client/CardFace.luau`

**Interfaces:**
- Consumes: `CardLook`, `CardMotion`, `CardArt`, `Palette`, `TypeLabel`
- Produces: `CardFace.new(parent: GuiObject, options): Frame`, with options `cardId`, `tier`, `variant`, `size: UDim2`, `position: UDim2`, `serial: number?`, `corner: string?`, `ghost: boolean?`

The card's text all scales with its width, using the spec's units: `width / 150`.

- [ ] **Step 1: Write `CardFace.new`**

Bottom to top: an `ImageLabel` of `CardArt.base`, with `Palette` background and `UICorner` behind it for when art is missing; the stripes as a tiled `ImageLabel` in a clipped frame, tinted by look, except Zero-Day; the small serial or `corner` text; card name; rarity text, in Red on Redline and Cyan on Zero-Day; `S01` when `showsSetCode`; Zero-Day's big serial instead of stripes.

The small serial and big serial show `CardLook.serialText(options.serial)`. `corner` replaces the small serial when given.

`ghost` sets the image and text to the look of an unowned card, 75% transparent, and adds no moving parts.

- [ ] **Step 2: Add the motion**

- The shine and foil are `Frame`s the size of the card, with `UICorner` and a `UIGradient` rotated 70 degrees, moved through `Offset` by `CardMotion.shineOffset`. Gradients stay inside rounded corners, where a moving band wouldn't. Strength by look is 28%, 70%, 50% and 60%. Foil keys run cyan, `#0A22F5`, cyan, at 55% strength, with both ends clear.
- Prototype: `CardArt.outline` scaled about the monogram's centre by `CardMotion.pulse`, and the stripes moved one tile every 1.4s.
- Zero-Day: a ring from a `Frame` with `UICorner` and `UIStroke`, in cyan, sized by `CardMotion.ping`, and the big serial set from `CardMotion.scramble`.

- [ ] **Step 3: Add one shared step**

A single `RunService.RenderStepped` connection walks a list of live faces. A face leaves the list on `Destroying`. A face with a hidden ancestor is skipped. The connection ends when the list is empty.

- [ ] **Step 4: Compile, then commit**

Run the compile check. Expected: all files compile.

### Task 4: Using it in the panels

**Files:**
- Modify: `src/client/LoadoutPanel.luau`, `src/client/ProfilePanel.luau`, `src/shared/CardCore/CardIndex.luau`
- Test: `tests/cardindex_spec.luau`

**Interfaces:**
- Consumes: `CardFace.new`, `CardLook.tierName`
- Produces: `CardIndex.build` entries gain `variant: string`, the rarest variant owned at that tier, or `Base`.

- [ ] **Step 1: Write the failing test**

With stacks `{ ["phase_dash:Field:Base"] = 2, ["phase_dash:Field:ZeroDay"] = 1 }` (use `Inventory.key`), the Phase Dash Field entry has `count` 3 and `variant` `Variant.ZeroDay`. An unowned entry has `variant` `Variant.Base`.

- [ ] **Step 2: Run it, watch it fail, then add `variant` to `CardIndex.build`**

Walk `Variant.order` backwards, from `ZeroDay` to `Base`, and take the first with copies. With no copies, the answer is `Base`.

- [ ] **Step 3: Rebuild the Loadout slots**

`SLOT_WIDTH` becomes `0.09375`, keeping `SLOT_HEIGHT`, for the 150 by 240 shape. Each slot keeps its transparent button, with a `CardFace` inside. The name and tier labels go, and so does the slot number on the card: it moves under the card in `Label`, at `SLOT_TOP + SLOT_HEIGHT + 0.012`. Slots use the variant from `CardIndex`.

- [ ] **Step 4: Rebuild the Profile index**

`CELL_WIDTH` becomes `0.0661`. Each cell is a `CardFace` with `corner` set to `X{count}` when owned, and `ghost` when not. In Studio only (`RunService:IsStudio()`), a fourth row shows each card as Zero-Day with `corner` unset and `serial` 1, so River can see it.

- [ ] **Step 5: Use `CardLook.tierName`**

Delete `TIER_NAMES` from both panels.

- [ ] **Step 6: Run all tests and compile, then commit**

Expected: `0 failed`.

- [ ] **Step 7: River checks in Play**

Open Loadout and Profile. Check each look, the glow, the shine, the foil, text sizes in the index, and that a closed panel stops moving. Fix what River flags.

### Task 5: Docs and shipping

**Files:**
- Modify: `docs/specs/card-art.md`, `docs/specs/cards.md`, `docs/specs/outpost-ui.md`, `docs/README.md`, `docs/HANDOFF.md`
- Delete: this plan

- [ ] **Step 1: Update the specs**

`card-art.md`: status becomes partly built. `cards.md`: the tier table shows Redline and the new colours. `outpost-ui.md`: replace "Cards are blank for now" with the exception from the spec's Colour rules, and update the slot and index descriptions. `README.md` and `HANDOFF.md`: card art status.

- [ ] **Step 2: Ship**

Follow `AGENTS.md`, deleting this plan in the pull request.
