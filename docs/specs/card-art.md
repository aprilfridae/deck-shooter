# Card art

**Status:** step 1 is built: the art in the menus and the pull reveal, and inspecting a card in 3D. The card in hand and serials aren't built, so serials show `--`. Chromatic and Redacted are proposals River hasn't seen drawn yet, and show only their rarity text. Checked against the code on 2026-11-07.

**Redesign pending:** `card-face-redesign.md` (agreed 2026-11-11, not built) replaces the Layout and Rarities sections below once it's built.

**Covers:** how cards look, and the serial numbers printed on them. How cards work is in `cards.md`. The pull reveal is in `packs.md`, and fusion effects get their own spec.

## The idea

Common cards stay calm in the game's navy and Bone, so rare ones hit hard. Every card is the same layout, and rarity shows through colour, glow and motion.

## Names

- The Black-Site tier is shown to players as **Redline**. Its id stays `BlackSite`, so saves don't change. The shown names are `TIER_NAMES` in `src/shared/CardCore/CardLook.luau`.
- Each card has a two-letter monogram: `PD` Phase Dash, `OC` Overclock, `RP` Recon Pulse, `AS` Aegis Shell. A new card needs one.

## Layout

Cards are vertical, in the proportions 150 by 240. Positions below are in those units, measured from the card's top left. Corners are rounded by 10. The card has no connector tab.

| Part | Where | Notes |
| --- | --- | --- |
| Monogram | Left 12 to 104, top 12 to 158 | Heavy weight, turned 90 degrees to read up the card. Every monogram fills exactly this box, with no cuts and nothing past the card's edge. |
| Small serial | Top right, inset 10 | Upright. Field, Redline and Prototype only. |
| Crosshair | Centred on (130, 42) | Circle of radius 7, with arms from 120 to 140 and from 32 to 52. |
| Ticks | 5 lines from 125 to 135, at y 62 to 94, 8 apart | Centred under the crosshair. |
| Slashes | 4 slashes from x 116 to 140, y 182 to 192 | |
| Lower block | Left 12 to 104, top 160 to 198 | Hazard stripes, or Zero-Day's big serial. |
| Rule | y 204, from 10 to 140 | A hairline. |
| Card name | Bottom left, above the rarity | Upright. |
| Rarity | Bottom left, inset 7 | Upright. |
| Set code | Bottom right, inset 7 | `S01` for `set_01`. Dropped on a card whose rarity text is long enough to reach it, like `PROTOTYPE ZERO-DAY`. |

- All small text is upright when the card is held vertically, and uses `Label`.
- The crosshair, ticks, slashes and rule are identical on every card, in the card's ink colour.
- Stats aren't printed on the card's face. They show on its back when it's inspected.

## Rarities

| Rarity | Background | Monogram | Ink | Lower block | Shine strength |
| --- | --- | --- | --- | --- | --- |
| Field | Deep Navy | Bone, Bone glow | Bone | Bone stripes | 28% |
| Redline | Bone, Hazard Red outline | Hazard Red, red glow | Deep Navy, rarity text in Red | Red stripes | 70% |
| Prototype | Signal Acid, Deep Navy outline | Deep Navy | Deep Navy | Deep Navy stripes, scrolling | 50% |
| Zero-Day | `#0E1018`, Data Cyan outline | Data Cyan, cyan glow | Bone, rarity text in Cyan | Big serial | 60% |

- **Outline:** 2 wide, just inside the edge. Field has none.
- **Shine:** every card has a slanted white band that crosses it every 2.6s.
- **Prototype:** an outline of its monogram pulses outward and fades every 1.8s, and its stripes scroll.
- **Zero-Day** adds three things:
  - A soft foil band of cyan, blue and cyan travels with the shine.
  - The crosshair is filled with cyan and sends out a fading ring every 2s.
  - The serial scrambles through random characters and settles every 2.4s, at `PanelMotion.DECODE_FPS`.

## Variants

Tiers and variants are separate: a card has one of each, so any tier can be Zero-Day.

- **Zero-Day** looks the same at every tier, and its rarity text names both, like `FIELD ZERO-DAY`.
- **Chromatic** keeps the tier's look, and its rarity text reads like `FIELD CHROMATIC`. The shine cycles through Signal Acid, Data Cyan and Bone. (Proposal.)
- **Redacted** keeps the tier's look with a solid bar over the monogram that lifts under the mouse. Rarity text reads like `FIELD REDACTED`. (Proposal.)

## Colour rules

- Signal Acid, Data Cyan and Hazard Red may appear on cards. The menus and HUD stay navy and Bone, and `outpost-ui.md` lists cards as the exception.
- `Palette.Tiers` matches the table above, and `Palette.ZeroDayBack` is the Zero-Day background, `#0E1018`.

## Inspecting a card

Clicking a card in the Profile index or the pull reveal holds it up in the 3D world. `CardInspect.luau` draws it, and `CardSpin.luau` holds the motion rules.

- **Arrival:** the card spins once into place in the space beside the panel, at 70% of the screen's height. The panel stays open, the nav hides and the world dims to Deep Navy.
- **Spinning:** dragging turns the card freely, and tips it up to 0.6 radians. Let go and it eases to whichever side is nearest, then sways gently.
- **Shine:** while the card is turned, the shine and foil follow its angle. At rest they go back to the timed sweep.
- **The back:** a click without a drag flips the card. The top third is a solid block of the rarity's colour with a crosshair, the copies owned or `NOT OWNED`, the name, rarity and set code. Below it, the first stat is large and the rest smaller, then a short description and a strip of hazard stripes in the ink colour. `CardText.luau` holds the words, which are limited to the menu font's characters, so percentages read `PCT`.
- **Unowned cards** open too, faded and still.
- **Closing:** a click off the card closes it, as does anything that closes the menu. Esc can't be used, because Roblox keeps it for its own menu.
- The part is clear with a `SurfaceGui` on each side, so the card keeps its rounded corners. Both draw over the world, so nothing in the Outpost can cross the card, and only the side facing the camera is shown.

## Serial numbers

- Every copy of a card has a serial, given when it's created. The first copy made is `01`, the second `02`.
- Serials count separately for each card, tier and variant, so a Zero-Day Aegis Shell `01` and a Field Aegis Shell `01` can both exist.
- Serials are padded to two digits, and longer numbers show in full. Zero-Day's big serial shrinks to fit past two digits.
- Serials never change and are never reused, even when a copy is spent.

**What this changes in `cards.md`:**

- **Saves:** copies are stored as counts today, like `phase_dash:Field:Base`. Each copy becomes its own record, with its serial. Saves move to a new version, and existing copies get serials the first time they load.
- **Counters:** the next serial lives in a shared counter that every server updates with `UpdateAsync`, so two servers can't hand out the same number. If the counter can't be reached, the request fails and changes nothing in the save, like any other failed request.
- **Fusion:** spends the highest serials first, so your lowest numbers are the last to go. Variants still need confirming.
- **Income, Deck Power Rating and decks:** don't change. They still go by card, tier and variant.

## How it's built

- **Art:** the background, monogram, glow and fixed details are one image per card and rarity, because Roblox UI can't blur text. Images are group assets, ids kept with the others. The monogram uses KH Interference Bold, the same as the menu titles. `tools/make-card-art.py` makes the images.
- **Live parts** are drawn over the image: the serial and name through `TypeLabel`, the shine and foil as moving frames with `UIGradient`, the stripes as a scrolling image.
- **Foil:** Roblox UI can't blend colours into what's beneath, so the band sits on top at partial transparency. River judges it in Play.
- **Where cards show:** `CardFace.luau` draws a card in the Loadout slots, the Profile index and the pull reveal. `CardView.luau` is the 3D card held in hand, still drawn from the `Card` model without this art.
- **In the panels:** a Loadout slot's number moves under the card. An index card shows its copy count where the serial goes, since it stands for every copy of that card.
- **Small sizes:** hairlines are baked in at 1.2 units so they survive the Profile index. Motion runs only while a card is on screen.

## Order of work

1. The art and `CardFace.luau` in the menus, with serials shown as a placeholder. Built.
2. The card in hand, in `CardView.luau`.
3. Serials: saves, counters and fusion.
4. A separate spec for fusion effects.

## Tests

Monogram lookup, rarity text for each tier and variant, serial formatting, fusion's spending order, and moving old saves are pure rules tested in Lune. River judges the look and motion in Play.
