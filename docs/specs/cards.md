# Cards and the card economy

**Status:** changed on 2026-11-11: Switchback, Kickplate and Siphon were added, Recon Pulse was removed, and tiers were made to matter far more. None of that has been seen in Play. Before that: the 4 ability cards and the card rules (tiers, fusion, income, Deck Power Rating, saves) are built. The Outpost menu shows Credits, DPR and the collection and edits the deck, and packs give new cards (`packs.md`). Nothing shows fusion or Catalysts yet. Checked against the code on 2026-11-07.

**Values live in:** `src/shared/CardCore/Cards.luau` (cards and their stats) and `src/shared/CardCore/Config.luau` (everything else). The rules are pure modules in `src/shared/CardCore/`, tested in Lune. The server side is `src/server/CardCore.server.luau`, `PlayerCards.luau` and `AbilityServer.server.luau`.

## Rules that hold everywhere

- The server owns every card, Credit and roll result. The client only displays them.
- A loadout is 2 guns plus 3 different cards. A deck can't hold the same card twice.
- Tiers run Field, Redline, Prototype. Redline's id stays `BlackSite`, so saves don't change. A Prototype card is about twice a Field one: every stat is between 1.4 and 2 times better (`tests/cards_spec.luau` checks this). River, 2026-11-11: "higher rarity = better". It was 20 to 25% before. Perks are utility and never add damage.
- Fusion turns copies into one card of the next tier. The resulting tier is never random, and duplicates can never be turned into currency.
- Income pays only while the player is in the game.
- Variants add income, never combat power.
- Deck Power Rating never uses skill or win rate.
- A failed request changes nothing in the save.
- The modules in `src/shared/CardCore/` use no Roblox APIs. Randomness comes in as a function returning a number from 0 up to 1, so tests can fix it.

## Tiers

| Tier | Id | Colour | DPR points | Perk strength | Income per copy per second |
| --- | --- | --- | --- | --- | --- |
| Field | `Field` | Deep Navy | 100 | 50% | 0.1 Credits |
| Redline | `BlackSite` | Hazard Red | 112 | 75% | 0.6 |
| Prototype | `Prototype` | Signal Acid | 125 | 100% | 3.5 |

## The cards

All 6 are in set `set_01`. Stats are listed Field / Redline / Prototype.

| Card | Id | Stats | Cooldown | Perk |
| --- | --- | --- | --- | --- |
| Phase Dash | `phase_dash` | Distance 8 / 12 / 16 studs | 16 / 13 / 10s | Nearly invisible for 0.75 / 1.1 / 1.5s |
| Overclock | `overclock` | Fire rate +15 / 22 / 30% for 5 / 7 / 9s | 25s | None |
| Aegis Shell | `aegis_shell` | Shield 52 / 78 / 104 HP for 3 / 4 / 5s | 25s | Pushes nearby enemies away when it ends, at 50 / 75 / 100% strength |
| Switchback | `switchback` | Range 40 / 60 / 80 studs | 20 / 16 / 12s | None |
| Kickplate | `kickplate` | Launch height 24 / 36 / 48 studs | 14 / 12 / 10s | None |
| Siphon | `siphon` | Speed stolen 15 / 22 / 30% for 3 / 4.5 / 6s | 18s | None |

- **Phase Dash** was already strong at Prototype, so River had its lower tiers made worse instead of its top tier better.
- **Switchback** fires a tether the way you look. If it reaches an enemy, the two of you swap places and each keeps facing the way they were.
- **Kickplate** blasts the surface you aim at, if it is within 14 studs, and throws you straight away from that point. Aimed at your feet it sends you up by its height. With nothing in reach it does nothing and isn't spent.
- **Siphon** shoots a bolt the way you look. The enemy it hits is slowed and you are sped up by the same share. It does no damage.
- **Aimed cards are forgiving:** Switchback and Siphon hit the nearest enemy within 3 studs of your line of sight, with nothing solid in between. A miss brings the card back in 4 seconds, not its full cooldown.
- **The starter deck** is Phase Dash, Overclock and Siphon.
- **Recon Pulse was removed** on 2026-11-11, the same way as Arc Mine below: saves keep the copies, it leaves the deck, and it does nothing.
- **Effects are placeholders:** a cyan line for the tether, a red bolt for Siphon, a pale ring for the blast. No sounds or arm animations yet.
- Arc Mine was removed. Old saves keep their Arc Mine copies in case it returns, but it leaves the deck, the deck refills, and the copies earn nothing.
- Cards with one cooldown for every tier use a top-level `cooldown` field, because the ceiling test needs every `stats` entry to rise by tier.

## Using a card

- Key 3 (the default, `slot1`) pulls the cards out, starting on the first ready card, and puts them away again. With a card out, right click (the aim key) turns to the next ready card, round and round (`CardHand.cycle`). Keys 4 and 5 still go straight to the cards in slots 2 and 3 if they're ready.
- Each turn skips what's left of the flourish and plays a flip (`CardFlourish.turn`): the left thumb flips the deck's next card across and it lands face up, showing the new card, on top of the ones the right hand already holds. Using a card crushes the top one and the rest go back to the deck.
- Left click uses the held card. The gun can't fire while a card is out, or until that click is released.
- Cards are put away when you swap guns and in the Outpost.
- A cooldown starts when the card is used, even while its effect runs.
- Every card comes back ready on each spawn. Matches will reset them each round instead (see `matches.md`). Effects end at death.
- The server checks the slot number, that the player is alive, the zone and the cooldown (`Ability.luau`, `AbilityServer.server.luau`).
- In Studio only, T cycles between two test decks ({Phase Dash, Overclock, Recon Pulse} and {Aegis Shell, Phase Dash, Overclock}) and Y cycles the tier. These choices are never saved. Matches remove them.

## What each card does

- **Phase Dash:** the client asks, the server approves, then the client dashes. That costs one ping of delay, the first thing to revisit if dashes feel late. The dash is a launch (2026-11-11, not tried in Play; it used to place the body along a set path every frame, which River found steppy): the velocity is set once to the distance stat over 0.14s (93 to 114 studs a second; 65 to 80 at first, which River measured as "not enough") and physics carries it. It goes where the camera looks, up and down too, when only forward is held, and otherwise flat in the move direction (the flat camera direction when standing still); from the ground it always pops up a little. The running speed then eases back to the speed from before the dash (at least 24) over 3s, held near full at first and eased out at both ends (`MoveConfig.DashFadeTime`, `MoveState.speed`). The launch rides over whatever else the player does, through landings and jumps, and with no keys held it carries the player on along the ground while it is over 1.3 times sprint speed (the first version was cut to a 0.6s fade by the first landing and stopped dead with no keys, which River said felt like nothing). The movement check looks away for 3s. The camouflage (parts at 90% transparency) starts with the dash.
- **Overclock:** raises fire rate on both guns for its duration.
- **Recon Pulse:** marks the living enemies within the radius at the moment it's used, with a red highlight that shows through walls. Teams don't exist yet, so everyone else counts as an enemy and the teammate perk can't be tested.
- **Aegis Shell:** an 8-stud Data Cyan bubble that can't be shot or touched. While it's up, the shield takes every hit, head or body, and nothing reaches health. Damage beyond the shield's HP is lost, and an instant-kill headshot only breaks it. When it ends, by running out or breaking, enemies within 15 studs are pushed away at 48 / 54 / 60 studs per second and 35 upward. Dying ends it without a push. The push speed stays under the movement check's limit of 63.

## Collection

- **Copies** are stored per card, tier and variant, as keys like `phase_dash:Field:Base`.
- **Variants:** Base, Chromatic, Redacted and Zero-Day. They pay 1x, 1.5x, 2.5x and 5x income. The odds of a roll are 1/50 Chromatic, 1/500 Redacted and 1/5,000 Zero-Day; the rest are Base. Fusion and pack cards roll a variant at these odds. A Prototype pack and a Zero-Day pack's first card use their own, in `packs.md`.
- **Fusion:** 5 copies at one tier make 1 copy at the next tier. A Fusion Catalyst lowers that to 4. The fee is 100 Credits from Field and 600 from Redline, and a Catalyst doesn't lower it. Prototype can't be fused.
  - Checks run in this order, and a failed check changes nothing: unknown card, bad tier, top tier, no Catalyst, not enough copies, variants not confirmed, not enough Credits.
  - Base copies are spent first. Spending any variant needs the request to confirm it, because variants are the most valuable copies.
  - The new copy's variant is rolled.
  - If fusion spends the last copy of an equipped card at that tier, the deck slot moves up to the new tier.
  - Nothing gives Catalysts yet.
- **Income:** each copy pays its tier's rate times its variant's multiplier. Per card and tier, the first 10 copies pay in full, best-paying first, and copies past 10 pay half. Owning every card in a set adds 10% to all income. The server pays every second for loaded players, and one payment covers at most 5s, so a server stall can't pay a lump sum. Fractions of a Credit carry over. A new player earns 0.3 Credits per second.
- **Deck Power Rating (DPR):** the sum of the deck's tier points, plus 3 per gun upgrade level. Gun levels are always 0, so DPR runs from 300 (all Field) to 375 (all Prototype). Tier points of 100 / 112 / 125 follow the cards' real stat gains, so 1% DPR is about 1% power, and they can express the parent spec's lobby band of 10 to 15% higher DPR.
- **Deck:** exactly 3 different owned cards. New players get 1 Field copy each of Phase Dash, Overclock and Recon Pulse, equipped.

## Save data

`src/shared/CardCore/SaveData.luau`, saved with ProfileStore (`src/server/vendor/ProfileStore.luau`, from MadStudioRoblox at commit `45c9847`, Apache-2.0, licence in `licenses/`).

- Store `PlayerData_v1`, key `Player_<UserId>`. Session locking stops copies being duplicated across servers.
- **Version 6 fields:** `version`, `credits`, `creditRemainder`, `stacks`, `serials` (see `serials.md`), `market` (cards up for auction and Credits set aside in bids; see `auction-house.md`), `deck`, `gunLevels` (2 numbers), `catalysts`, `class`, `rifle`, `settings`, `commentsOff`, `packs`, `rebirths`, `openAllCredits`, `receipts`.
- **The fresh start:** a save from before version 5 is reset the first time it loads (River, 2026-11-11), keeping only settings, comments off, class, rifle, receipts and waiting Open All purchases. `serials.md` says why.
- **Loading** starts from a new save and copies in each valid field. A save from a newer version is never overwritten: the server ends the session and kicks the player with "This server is out of date. Please rejoin."
- **Corrupt values** reset to their default one field at a time: stack, pack, rebirth and Catalyst counts above 1,000,000, Credits above 2^53, gun levels above 100, unknown classes or rifles, and badly formed stack keys. Copies of unknown cards are kept, so a removed card can come back.
- **Deck repair:** each slot keeps its card, position and tier where it can. If the saved tier is no longer owned, the slot moves to the best tier owned. An empty slot takes the first unused owned card, then a starter card, which grants 1 Field copy with no serial. New players get their starter cards this way.

## Remotes

All in `ReplicatedStorage.CardCoreRemotes`. Each player gets 5 calls per second across all the functions there, including the pack, purchase, profile, comment and settings ones (`packs.md`, `outpost-ui.md`). Replies are `{ ok = true }`, with a `result` from `Fuse`, `SetDeck` and `GetSnapshot`, or `{ ok = false, code }`, with codes such as `RateLimited`, `NotLoaded` and `BadRequest`.

| Remote | Kind | Does |
| --- | --- | --- |
| `Fuse` | Function | Takes `{ cardId, tier, useCatalyst, includeVariants }` and returns the new copy |
| `SetDeck` | Function | Takes exactly 3 slots of `{ cardId, tier }` and returns the new snapshot |
| `GetSnapshot` | Function | Returns the current snapshot |
| `Snapshot` | Event, server to client | `{ credits, stacks, deck, catalysts, dpr, ratePerSecond, class, rifle, packs, rebirths, openAllCredits }`, sent on load, after each change and every 5s |

Requests go through `Requests.luau`, which drops bad types, NaN, extra fields and badly shaped tables without an error.

## What players see

- The HUD's ability rows: key, card name, tier in its colour and a 10-segment cooldown bar (see `hud.md`).
- Left hold: the first finger reaches out past the card's edge before curling round it (bends 5, 40, 70 degrees; the middle finger 5, 62, 45; the last two 5, 80, 25), because the hand lies at a slant and its joint falls short of the edge.
- Life: so it never plays the same twice, each hand drifts up to 0.012 studs and rolls up to 3 degrees on its own slow wander, with its cards (`CardFlourish.sway`; a card crossing between hands blends from one to the other), and the flourish runs up to 0.035s ahead of or behind itself (`CardFlourish.tempo`). Each time out starts at a random point in the wander.
- Print: the cards that are face up or turning over (from the top card to the first one flipped) get a `SurfaceGui` with the whole `CardFace` on it, so they carry their name, rarity and serial like the cards in the menus. The rest, and the blur copies, show only the baked image.
- Skip burst: turning to the next card before the flourish is done cuts it short, and a burst pops off the deck in the left hand for 0.32s (`SkipBurst.luau`, drawn by `CardView.snap`). It is flat and hard-edged like the HUD, with no soft particles: a Bone square outline that jumps outward in 8 beats and drops out for two of them, 8 dashes shot along the axes (Data Cyan) and diagonals (Signal Acid) that shorten to nothing, and 10 blocks of static flickering on a grid. Every piece is a flat unlit rectangle facing the eye.
- The cut: before the top half slides off, the left hand's fingers drop off the deck's right edge (`LEFT_RELEASE`) so the half passes over them, and they wrap back onto the bottom half once the right hand has lifted its half clear. The right hand comes for it from the right of the deck, leaning in (`SWOOP_GRIP`), so its arm stays clear of the left arm.
- Bend: the right hand bows the deck 40 degrees end to end toward its palm in the first 0.05s. Each card snaps straight as it springs off, whipping a little past flat before it lands flat. A bent card is shown as 4 strips along its length, each with its slice of the face and back (`CardFlourish.strips`, `CardView`); the flat card is put away while they show. Strips have square corners.
- Motion blur: while a card moves faster than 0.5 studs a second, three faint copies of it trail back over the last 0.03s of its path (`blur` in `CardView.luau`; cards moving as one stack share one trail), and two faint copies of the arms do the same (`ViewArms.blur`).
- The deck in hand (`CardView.luau`): 32 thin cards showing the player's own deck over and over, each cut at run time with the art's rounded corners (`GeometryService` in `CardView.luau`; square until that's done, and solid so the hands' outline can't show through), with the same back: a circuit grid on navy with one acid node, baked by `tools/make-card-back.py` and kept as `CardArt.HAND_BACK`, with the card in hand on top. Pulling a card out plays a 3.6s flourish (its keys run to 5.7s and play 1.6 times as fast) keyed in code (`CardFlourish.luau`): the deck springs from the right hand into the left, the left hand tips it and slides the top half off, the right hand pinches that half, spins it and fans it open about its thumb, then closes it and drops it back on. Every card is face down the whole way, so only backs show, and to finish the left thumb flips the top card (the one in hand) face up across to the right hand, which holds it up well clear of the left. Moves ease only half way into each key and the tracks are blended over 0.2s, so one move runs into the next. For weight, each thing that lands knocks its hand down and the hand rings back with its cards (`knock`): the left hand sinks as the deck piles in and is knocked when the half drops back on, the right hand kicks as the deck springs out and takes the cut, the spin stopping, the fan (which overshoots as it snaps open) and the caught card. The hands are placed as palms behind the cards, so only thumbs and fingertips come round to the front, and the fingers are keyed too: named shapes for each hand blended through the moves, each finger a touch behind the last. A click uses the card at any point: the right hand snatches its card and crushes it in a fist over 0.4s, the fist jolting as it shuts (`CardFlourish.crush`), the card shrinks away and bits of card and sparks burst out of the fist (`CardView.luau`), and then the gun comes back. Nothing plays for the switch itself: the gun is gone the moment a card comes out and back the moment the card is done, with no lowering or raising (the switch animations are to be reworked). Putting a card away unused skips the crush.
- Credits and income in the Outpost's top left (`IncomeLine.luau`).
- The Loadout page: DPR and the deck, with a card picker (`LoadoutPanel.luau`, see `outpost-ui.md`).
- The Profile page: Credits, DPR and the card index with copy counts (`ProfilePanel.luau`).
- Nothing shows Catalysts or fusion yet.

## Not built

- The player market and serialized seasonal cards.
- A fusion screen, ways to get Catalysts, gun upgrades, teams.

## Known issues

- A deck change or a fusion that moves a slot up doesn't reach the abilities until the next respawn, because the server reads the deck only when cards reset.
- The first `Snapshot` fires when the save loads. The listener (`CardData.luau`) connects later, which is the likely cause of the "no listener" console warning. Not verified.
