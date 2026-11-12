# Card face redesign

**Status:** built on 2026-11-11. River has checked the still card in Play ("looks right"). The motion, each rarity's effects and the rainbow low serial are built and pass their tests but have not been seen in Play. This replaces the Layout and Rarities sections of `card-art.md`; the rest of that spec stands.

**Covers:** the front of a card: its layout, type, the effect each rarity gets, and the look of serials 1 to 10.

## The idea

River drew a sheet of micrographics (two arrow boxes, a burst, two sparkles, a globe) and wants the card built around it. The card keeps its sideways acronym and its four colour schemes. Everything that used to be drawn by hand in `tools/make-card-art.py` (crosshair, ticks, slashes, rule, stripes) goes, and River's graphics take its place. Each rarity then gets its own motion on top, so a rarer card is busier.

Success is River looking at the card in Play and saying it matches the last mockups.

## Source art

- River's file is `E:\CARD DESIGNS\BASE DESIGN\SVG\Artboard 1.svg`, 1280 by 2048. A copy goes in `assets/cards/source/`, which stays out of git like the rest of `assets/`.
- All positions below are in that file's units, from the card's top left. The game keeps them in `CardLayout.luau`.
- River's lines are 2 wide in the file. They are baked 5 wide so they survive on small cards. River hasn't objected; it is theirs to change. The card is still 5:8 with corners rounded by 85 (the old 10 in 150).
- The margins are River's: 45 on the left, right and bottom, 69 at the top.

## Layout

| Part | Where | Notes |
| --- | --- | --- |
| Acronym | Left 45 to 690, top 69 to 1130 | KH Interference Bold, turned to read up the card, stretched to fill the box exactly, as today. Narrower than before so it stops short of River's graphics. No glow. |
| Arrow boxes, burst, sparkles | Where the SVG has them | In the ink colour. |
| Globe | The SVG's globe moved down by 170, so its centre is at (640, 1476) | River asked for it lower. |
| Card name | Left 45, baseline 1891 | Capitals, spaces removed (`PHASEDASH`). PP Fraktion Mono at 112, medium weight, no extra letter spacing. |
| Rarity | Left 45, baseline 1968 | Lowercase (`zero-day`). PP Fraktion Mono Regular at 64, letters slightly tighter than the font's default. |
| Serial | Right edge 1235, baseline 1891 | Four digits (`0042`). PP Fraktion Mono Bold at 112, so it is the same height as the name and sits on the same line. In the rarity's acronym colour. |
| Barcode | Right edge 1235, 396 wide, top 1919 to 2003 | Ends on the bottom margin. The same bars on every card. |

- **Medium weight:** PP Fraktion Mono has no Medium. It is made by thickening Regular by 24 thousandths of the letter size, which is how the mockup drew it.
- **Gone from the face:** the outline round the card, the acronym's glow, the small serial at top right, the lower block and its hazard stripes, the rule, and the set code.
- **Card names elsewhere** (menus, the back of the card) keep their space: "Phase Dash".
- **The index card** still shows its copy count where the serial goes.

## Colours

Unchanged from `Palette.Tiers`.

| Rarity | Background | Acronym and serial | Ink (graphics and text) |
| --- | --- | --- | --- |
| Field | Deep Navy `#29324F` | Bone | Bone |
| Redline | Bone `#E8E6DF` | Hazard Red | Deep Navy |
| Prototype | Signal Acid `#C2FE0B` | Deep Navy | Deep Navy |
| Zero-Day | `#0E1018` | Data Cyan | Bone |

Zero-Day is still a variant that any tier can have, and still looks the same at every tier. Its rarity text names both in lowercase, like `field zero-day`.

## Motion every card has

| Part | What it does |
| --- | --- |
| Shine | A slanted white band crosses the card, as today. It is stronger on Redline and Prototype so it shows on their light backgrounds. |
| Sparkles | The two sparkles shrink and grow in turn, 3s each, half a cycle apart. |
| Burst | The centre dot pulses every 1.2s and the rays every 2.4s. |
| Globe | Stays still. Three dots orbit it, one on each ring: 6s, 4.4s the other way, and 3s. The outer and inner dots are the acronym colour, the middle one the ink colour. |
| Arrows | Still. |
| Acronym | Still, on every rarity except Redline's flicker below. |

## What each rarity adds

| Rarity | Effects |
| --- | --- |
| Field | Nothing more. |
| Redline | A wide, soft red band sweeps down the card every 5s. Red embers rise from the bottom edge and fade. The acronym flickers briefly, like a bad light. |
| Prototype | A faint blueprint grid slides diagonally behind everything. Small plus marks blink on and off around the card. A crosshair sits locked on the globe's centre, with hairlines running to the card's edges and a ring that pings outward every 1.3s. A measuring line with arrowheads draws itself under the acronym, holds, fades, and repeats every 5s. |
| Zero-Day | The background carries fine swirl lines like the engraving on a banknote, barely visible. A band of light crosses the card every 5.5s, and where it passes the lines show in foil colours (cyan, violet, pink, gold). The shine travels with that band. The two sparkles are filled with the same slowly shifting foil. A few small copies of the sparkle twinkle around the card. |

The old Prototype pulse on the acronym and the old Zero-Day foil band, filled crosshair and scrambling serial are dropped.

## Serials 1 to 10

A card whose serial is 1 to 10 shows it differently, on any rarity:

- The number is two digits (`01` to `10`) in PP Fraktion Mono Bold at 275, right edge 1235, sitting on the bottom margin. Its top is level with the top of the card name.
- It is a full rainbow that keeps sliding across the digits, with a soft glow in the same colours behind it that pulses every 1.6s.
- There is no barcode.

The glow is weaker on Redline and Prototype, because their backgrounds are light. River has seen this in the mockup.

## Things the mockups showed that are not in this design

- **"/1000":** every mockup had `/1000` after the serial. Cards have no limit on copies, so there is no total to print. It is left off until River sets one.
- **Serials are not in the game yet.** `card-art.md` lists them as step 3, and cards show `--` today. Until then Studio shows stand-in serials so both looks can be judged (`CardLook.studioSerial`: Phase Dash 1, Overclock 7, Recon Pulse 42, Aegis Shell 117), and the live game shows `----`.
- **Light that follows the mouse or the card's tilt** on Zero-Day was an idea, not a decision. The band runs on a timer. Inspecting a card already ties the shine to its angle, and the light band follows the shine there.

## How it's built

`CardFace.luau` keeps drawing the card. The change is that the face becomes layers that can move on their own.

- **Baked images** (`tools/make-card-art.py`, uploaded as group assets as today), all white on clear so one image serves every rarity by tinting:
  - River's graphics, split into the still parts (boxes, arrows, globe), the burst's rays, the burst's dot, and each sparkle.
  - The four acronyms.
  - The four card names, already in medium weight.
  - The barcode.
  - The Zero-Day swirl lines.
  - The ten low-serial numbers, each with a blurred copy for the glow, because Roblox can't blur text.
- **Live text:** the rarity and the normal serial use `TypeLabel`. Its `Label` set has no lowercase letters, so a lowercase set is added for the rarity. The serial uses the existing bold set.
- **Motion** uses what the card already uses: frames moved and scaled each frame, and `UIGradient` for the shine, the red band, the foil colours and the rainbow. The Zero-Day reveal is one gradient on the swirl image that carries both the colours and a see-through band. Embers, plus marks and twinkles are small frames or copies of the sparkle image.
- **Pure rules** go in `CardLook.luau`: the printed name (capitals, no spaces), the rarity text in lowercase, the four-digit serial, and whether a serial gets the low-serial look.
- **Cost:** motion runs only while a card is on screen, as today. Cards drawn small (the Profile index) use about half the embers, marks and twinkles.

## What could go wrong

- **Foil and glow in Roblox** won't match a browser exactly. Roblox can't blend colours into what is beneath, so the foil and glow sit on top at partial transparency. River judges them in Play.
- **The mockups are not the game.** They were drawn in a browser. Timings above are the mockup's and are a starting point.
- **Rotated parts lose clipping in Roblox**, and the HUD tilts its cards. So nothing may rely on the card cutting it off: bands are card-sized frames whose gradient moves (as the shine is today), and embers, marks and twinkles stay inside the card's edges.
- **The card in your hand** (`CardView.luau`) shows one flat image per card and look, not `CardFace`. It gets a new flat image of the still face with the name, and no rarity text, serial or motion, as today.

## Order of work

1. The still face: new images, layout, type, colours. River checks it in Play.
2. The motion every card has.
3. Each rarity's effects.
4. The low-serial look, shown with a test serial.

## Tests

Lune tests cover the pure rules: the printed name for one-word and two-word cards, lowercase rarity text for each tier and variant, serial padding, and the 1 to 10 check at 0, 1, 10 and 11. River judges the look and motion in Play.
