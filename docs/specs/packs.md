# Packs and rebirths

**Status:** built on 2026-11-07, waiting on River's check in Play. Purchases, the favorite and the group check can only be proven on a live game. Odds and prices are starting numbers to tune, in `src/shared/CardCore/Config.luau`.

**Covers:** rolling for packs, opening them, the pull reveal, auto roll, Robux purchases, rebirths and luck, the packs menu, and the income display. How cards work is in `cards.md`, and how they look is in `card-art.md`.

## The idea

Rolling and opening are free. Luck decides what you get, and it's the thing you work towards.

Cards earn Credits while you idle. Credits buy rebirths, and each rebirth raises your luck. Later, a player market lets lucky pulls be sold for Credits, which feeds more rebirths. Luck never affects combat.

## Rolling

- A roll is free and gives one pack. The roll decides the pack's rarity.
- A player can roll once every 3 seconds. The server enforces this and holds every result.
- Every player can roll by hand. See Auto roll for rolling while idle.

| Pack | Odds |
| --- | --- |
| Field | 80% |
| Redline | 16% |
| Prototype | 3.98% |
| Zero-Day | 0.02% (1 in 5,000) |

## Opening

Opening a pack is free and gives 3 separate cards. Unopened packs are stored as a count for each rarity, so a large pile costs nothing in the save.

A pack gives mostly its own rarity, with a small chance of each card being higher. The tier is rolled first, then the variant.

| Pack | Field | Redline | Prototype | Zero-Day variant |
| --- | --- | --- | --- | --- |
| Field | 90% | 9% | 1% | 1 in 5,000 |
| Redline | None | 88% | 12% | 1 in 5,000 |
| Prototype | None | None | 100% | 5% |
| Zero-Day, first card | 60% | 30% | 10% | Always |
| Zero-Day, other 2 cards | None | 60% | 40% | 1 in 5,000 |

- A Zero-Day pack gives exactly 1 guaranteed Zero-Day card. Its other 2 cards can still roll one at the normal odds.
- Chromatic and Redacted keep their odds of 1 in 50 and 1 in 500 on every card that isn't already Zero-Day.
- The card itself is picked evenly from the set.
- Credits and Catalysts never come from packs.

## Auto roll

- Auto roll rolls every 3 seconds while it's on. It's off each time a player joins. It's unlocked by favoriting the game or joining the Fridae Studios group.
- It only runs while the player is in the Outpost. It stops in matches, and there's no rolling offline.
- The server checks the group itself. It can't check a favorite, so it takes the client's word, and an exploiter could fake that. All they'd gain is auto roll.
- The favorite check uses `AvatarEditorService`, which Roblox doesn't officially support for experiences, so the group is the fallback if it breaks.
- River decided this knowing that Roblox's rules appear to ban rewards for favorites.
- The group has to be open for anyone to join.

## Robux

| Purchase | Type | Price | What it does |
| --- | --- | --- | --- |
| Open All | Developer product | 1,500 Robux for each use | Opens the player's whole pile once |
| Auto Open | Gamepass | 100 Robux, once | Works through the player's pile, showing rare pulls only |

- Auto Open opens one pack every 2 seconds while the player is in the Outpost, starting with the commonest rarity. It clears existing piles as well as new packs.
- That's only a little faster than auto roll adds packs, so a big pile takes hours of idling. Open All clears it at once, which is its use later on.
- Free players open packs one at a time. The `OPEN ALL` button prompts the purchase.
- If the pile is empty when an Open All purchase lands, because Auto Open got there first, the purchase is saved as `openAllCredits`. The player is told, the button reads `OPEN ALL X1`, and the next click on a pile spends it without a prompt.
- A rarity's pile stops at 1,000,000 packs, and rolling that rarity does nothing until it's opened. A card stack stops at the same limit.
- `Config.OpenAllProduct` and `Config.AutoOpenPass` are 0 until River creates them, and their buttons read `SOON`.
- The server opens the pile only once Roblox's `ProcessReceipt` reports the payment, and accepts the payment only once the save has landed. A repeated receipt never opens anything twice.
- The odds are always shown in the menu, and its `ODDS` button shows the card odds as well. `PolicyService` hides Open All where paid random items are restricted.

## Rebirths and luck

- A rebirth costs all of the player's Credits, and they must hold at least its price. Cards, decks and packs are kept.
- The first costs 25,000 Credits, and each one after costs 2.5 times the last.
- The button needs a second click, `CONFIRM REBIRTH`, within 3 seconds.
- Luck is `1 + 0.15 x rebirths`. Rebirths have no limit.
- Luck multiplies every outcome above the commonest one, in the pack roll and in each card roll. The commonest outcome takes what's left, and stops at 0. If the raised outcomes pass 100%, they're cut back evenly to total 100%.
- Guaranteed outcomes don't change.
- With 5 rebirths, luck is 1.75 and a Zero-Day pack is about 1 in 2,857.

## The packs menu

A new `PACKS` row joins the nav. The Market stall's prompt opens the same menu until the player market exists.

From top to bottom:

- The `PACKS` title.
- A line with luck, income and rebirth count.
- A big `ROLL` button, with `AUTO ROLL` beside it, and a bar for the wait until the next roll. Before it's unlocked, `AUTO ROLL` prompts the favorite.
- The four packs, large and almost touching, each with its count and roll odds. Hovering lifts a pack, and clicking opens one.
- `OPEN ALL`, `AUTO OPEN` and `ODDS`, then the rebirth button, which shows its price.

## Pack designs

Packs are vertical foil wrappers with crimped ends, in the same colours as the cards, in the proportions 150 by 230.

Each has a large `S1` reading up the wrapper, an outline and a strip of hazard stripes in the rarity's colour, and its name near the bottom. `S1` is the set. `tools/make-pack-art.py` bakes the wrapper, and `src/client/PackFace.luau` draws the name, stripes and effects.

| Pack | Background | Art and outline | Effect |
| --- | --- | --- | --- |
| Field | Deep Navy | Bone | A soft shine |
| Redline | Bone | Hazard Red | A strong shine, with a pulsing red edge |
| Prototype | Signal Acid | Deep Navy | A shine, with scrolling stripes |
| Zero-Day | `#0E1018` | Data Cyan | A shine with a blue foil band, and a cyan ring pinging from the corner |

## Pull reveal

This hasn't been mocked up. River judges it in Play. A rare pull is a Prototype or any variant.

- **One pack:** clicking a pack plays the whole opening by itself, held up in 3D beside the menu, where an inspected card sits. The nav and income line fade out first, and fade back after `DONE`. The pack spins in and shakes, the strip down its right side peels off, light in the colour of the best card shows at the tear, and the cards slide out of the side. They spread out face down on the pack's own back design, with the best card in the middle, and shake for as long as the best card needs. All 3 then turn over at once. The menu stays usable, and opening another pack once this one has finished moves straight on to it.
- **Rare cards:** a Redline or better flashes the screen in the best card's colour when the cards turn.
- **Zero-Day:** the world dims further and the flash is brightest.
- **Particles:** the best card picks them, with a burst at the rip, one from each card at the flip, and a steady trickle until `DONE`. Field gets drifting flecks, Redline red sparks, Prototype acid pixels that move in jumps, Chromatic confetti, Redacted sliding black bars, and Zero-Day cyan rain.
- **Open All:** each rare stack shows until clicked, with `SKIP` to pass the rest, then a list of everything that arrived.
- **Auto Open:** a rare pull plays by itself beside the middle of the screen and leaves after 4 seconds. The world stays usable, so an idle player's screen never blocks. Only 3 can wait at once and the rest aren't shown, except a Zero-Day, which always is. A pack the player opens goes first.

The cards can be inspected in 3D like any other.

## Income display

A small line in the Outpost HUD, top left, shows Credits and income, like `+3.4 CR/S`. It uses `ratePerSecond` from the card snapshot.

## Saves

The save moves to a new version with `packs`, a count for each rarity, and `rebirths`, both starting at 0.

## What this changes elsewhere

- **Fusion** keeps its Credit fee, as a way to take Credits out of the game.
- **Variant odds:** `cards.md` says only fusion rolls a variant. Packs now do too.
- **Income:** 60 cards a minute is possible, so the rule that halves income past 10 copies matters far more. It may need tuning.
- **Serials:** `card-art.md` gives every copy its own save record, which can't survive 60 cards a minute. That has to change before serials are built. One likely fix is giving serials only to rarer cards or variants.

## Order of work

1. This spec: rolling, opening, the packs menu, pack art, the reveal, purchases, rebirths and the income display.
2. Serial numbers, with the change above.
3. The player market, in its own spec. It needs trades that can't duplicate or lose cards, and listings shared across servers.

River creates the gamepass and developer product on Creator Hub, and opens the group.

## Tests

Pack and card odds, luck, the Zero-Day guarantee, the roll timer, rebirth prices, and what a rebirth keeps are pure rules tested in Lune. River judges the look and the reveal in Play.
