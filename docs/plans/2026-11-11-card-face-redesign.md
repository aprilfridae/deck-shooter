# Card Face Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rebuild the front of a card around River's micrographics, with the agreed type, per-rarity effects and the rainbow look for serials 1 to 10.

**Architecture:** The front stops being one baked image. `tools/make-card-art.py` bakes white-on-clear layers from River's SVG and the two fonts; `CardFace.luau` stacks and tints them using positions from a new pure `CardLayout.luau`; motion maths lives in pure `CardMotion.luau` and the per-rarity builders in a new `CardFaceFx.luau`. The back of the card is untouched.

**Tech Stack:** Luau (Roblox, Rojo), Lune tests (`tests/run.luau`), Python 3 with Pillow and fontTools for art, Open Cloud upload through `tools/upload-group-assets.py`.

**Spec:** `docs/specs/card-face-redesign.md` (read it first; `docs/specs/card-art.md` describes what exists today).

## Global Constraints

- Work on branch `feature/smooth-arms-recoil` in `H:\SplitDeck`. Rojo is already serving; don't restart it. Never edit scripts through the Studio MCP, never start or stop Play: River does all Play testing.
- Never commit `assets/`, place files or keys. The upload key is read from the `ROBLOX_GROUP_API_KEY` environment variable only; never print or save it. If it isn't set, stop and ask River.
- Checks before every commit, from `/h/SplitDeck`: `lune run "$TEMP/sd/compile.luau" | tail -1`, `lune run "$TEMP/sd/globals.luau" | tail -1`, `lune run tests/run.luau | grep -E "^FAIL|expected|passed"`. A failing test must show; don't pipe to `tail` alone.
- Commit messages end with `Co-Authored-By: Claude Fable 5.2 <noreply@anthropic.com>`.
- Front-of-card positions are in River's SVG units: card 1280 by 2048, corner 85, margins 45 left/right/bottom and 69 top. The back keeps its 150 by 240 units.
- Colours come from `Palette` only: DeepNavy `#29324F`, Bone `#E8E6DF`, SignalAcid `#C2FE0B`, HazardRed `#FF0D1A`, DataCyan `#01FFFF`, ZeroDayBack `#0E1018`. No green anywhere else.
- Fonts: KH Interference Bold (`assets/fonts/KHInterferencePRO-Bold.otf`) for the acronym; PP Fraktion Mono Regular and Bold (`C:\Users\river\Downloads\PPFraktion-Pro\PPFraktion-Pro\Mono\`) for everything else.
- Nothing may rely on the card clipping it: the HUD tilts cards and Roblox drops clipping for rotated UI.
- Comments in code say why, in plain words, and name River and the date where a choice was theirs.

## Review Focus

1. A card id with no art yet (a new card) must still draw: background, live text, no error, no blank-image warnings.
2. Serial `nil`, `0`, negative, `10`, `11` and five digits: only 1 to 10 get the low look; `nil` shows `----`; long numbers show in full.
3. The longest rarity text (`prototype chromatic`, 19 letters) must end left of the serial.
4. A ghost (unowned) card stays faded and still: no motion, no effects, no per-frame work.
5. A very small card (the Profile index) halves embers, marks and twinkles and never asks for a zero or negative size.

Tests for 1 to 3 and 5 are in Tasks 1, 2 and 6. Number 4 is a code-review check in Task 4, since it needs Roblox instances.

---

### Task 1: Printed-text rules in `CardLook`

**Files:**
- Modify: `src/shared/CardCore/CardLook.luau`
- Test: `tests/cardlook_spec.luau`

**Interfaces:**
- Produces: `CardLook.faceName(name: string): string`, `CardLook.faceRarity(tier: string, variant: string): string`, `CardLook.faceSerial(serial: number?): string`, `CardLook.isLowSerial(serial: number?): boolean`, `CardLook.lowSerialText(serial: number): string`, `CardLook.studioSerial(cardId: string): number?`.
- `rarityText` and `showsSetCode` stay (the back uses them). `serialText` and `bigSerialSize` are removed in Task 4 when their last caller goes.

- [ ] **Step 1: Write the failing tests** in `tests/cardlook_spec.luau`:

```lua
it("prints the name in capitals with no spaces", function()
	expect(CardLook.faceName("Phase Dash")).toBe("PHASEDASH")
	expect(CardLook.faceName("Overclock")).toBe("OVERCLOCK")
end)

it("prints the rarity in lowercase, tier then variant", function()
	expect(CardLook.faceRarity("Field", "Base")).toBe("field")
	expect(CardLook.faceRarity("BlackSite", "Base")).toBe("redline")
	expect(CardLook.faceRarity("Field", Variant.ZeroDay)).toBe("field zero-day")
	expect(#CardLook.faceRarity("Prototype", Variant.Chromatic)).toBe(19) -- the longest; CardLayout checks it fits
end)

it("pads a serial to four digits and shows longer ones in full", function()
	expect(CardLook.faceSerial(42)).toBe("0042")
	expect(CardLook.faceSerial(12345)).toBe("12345")
	expect(CardLook.faceSerial(nil)).toBe("----")
end)

it("gives serials 1 to 10 the low look and no others", function()
	for _, serial in { 1, 10 } do
		expect(CardLook.isLowSerial(serial)).toBe(true)
	end
	for _, serial in { 0, -3, 11, 1000 } do
		expect(CardLook.isLowSerial(serial)).toBe(false)
	end
	expect(CardLook.isLowSerial(nil)).toBe(false)
	expect(CardLook.lowSerialText(1)).toBe("01")
	expect(CardLook.lowSerialText(10)).toBe("10")
end)

it("has a stand-in serial for each card in Studio, one of them low", function()
	expect(CardLook.studioSerial("phase_dash")).toBe(1)
	expect(CardLook.studioSerial("overclock")).toBe(7)
	expect(CardLook.studioSerial("recon_pulse")).toBe(42)
	expect(CardLook.studioSerial("aegis_shell")).toBe(117)
	expect(CardLook.studioSerial("no_such_card")).toBe(nil)
end)
```

- [ ] **Step 2: Run** `lune run tests/run.luau | grep -E "^FAIL|expected|passed"`. Expected: the five new tests fail (functions are nil).
- [ ] **Step 3: Implement the six functions.** `faceRarity` is `string.lower(CardLook.rarityText(...))`. `studioSerial` reads a small table and carries a comment: serials aren't built yet (`card-art.md` step 3), so Studio shows these to let River judge both looks; delete it when real serials land.
- [ ] **Step 4: Run the tests.** Expected: all pass, count is 645 plus the new ones.
- [ ] **Step 5: Commit** `src tests` with message "Add the printed-text rules for the new card face".

---

### Task 2: `CardLayout`, the one place positions live

**Files:**
- Create: `src/shared/CardCore/CardLayout.luau`
- Test: `tests/cardlayout_spec.luau` (add it to `tests/run.luau`'s list the way the other specs are)

**Interfaces:**
- Produces a table of constants and two functions. Rects are `{ x, y, w, h }` in SVG units.

```lua
CardLayout.WIDTH = 1280; CardLayout.HEIGHT = 2048; CardLayout.CORNER = 85
CardLayout.MARGIN = 45
CardLayout.MONOGRAM = { x = 45, y = 69, w = 645, h = 1061 }
CardLayout.RAYS = { x = 773, y = 308, w = 462, h = 172 }
CardLayout.BURST_DOT = { x = 1004.84, y = 394.13, r = 43.77 }
CardLayout.STAR_BIG = { x = 706, y = 443, w = 386, h = 386 }     -- centre (898.77, 635.67)
CardLayout.STAR_SMALL = { x = 948, y = 559, w = 154, h = 154 }   -- centre (1025.11, 635.67)
CardLayout.GLOBE = { x = 640, y = 1476, ry = 134.12, rings = { 397.11, 291.91, 192.04 } } -- outer first
CardLayout.NAME = { x = 36, y = 1800, w = 760, h = 104 }          -- baseline 1891
CardLayout.RARITY = { x = 41, line = 1968, size = 64, tracking = -0.02 }
CardLayout.SERIAL = { right = 1235, line = 1891, size = 112 }
CardLayout.BARCODE = { x = 839, y = 1919, w = 396, h = 84 }
CardLayout.LOW_SERIAL = { x = 860, y = 1780, w = 400, h = 240 }   -- baseline 2003, digits 275
CardLayout.LOW_GLOW = { x = 800, y = 1730, w = 480, h = 318 }
CardLayout.CROSSHAIR = { x = 520, y = 1356, w = 240, h = 240 }    -- centred on the globe
CardLayout.MEASURE = { x = 45, y = 1140, w = 645, h = 60 }
CardLayout.GRID_TILE = 80
CardLayout.SMALL_CARD = 160 -- pixels wide; below this a card shows half the particles

function CardLayout.rarityRight(text: string): number  -- right edge of rarity text, SVG units
function CardLayout.count(full: number, cardWidth: number): number -- particles to draw at this pixel width
```

- [ ] **Step 1: Write the failing tests:**

```lua
it("keeps the longest rarity text clear of the serial", function()
	local serialLeft = CardLayout.SERIAL.right - 4 * 0.6 * CardLayout.SERIAL.size
	expect(CardLayout.rarityRight("prototype chromatic") < serialLeft).toBe(true)
end)
it("keeps every rect inside the card", function()
	for _, name in { "MONOGRAM", "RAYS", "STAR_BIG", "STAR_SMALL", "NAME", "BARCODE", "LOW_SERIAL", "LOW_GLOW", "CROSSHAIR", "MEASURE" } do
		local r = CardLayout[name]
		expect(r.x >= 0 and r.y >= 0 and r.x + r.w <= 1280 and r.y + r.h <= 2048).toBe(true)
	end
end)
it("ends the barcode on the bottom margin", function()
	expect(CardLayout.BARCODE.y + CardLayout.BARCODE.h).toBe(2048 - 45)
end)
it("halves particles on small cards and never returns less than one", function()
	expect(CardLayout.count(24, 400)).toBe(24)
	expect(CardLayout.count(24, 100)).toBe(12)
	expect(CardLayout.count(1, 20)).toBe(1)
end)
```

- [ ] **Step 2: Run the tests.** Expected: fail, module not found.
- [ ] **Step 3: Implement.** PP Fraktion Mono's advance is 0.6 of its size, so `rarityRight` is `RARITY.x + #text * (0.6 + RARITY.tracking) * RARITY.size`. `count` is `math.max(1, if cardWidth < SMALL_CARD then full // 2 else full)`.
- [ ] **Step 4: Run the tests.** Expected: pass.
- [ ] **Step 5: Commit** "Add CardLayout: the new card face's positions".

---

### Task 3: Bake the layers

**Files:**
- Modify (rewrite): `tools/make-card-art.py`
- Modify: `tools/export_font_atlas.py` (the `Label` style only)
- Output, not committed: `assets/cards/layers/*.png`, `assets/cards/flat/*.png`, `assets/hud/Label.png`
- Regenerated and committed: `src/shared/Guns/Hud/GlyphData.luau`

**Interfaces:**
- Produces these PNGs, all white (255,255,255) with alpha, unless noted. Scale: full-card layers at 0.5 pixel per unit (640 by 1024); cropped layers at 1 pixel per unit of their `CardLayout` rect.

| File | Content |
| --- | --- |
| `layers/still.png` | Full card. The SVG's three boxes and two arrows where they are; the globe group moved down 170. No rays, burst dot or sparkles. |
| `layers/rays.png` | `RAYS` rect: every line inside the burst box, without the box or the dot. |
| `layers/star_big.png`, `layers/star_small.png` | The two sparkle paths, in `STAR_BIG` and `STAR_SMALL`. |
| `layers/mono_PD.png` (and `OC`, `RP`, `AS`) | `MONOGRAM` rect: the two letters turned to read up the card and stretched to fill the rect exactly, as `fitted()` does today. |
| `layers/name_phase_dash.png` (one per card id) | `NAME` rect: `CardLook.faceName` text, PP Fraktion Mono Regular at 112, origin at x 0, baseline 91 down, drawn with a 2.7-unit stroke (24 thousandths of 112) for the medium weight. |
| `layers/barcode.png` | `BARCODE` rect: the 18 bars from the mockup, widths and gaps scaled by 1.2. Bar x and width in a 330-wide strip: (0,10) (20,4) (34,16) (60,4) (72,8) (92,20) (120,4) (132,4) (146,12) (168,6) (182,18) (208,4) (222,10) (240,4) (254,16) (278,6) (292,4) (306,24). |
| `layers/swirl.png` | Full card: three rosettes centred (640, 1024). Each curve is `r = R * (1 + amp * sin(n * angle + k * 2π / count))` for `k` in `0..count-1`: (R 860, n 9, amp 0.2, count 16), (470, 7, 0.28, 14), (190, 5, 0.35, 10). |
| `layers/grid.png` | 160 by 160 pixels: two repeats each way of an 80-unit tile with one line along its top and one along its left. |
| `layers/crosshair.png` | `CROSSHAIR` rect, centred: ring radius 56, four arms from 30 to 90 out, four corner brackets at 80 to 110. No hairlines, no ping. |
| `layers/measure.png` | `MEASURE` rect: end ticks full height, a line along the middle, an arrowhead 34 long and 32 tall at each end. |
| `layers/low_01.png` … `low_10.png` | `LOW_SERIAL` rect: two digits, PP Fraktion Mono Bold at 275, origin x 45, baseline 223 down. |
| `layers/low_glow_01.png` … `low_glow_10.png` | `LOW_GLOW` rect: the same digits in the same card position, Gaussian blur radius 15. |
| `flat/PD_Field.png` (16: card × look) | 600 by 960, RGBA with rounded corners: background colour, acronym in its colour, `still`, rays, burst dot, sparkles and name in the ink colour, barcode. No rarity, serial or glow. For the card in hand. |

- Line weight: every stroke from the SVG is drawn 5 units wide (River's file says 2; 5 is so hairlines survive the Profile index, as the old art's 1.2-in-150 did). Flag this to River in Task 4.

- [ ] **Step 1: Copy the SVG** to `assets/cards/source/base.svg` from `E:\CARD DESIGNS\BASE DESIGN\SVG\Artboard 1.svg`.
- [ ] **Step 2: Rewrite `tools/make-card-art.py`.** No SVG library is installed, so parse the file with `xml.etree`: it only holds `polygon`, `rect` (one with a `rotate(90)` that is still a square), `circle`, `line`, `ellipse` and two `path`s of relative cubic curves; flatten the paths with `fontTools.svgLib.path.parse_path` into a `fontTools.pens.recordingPen.RecordingPen` and sample each curve at 24 points. Draw at 4 times the output size and downscale with LANCZOS. Classes: `cls-1` fill only, `cls-2` fill and stroke, `cls-3` stroke only. The font folder for PP Fraktion is the script's first argument.
- [ ] **Step 3: Run it:** `python tools/make-card-art.py "C:/Users/river/Downloads/PPFraktion-Pro/PPFraktion-Pro/Mono"`. Expected: 37 files in `assets/cards/layers` (1 still, 1 rays, 2 stars, 4 monograms, 4 names, barcode, swirl, grid, crosshair, measure, 10 low, 10 glow) and 16 in `assets/cards/flat`. The script's last line prints both counts.
- [ ] **Step 4: Look at them.** Build one contact sheet of every layer on a navy background (reuse the idea in `$TEMP/sd/card/sheet.py`) at `assets/preview/card-layers.png`, Read it, and check against the spec's Layout table: globe lower, acronym stops before the boxes, name baseline level with nothing cut off.
- [ ] **Step 5: Add lowercase to the `Label` sheet.** In `tools/export_font_atlas.py` give `Label` its own character set: `LABEL_CHARACTERS + string.ascii_lowercase`. Run `python tools/export_font_atlas.py "C:/Users/river/Downloads"` (it searches recursively for both fonts). Expected: `GlyphData.luau` changes only by added lowercase entries under `Label`; `git diff --stat` shows that one file. If other styles' numbers moved, the wrong font files were found: stop and report.
- [ ] **Step 6: Run the three checks, then commit** `tools src` with "Bake the new card face as layers; add lowercase to the Label sheet". Confirm `git status --short` lists nothing under `assets/`.

---

### Task 4: Upload, record ids, and draw the still face

**Files:**
- Modify: `src/shared/CardCore/CardArt.luau`, `src/shared/Guns/Hud/FontImages.luau`
- Modify: `src/client/CardFace.luau` (the front only: `CardFace.new` and its helpers above it)
- Modify: `src/shared/CardCore/CardLook.luau` (remove `serialText`, `bigSerialSize`, `SERIAL_DIGITS`)
- Test: `tests/cardart_spec.luau`, `tests/cardlook_spec.luau`

**Interfaces:**
- Consumes: Task 1's `CardLook` functions, Task 2's `CardLayout`, Task 3's files.
- Produces in `CardArt`: `CardArt.layer(name: string): string` for `"still" | "rays" | "star_big" | "star_small" | "barcode" | "swirl" | "grid" | "crosshair" | "measure"` (errors on an unknown name); `CardArt.monogram(cardId): string?`; `CardArt.name(cardId): string?`; `CardArt.lowSerial(n: number): string?`; `CardArt.lowGlow(n: number): string?`. `CardArt.base` stays and now returns the new flat images. `CardArt.outline` and its table are removed.
- Produces in `CardFace.new`: the returned root has the same type and `Options` as today. `options.corner`, when given, is shown in place of the serial text (the index's copy count).

- [ ] **Step 1: Upload.** `python tools/upload-group-assets.py "$TEMP/sd/card/card-layers.json" assets/cards/layers/*.png assets/cards/flat/*.png assets/hud/Label.png`. If `ROBLOX_GROUP_API_KEY` is unset, stop and ask River. Never echo the key.
- [ ] **Step 2: Update the failing tests.** `cardart_spec.luau`: every card id has `monogram`, `name` and a `base` for each look, all starting `rbxassetid://`; every layer name resolves; `lowSerial` and `lowGlow` resolve for 1 to 10 and are `nil` for 0 and 11; a made-up card id gives `nil` for `monogram`, `name` and `base`. Remove the `outline` assertions. `cardlook_spec.luau`: delete tests of `serialText` and `bigSerialSize` if any exist.
- [ ] **Step 3: Run the tests.** Expected: the new `CardArt` tests fail.
- [ ] **Step 4: Fill in `CardArt.luau` and `FontImages.Label`** from the results file. Run the tests. Expected: pass.
- [ ] **Step 5: Rebuild `CardFace.new` as layers.** Work in SVG units with `unit = options.width / CardLayout.WIDTH`. Order, back to front: root (background colour, corner 85); `still` tinted ink; `rays` tinted ink; burst dot (a round frame, ink); the two sparkles (ink); acronym image tinted the acronym colour; name image tinted ink; rarity as `TypeLabel` style `Label` with `CardLook.faceRarity`; then either the barcode plus the serial (`TypeLabel` style `LabelLarge`, right-aligned at `SERIAL`, text `options.corner` or `CardLook.faceSerial(serial)`, acronym colour) or, when `CardLook.isLowSerial(serial)`, the low-serial image tinted white with no barcode (its colour and glow come in Task 7). `serial` is `options.serial`, or in Studio only (`RunService:IsStudio()`) `CardLook.studioSerial(options.cardId)`. Replace `LOOKS` with: Field (back DeepNavy, ink Bone, mark Bone, shine 0.28), Redline (Bone, DeepNavy, HazardRed, 0.7), Prototype (SignalAcid, DeepNavy, DeepNavy, 0.5), ZeroDay (ZeroDayBack, Bone, DataCyan, 0.6). Keep the ghost path (CanvasGroup, early return, no motion) and keep the existing shine exactly as it is. Delete `outline`, `crosshairFill`, `pulse`, `scrambling`, the stripes and set-code lines, the old foil and ping, and every front-only constant they used. A missing image id is `""`, never an error. Don't touch `CardFace.back` or its constants.
- [ ] **Step 6: Remove `CardLook.serialText`, `bigSerialSize` and `SERIAL_DIGITS`.** Grep `src` to confirm no caller remains.
- [ ] **Step 7: Run the three checks.** Expected: compile and globals clean, all tests pass.
- [ ] **Step 8: Commit** "Draw the new card face from layers (still, no new motion yet)".
- [ ] **Step 9: Hand to River.** Ask them to open the Loadout, the Profile index, a pull and the card in hand in Play and compare with the last mockup. Tell them: line weight is 5 not 2, serials are Studio stand-ins (Phase Dash shows the low look, uncoloured for now), and only the shine moves so far. Wait for their answer before Task 5.

---

### Task 5: Motion every card has

**Files:**
- Modify: `src/shared/Guns/Hud/CardMotion.luau`, `src/client/CardFace.luau`
- Test: `tests/cardmotion_spec.luau`

**Interfaces:**
- Produces in `CardMotion` (all pure; `elapsed` in seconds):
  - `breathe(elapsed: number, period: number, offset: number): (number, number)` returns scale and transparency: scale runs 1 → 0.78 → 1 and transparency 0 → 0.45 → 0 as a cosine over `period`, shifted by `offset` seconds.
  - `orbit(elapsed: number, period: number, direction: number): (number, number)` returns the cosine and sine of the angle; `direction` is 1 or -1. At `elapsed = 0` it returns `(-1, 0)` (the ring's left end, as in the mockup).
- Removes `CardMotion.pulse` and `CardMotion.scramble` with their constants and tests (their callers went in Task 4).

- [ ] **Step 1: Write the failing tests:**

```lua
it("breathes between full size and 78 percent", function()
	local scale, transparency = CardMotion.breathe(0, 3, 0)
	expect(scale).toBeCloseTo(1); expect(transparency).toBeCloseTo(0)
	scale, transparency = CardMotion.breathe(1.5, 3, 0)
	expect(scale).toBeCloseTo(0.78); expect(transparency).toBeCloseTo(0.45)
	expect((CardMotion.breathe(0, 3, 1.5))).toBeCloseTo(0.78) -- half a cycle apart
end)
it("carries a dot once round its ring in one period, either way", function()
	local x, y = CardMotion.orbit(0, 6, 1)
	expect(x).toBeCloseTo(-1); expect(y).toBeCloseTo(0)
	local x2, y2 = CardMotion.orbit(1.5, 6, 1)
	local x3, y3 = CardMotion.orbit(1.5, 6, -1)
	expect(x2).toBeCloseTo(x3); expect(y2).toBeCloseTo(-y3)
	x, y = CardMotion.orbit(6, 6, 1)
	expect(x).toBeCloseTo(-1); expect(y).toBeCloseTo(0)
end)
```

- [ ] **Step 2: Run the tests.** Expected: fail.
- [ ] **Step 3: Implement both and delete `pulse` and `scramble`.**
- [ ] **Step 4: Wire into `CardFace.new`'s animate step** (non-ghost only): sparkles `breathe(elapsed, 3, 0)` and `breathe(elapsed, 3, 1.5)`, scaled about their centres; burst dot `breathe(elapsed, 1.2, 0)`; rays take only the transparency of `breathe(elapsed, 2.4, 0)`. Three round frames orbit `CardLayout.GLOBE`: outer ring radius 20 units, period 6, direction 1, acronym colour; middle 15, 4.4, -1, ink colour, started 1.5s in; inner 12, 3, 1, acronym colour, started 0.8s in. Position is `(GLOBE.x + ring * cos, GLOBE.y + GLOBE.ry * sin)`.
- [ ] **Step 5: Run the three checks. Commit** "Add the motion every card has: sparkles, burst, orbiting dots".

---

### Task 6: Each rarity's effects

**Files:**
- Create: `src/client/CardFaceFx.luau`
- Modify: `src/shared/Guns/Hud/CardMotion.luau`, `src/client/CardEffects.luau`, `src/client/CardFace.luau`
- Test: `tests/cardmotion_spec.luau`

**Interfaces:**
- Consumes: `CardLayout`, `CardArt.layer`, `CardEffects.band/animate/rounded`, Task 5's `CardMotion`.
- `CardEffects.band` gains an optional sixth parameter `rotation: number?` (default the existing 20). `CardEffects.ping` gains `color: Color3`, `from: number`, `to: number`, `period: number` parameters in place of its fixed cyan and `CardMotion.ping`; update its one other caller if `grep` finds one.
- Produces `CardFaceFx.build(look: string, root: GuiObject, unit: number, width: number, parts: Parts): { (elapsed: number, shine: number) -> () }` where `Parts = { monogram: ImageLabel, starBig: ImageLabel, starSmall: ImageLabel, ink: Color3, mark: Color3 }` and `shine` is the shine's current gradient offset (-1 to 1). `"Field"` returns an empty list. `CardFace.new` calls every returned function each frame after moving the shine.
- Produces in `CardMotion`, all pure and deterministic from the index so every card of a rarity looks alive but tests can pin them:
  - `sweepDown(elapsed): number` — offset for the red band: -1 → 1 over the first 40% of a 5s period, then held at 1.
  - `flicker(elapsed): number` — acronym transparency over a 3.2s period: 0.3 from 45% to 48%, 0.15 from 70% to 73%, otherwise 0.
  - `ember(index: number, elapsed: number): (number, number, number, number)` — x, y, size, transparency in SVG units. Start x `45 + (index * 173) % 1180`, start y `1780 + (index * 97) % 240`, size `8 + (index % 3) * 6`, period `2.6 + (index % 4) * 0.7`, phase `index * 0.41` seconds; rises 900 over the period; transparency 1 → 0 over the first 15%, then 0 → 1 to the end.
  - `mark(index: number, elapsed: number): (number, number, boolean)` — x `90 + (index * 311) % 1100`, y `120 + (index * 587) % 1560`, shown for the first 60% of a period of `1.4 + (index % 5) * 0.5`, phase `index * 0.33`.
  - `measure(elapsed): (number, number)` — reveal and transparency over 5s: reveal 0 → 1 across the first 35% and stays 1; transparency 0 until 80%, 0 → 1 from 80% to 95%, then 1.
  - `gridShift(elapsed): number` — 0 → 1 every 4s.
  - `twinkle(index: number, elapsed: number): (number, number, number)` — x `110 + (index * 397) % 1060`, y `180 + (index * 613) % 1500`, size in units `154 * (0.28 + (index % 3) * 0.14) * sin(π * t)` where `t` is the 0-to-1 position in a period of `2.2 + (index % 4) * 0.6`, phase `index * 0.53`.
  - `foilShift(elapsed): number` — 0 → 1 every 6s.

- [ ] **Step 1: Write the failing tests,** one `it` per function, pinning these values: `sweepDown(0) = -1`, `sweepDown(1) = 0`, `sweepDown(2) = 1`, `sweepDown(4.9) = 1`; `flicker(0) = 0`, `flicker(3.2 * 0.46) = 0.3`, `flicker(3.2 * 0.71) = 0.15`; `ember(0, 0)` gives x 45, y 1780, size 8, transparency 1, and `ember(0, 1.3)` gives y 1330; every `ember(i, t)` for `i` in 0..23 and `t` in {0, 1, 2.5} has x between 45 and 1235 and y between 0 and 2048; `mark(0, 0)` gives 90, 120, true and `mark(0, 1.0)` gives false; every mark for `i` in 0..13 lies inside the card; `measure(0) = (0, 0)`, `measure(1.75) = (1, 0)`, `measure(4.75)` transparency 1; `gridShift(2) = 0.5`; `twinkle(0, 0)` size 0 and `twinkle(0, 1.1)` size `154 * 0.28` within 0.01, never negative for `t` in 0..10 step 0.37; `foilShift(3) = 0.5`.
- [ ] **Step 2: Run the tests.** Expected: fail.
- [ ] **Step 3: Implement the `CardMotion` functions. Run the tests.** Expected: pass.
- [ ] **Step 4: Write `CardFaceFx.luau`.** One local builder per look, each returning update functions:
  - **Redline:** a red band from `CardEffects.band(root, corner, 0.2, ColorSequence.new(Palette.HazardRed), 0.42, 90)` moved by `sweepDown`; `CardLayout.count(24, width)` square HazardRed frames placed by `ember`; `parts.monogram.ImageTransparency = flicker(elapsed)`.
  - **Prototype:** behind everything (ZIndex below the acronym), the `grid` image tiled at `GRID_TILE` units, ImageColor3 ink, ImageTransparency 0.84, scrolled by sliding `ImageRectOffset` by `gridShift * 80` pixels on both axes with `ImageRectSize` 80 by 80 (the trick `CardEffects.stripes` uses, so nothing needs clipping); `CardLayout.count(14, width)` plus marks, each two ink frames 36 by 5 units, shown by `mark`; the `crosshair` image at `CROSSHAIR` plus two ink hairlines 3 units thick at 55% transparency, spanning the card's full width at y 1476 and full height at x 640, each split so it leaves a 140-unit gap at the centre; `CardEffects.ping` at the globe centre in ink, 56 → 134 units, 1.3s; the `measure` image at `MEASURE` with a horizontal `UIGradient` whose transparency edge is driven by `measure`'s reveal, and `ImageTransparency` by its second value.
  - **ZeroDay:** behind the acronym, the `swirl` image tinted DataCyan at 0.87 transparency; above it the same image with a `UIGradient` at rotation 20 whose Color is the foil sequence (`#01FFFF`, `#7A5CFF`, `#FF4FD8`, `#FFD166`, `#01FFFF`) and whose Transparency is a band of half-width 0.3 clear at the centre, with `Offset.X = shine`; a `UIGradient` with the same foil colours on each of `parts.starBig` and `parts.starSmall` (set their ImageColor3 to white), `Offset.X = foilShift * 2 - 1`; `CardLayout.count(9, width)` copies of the `star_small` image tinted Bone, placed and sized by `twinkle`.
- [ ] **Step 5: Call it from `CardFace.new`** after the shared motion, passing the shine's offset each frame (the held `shineAt` value when there is one).
- [ ] **Step 6: Review Focus 4 check.** Read `CardFace.new` once more: the ghost path returns before any `CardFaceFx.build` or `CardEffects.animate` call.
- [ ] **Step 7: Run the three checks. Commit** "Give each rarity its own effects on the new card face".
- [ ] **Step 8: Hand to River** to judge the three rarities in Play. Expect tuning; change values in `CardMotion` and their tests together.

---

### Task 7: The low-serial look

**Files:**
- Modify: `src/shared/Guns/Hud/CardMotion.luau`, `src/client/CardFace.luau`
- Test: `tests/cardmotion_spec.luau`

**Interfaces:**
- Produces: `CardMotion.rainbowShift(elapsed): number` (0 → 1 every 2.6s) and `CardMotion.glow(elapsed): number` (transparency 0.25 → 0 → 0.25 as a cosine every 1.6s; `glow(0) = 0.25`, `glow(0.8) = 0`).

- [ ] **Step 1: Write the failing tests** for those four values plus `rainbowShift(1.3) = 0.5`.
- [ ] **Step 2: Run. Expected: fail. Step 3: Implement. Step 4: Run. Expected: pass.**
- [ ] **Step 5: In `CardFace.new`'s low-serial branch,** add the `CardArt.lowGlow` image at `LOW_GLOW` under the number, and give both images one shared-shape `UIGradient` at rotation 20 with the rainbow `#FF2D55, #FF9F0A, #FFE600, #30E060, #01D5FF, #8A5CFF, #FF2D55` (ImageColor3 white). Each frame set both gradients' `Offset.X = rainbowShift * 2 - 1` and the glow image's `ImageTransparency = glow(elapsed)`. A ghost card shows the number untinted and still.
- [ ] **Step 6: Run the three checks. Commit** "Add the rainbow glow for serials 1 to 10".
- [ ] **Step 7: Hand to River:** in Studio, Phase Dash (stand-in serial 1) and Overclock (7) show it; Recon Pulse and Aegis Shell show normal serials.

---

### Task 8: Bring the docs in line

**Files:**
- Modify: `docs/specs/card-art.md`, `docs/specs/card-face-redesign.md`, `docs/HANDOFF.md`

- [ ] **Step 1:** In `card-art.md`, replace the Layout and Rarities sections with a short pointer to `card-face-redesign.md`, and fix "How it's built" (layers, not one image; the hand's flat image) and the status line. In `card-face-redesign.md`, change the status to what was built and what River has and hasn't judged in Play, and correct any number that tuning changed. Add the Studio stand-in serials and the 5-unit line weight to `HANDOFF.md`'s open items.
- [ ] **Step 2: Commit** "Update the card specs for the new face".
