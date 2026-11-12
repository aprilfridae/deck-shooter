# Card art

**Status:** the front is the 2026-11-11 redesign (`card-face-redesign.md`): built and checked by River in Play. The back, inspecting a card in 3D and the pull reveal are built. Real serials aren't built: Studio shows stand-in serials and the live game shows `----`. Chromatic and Redacted are proposals River hasn't seen drawn yet, and show only their rarity text.

**Covers:** how cards look, and the serial numbers printed on them. How cards work is in `cards.md`. The pull reveal is in `packs.md`, and fusion effects get their own spec.

## The idea

Common cards stay calm in the game's navy and Bone, so rare ones hit hard. Every card is the same layout, and rarity shows through colour, glow and motion.

## Names

- The Black-Site tier is shown to players as **Redline**. Its id stays `BlackSite`, so saves don't change. The shown names are `TIER_NAMES` in `src/shared/CardCore/CardLook.luau`.
- Each card has a two-letter monogram: `PD` Phase Dash, `OC` Overclock, `RP` Recon Pulse, `AS` Aegis Shell. A new card needs one.

## Layout, rarities and effects

The front of the card was redesigned on 2026-11-11 around River's micrographics. Its layout, type, colours, the motion every card has, each rarity's effects and the look of serials 1 to 10 are in `card-face-redesign.md`.

## Variants

Tiers and variants are separate: a card has one of each, so any tier can be Zero-Day.

- **Zero-Day** looks the same at every tier, and its rarity text names both, like `field zero-day` on the front and `FIELD ZERO-DAY` on the back.
- **Chromatic** keeps the tier's look, and its rarity text reads like `field chromatic`. The shine cycles through Signal Acid, Data Cyan and Bone. (Proposal.)
- **Redacted** keeps the tier's look with a solid bar over the monogram that lifts under the mouse. Rarity text reads like `field redacted`. (Proposal.)

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
- Serials are padded to four digits, and longer numbers show in full. Serials 1 to 10 show as a big two-digit rainbow number.
- Serials never change and are never reused, even when a copy is spent.

**What this changes in `cards.md`:**

- **Saves:** copies are stored as counts today, like `phase_dash:Field:Base`. Each copy becomes its own record, with its serial. Saves move to a new version, and existing copies get serials the first time they load.
- **Counters:** the next serial lives in a shared counter that every server updates with `UpdateAsync`, so two servers can't hand out the same number. If the counter can't be reached, the request fails and changes nothing in the save, like any other failed request.
- **Fusion:** spends the highest serials first, so your lowest numbers are the last to go. Variants still need confirming.
- **Income, Deck Power Rating and decks:** don't change. They still go by card, tier and variant.

## How it's built

- **Art:** the front is white image layers the game tints and moves: River's graphics, the acronym, the baked name, the barcode and the effect images. `tools/make-card-art.py` bakes them from River's SVG and the two fonts, and `CardLayout.luau` holds where each sits. Images are group assets, ids in `CardArt.luau`.
- **Live parts:** the rarity and serial through `TypeLabel`, the shine and the other bands as frames with a moving `UIGradient`, particles as small frames. `CardFaceFx.luau` builds each rarity's effects and `CardMotion.luau` holds the timing rules.
- **Foil and glow:** Roblox UI can't blend colours into what's beneath or blur text, so foil sits on top at partial transparency and the low serial's glow is a blurred picture. River judges them in Play.
- **Where cards show:** `CardFace.luau` draws a card in the Loadout slots, the Profile index and the pull reveal. `CardView.luau` is the 3D card held in hand. It shows one flat image per card and look: the still face with the name, without rarity text, serial or motion.
- **In the panels:** a Loadout slot's number moves under the card. An index card shows its copy count where the serial goes, since it stands for every copy of that card.
- **Small sizes:** lines are baked 5 units wide (of 1280) so they survive the Profile index, and cards under 160 pixels wide show half the particles. Motion runs only while a card is on screen.

## Order of work

1. The art and `CardFace.luau` in the menus, with serials shown as a placeholder. Built.
2. The card in hand, in `CardView.luau`.
3. Serials: saves, counters and fusion.
4. A separate spec for fusion effects.

## Tests

Monogram lookup, rarity text for each tier and variant, serial formatting, fusion's spending order, and moving old saves are pure rules tested in Lune. River judges the look and motion in Play.
