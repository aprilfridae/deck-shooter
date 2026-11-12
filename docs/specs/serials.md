# Serials

**Status:** built on 2026-11-11 on `feature/serials`, and passing its tests. Not yet seen in Play, and the two-server case has not been tried. This is the first of three pieces of the player market: serials, then the auction house, then the market screen. It replaces the "Serial numbers" section of `card-art.md`.

**Covers:** giving every pulled card a real serial, how serials are stored and handed out, and the fresh start that comes with them. How a serial looks on a card is in `card-face-redesign.md`.

## Why

The market sells one exact copy of a card, like "Aegis Shell, Zero-Day, serial 04". Today a save only holds how many of each card a player owns. Serials make each copy its own thing, and make low numbers worth chasing.

Success is: a card pulled on any server gets the next number for its kind, no number is ever given twice, and a player's low serials survive fusion and Open All.

## What a serial is

- Every card that comes from a pack, a pile or a fusion gets a serial.
- Serials count separately for each card, tier and variant. A Zero-Day Aegis Shell `01` and a Field Aegis Shell `01` can both exist. A Field Zero-Day and a Redline Zero-Day count separately too.
- The first one made is 1, the next 2, across every server.
- A serial never changes and is never reused, even when its copy is spent.
- Numbers can be skipped. If a server stops between taking numbers and saving them, those numbers are gone. That is rare and accepted; a number is never given twice.

## The fresh start

River chose a full reset so every serial is earned from a pull.

- Saves move to version 5. A save from any earlier version is reset the first time it loads.
- **Reset:** cards, deck (back to the starter deck), Credits, rebirths, unopened packs, gun levels and catalysts.
- **Kept:** settings, whether comments are off, class and rifle, Robux receipts already handled, and Open All purchases still waiting for a pile. Profile comments live in their own store and aren't touched.
- The reset happens once per save. There is no way to undo it, so this ships only when River says so.

## Starter cards

Every new player gets the three starter cards. If those were numbered, the first ten people to join after the reset would hold 01 to 10 of each for doing nothing.

- Starter copies never get a serial. They show `----`.
- They can't be listed in the market.
- They are the first copies fusion spends.

## How numbers are handed out

- **The counter:** one shared record for the whole game holds the next number for every kind of card. Servers change it with `UpdateAsync`, which can't lose an update when two servers write at once.
- **A pulled card is usable at once.** It is added to the save as an unnumbered copy and can go in the deck, earn Credits and be fused straight away.
- **Numbers arrive in batches.** Every 5 seconds a server asks the counter once for all the numbers its players are waiting on, then writes them into their saves. Asking on every pull would break Roblox's limits: a player opens a pack every 2 seconds, and a server may write about 10 times a minute per player.
- **If the counter can't be reached,** copies stay unnumbered and the server tries again on its next batch. A save that loads with unnumbered copies joins the next batch too, so a crash or a leaving player loses nothing.
- **Open All** gives a pile of any size one run of numbers per kind of card, in one batch.
- **In Studio without API access,** saves live in memory, so the counter does too.
- **In Studio with API access,** saves are real, so pulls there take real numbers from the real counter, exactly as in the live game. River's pulls while testing count.

A copy that is waiting for its number can't be listed in the market. In normal play that is a few seconds.

## How serials are stored

A player can own millions of copies, so a save can't hold one record per copy.

- Each stack (card, tier, variant) holds: its numbered copies as runs of serials, like 120 to 5,000; a count of copies waiting for a number; and a count of starter copies.
- Runs are kept sorted and joined where they touch. Taking one serial out of a run splits it.
- A stack's size is the three added together, so income, Deck Power Rating and the deck go on working by card, tier and variant as they do today.
- A save that claims the same serial twice in one stack, or a run that goes backwards, is treated as damaged like any other bad save data: the bad runs are dropped.

## Rules that follow

- **Which serial a card shows:** the lowest serial the player owns of that card, tier and variant. That is what the Loadout, the card in hand and inspecting a card show. If they own only unnumbered copies it shows `----`.
- **The Profile index** still shows the copy count where the serial goes.
- **The pull reveal** shows each pulled card's own serial. The server sends the cards at once and the serials when the batch comes back; the reveal fills each one in when it arrives, and shows `----` until then.
- **Fusion** spends starter copies first, then copies waiting for a number, then the highest serials, so the lowest numbers are the last to go. The fused card is a new copy and gets a new number.
- **Long serials:** up to seven digits fit beside the longest card name. From eight digits the serial is drawn smaller to fit.
- **The Studio stand-in serials** (`CardLook.studioSerial`) are deleted.

## What could go wrong

- **Too many servers writing one record.** Every server writes the counter every 5 seconds while its players are pulling. If the game grows to where those writes queue up, the counter is split into one record per card. The code keeps that change in one place.
- **A number given but not saved.** The server takes numbers, then the save write fails or the server dies. The numbers are skipped, never reused. The copies are still in the save as waiting, and get new numbers later.
- **Two servers holding one save.** ProfileStore's session lock already prevents this, and serials rely on it.
- **The reset is permanent.** It is tested on a copy of a real save before it ships.

## How it's built

- A save keeps `stacks` as plain counts, as before, and adds `serials`: for each stack, its runs as a flat list of pairs and its count of starter copies. Copies that are neither are waiting.
- The counter is DataStore `SerialCounters_v1`, key `all` (`SerialCounter.luau`). `SerialBatch.luau` holds the batching rules and `SerialServer.luau` runs the 5-second round.
- The client's snapshot carries `lowest`, each stack's lowest serial. A pulled card's own serial comes in a `Serials` pack event matched to its `Opened` event by `openId`; the card's face redraws its serial when its `Serial` attribute is set.
- `Inventory.luau` keeps its job, the stacks in a save, and gains the runs: adding unnumbered copies, giving waiting copies a run of numbers, taking a single serial out, and reporting a stack's lowest serial. `count`, `add` and `remove` keep meaning what they mean today, so `Income`, `Dpr`, `Deck` and `CardIndex` don't change.
- `SaveData.luau` moves to version 5, does the reset, and cleans runs on load.
- A new pure module holds the batching rules: which stacks are waiting, how many numbers to ask for, and how to share out what came back.
- A new server module owns the counter and the 5-second batch. `PackServer.luau`, the Open All purchase and fusion don't talk to the counter themselves; they add unnumbered copies and the batch does the rest.
- `PlayerCards.luau` tells the batch when a save loads.
- A new remote message carries serials to the client when they arrive.
- `CardFace.luau` and its callers pass the real serial in `options.serial`.

## Order of work

1. Runs in `Inventory`, and fusion's spending order. Pure rules, tested.
2. Save version 5 and the reset. Tested with made-up old saves.
3. The counter and the batch on the server.
4. Serials on screen: Loadout, hand, inspect and the pull reveal. River checks in Play.

## Tests

Lune tests cover the pure rules: adding, numbering and taking copies; joining and splitting runs; the lowest serial; fusion's order; the reset from each old version, keeping what must be kept; cleaning damaged runs; and sharing out a batch, including a batch that comes back short or not at all. The counter's use of `UpdateAsync` and the look on screen are checked in Play by River, with two players for the cross-server case.
