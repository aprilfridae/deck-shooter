# Auction House Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the rules and server for card auctions: listing, bidding, Buy Now, ending and settling, with no way to copy or lose a card or a Credit.

**Architecture:** Nothing moves between two saves. A listed card and a bid's Credits live in their owner's save under the auction's id; one DataStore record per auction says who is winning; each save settles its own side by comparing its entry with the record. All of that deciding is one pure module, `Auction.luau`, tested in Lune. Two server modules do the Roblox calls: `AuctionStore.luau` (records, browsing map, announcements) and `AuctionServer.luau` (requests and checks).

**Tech Stack:** Luau (Roblox, Rojo), ProfileStore saves, DataStoreService `UpdateAsync`, MemoryStoreService sorted maps, MessagingService, Lune tests.

**Spec:** `docs/specs/auction-house.md` (read it first). It builds on `docs/specs/serials.md`.

## Global Constraints

- Branch `feature/auction-house`, cut from `feature/serials`, in `H:\SplitDeck`. Rojo serves this folder live; don't restart it. Never edit scripts through the Studio MCP and never start or stop Play: River does all Play testing.
- Checks before every commit, from `/h/SplitDeck`: `lune run "$TEMP/sd/compile.luau" | tail -1`, `lune run "$TEMP/sd/globals.luau" | tail -1`, `lune run "$TEMP/sd/consts.luau" | tail -1`, `lune run tests/run.luau | grep -E "^FAIL|expected|passed"`.
- Commit messages end with `Co-Authored-By: Claude Fable 5.2 <noreply@anthropic.com>`. Never commit `assets/`, place files or keys.
- **The one ordering rule:** a save change that takes something from a player (a card into a listing, Credits into a bid) must be written to the data store (`PlayerCards.saveAndWait`) before the shared record is told. A save change that gives something (a won card, a sale's Credits, a returned card) must be written before the record is marked done for that side. Break this and a crash copies or loses things.
- Spec values, exact: lengths 1, 6 or 24 hours; next bid at least 5% over the current bid and at least 1 more (rounded up); a bid in the last 120 seconds moves the end to 120 seconds after it; 10 listings and 20 open bids per player; prices are whole Credits from 1 to `Config.MaxCredits`; no market cut.
- Save version becomes 6. Record store `Auctions_v1`. Time is `DateTime.now().UnixTimestamp`, passed into the rules as `now`.
- Comments say why, in plain words, and name River and the date where a choice was theirs.

## Review Focus

1. A check runs on a bid while that bid's own request is still waiting on the data store. It must not refund Credits that are about to win.
2. The same check runs twice in a row, or on two loads, for a won auction, a sold auction and an unsold one. The card and the Credits arrive exactly once.
3. A buyer bids far above Buy Now. They pay Buy Now, not their bid.
4. The winner or seller doesn't come back for a long time. The other side still settles, and the late one settles correctly when they do.
5. A request's numbers are hostile: fractions, negatives, NaN, huge values, a serial the player doesn't hold, an auction id that doesn't exist.

Tests for 2 to 5 are in Tasks 1 to 3 and 5. Number 1 is enforced in Task 5 and checked by reading.

---

### Task 1: The save's market entries

**Files:**
- Modify: `src/shared/CardCore/Inventory.luau`, `src/shared/CardCore/SaveData.luau`, `src/shared/CardCore/Rebirth.luau`
- Test: `tests/inventory_spec.luau`, `tests/savedata_spec.luau`, the rebirth spec (`grep -l "Rebirth.perform" tests`)

**Interfaces:**
- `Inventory.give(data, key: string, serial: number): boolean` — adds one copy to the stack holding exactly this serial. False, changing nothing, if the stack already holds it or is at `MaxStackCount`.
- Save gains `market: { listed: { [id]: Listed }, bids: { [id]: Bid }, settled: { [id]: true } }` where `Listed = { cardId, tier, variant, serial, startBid, buyNow: number?, endsAt, live: boolean }` and `Bid = { amount: number, endsAt: number }`. `SaveData.new()` has all three empty. `CURRENT_VERSION = 6`; a version 5 save loads with empty entries and is otherwise untouched.
- `Rebirth.perform` returns `false, "BidsOpen"` when `data.market.bids` has any entry.

- [ ] **Step 1: Write the failing tests.**
  - `give`: on a stack holding `{ 1, 2, 4, 5 }`, `give(data, key, 3)` is true and the runs are `{ 1, 5 }`, count 5; `give(data, key, 3)` again is false; giving to a missing stack creates it with count 1 and runs `{ 9, 9 }`; a stack with waiting copies keeps them waiting.
  - Save: `SaveData.new().market` equals `{ listed = {}, bids = {}, settled = {} }`. A version 5 save with credits 40 and a numbered stack loads as version 6 with both kept and an empty market. A version 6 save keeps well-formed entries. Cleaning drops, without error: a listed entry with a bad card id, tier or variant, a serial below 1 or not whole, `startBid` below 1, `buyNow` not above `startBid`, a missing `endsAt`; a bid whose amount is 0, negative, fractional or above `MaxCredits`; a `settled` value that isn't `true`; non-string ids; and a `market` that isn't a table. More than 10 listed or 20 bids are all kept (they hold real cards and Credits; the limit is on making new ones).
  - Rebirth: with enough Credits and one bid entry, `perform` returns `false, "BidsOpen"` and changes nothing; with none it works as before.
- [ ] **Step 2: Run the tests.** Expected: the new ones fail.
- [ ] **Step 3: Implement.** `give` is `add` one copy then `number(data, key, serial, serial)`, undone if numbering returns 0.
- [ ] **Step 4: Run the checks. Commit** "Save version 6: hold listed cards and bids in the save".

---

### Task 2: Listing and bidding rules

**Files:**
- Create: `src/shared/CardCore/Auction.luau`
- Test: `tests/auction_spec.luau` (add to both lists in `tests/run.luau`)

**Interfaces:**
- `Record = { id: string, seller: number, sellerName: string, cardId: string, tier: string, variant: string, serial: number, startBid: number, buyNow: number?, endsAt: number, bid: number?, bidder: number?, bidderName: string?, cancelled: boolean?, sellerDone: boolean?, winnerDone: boolean? }`
- `Auction.LENGTHS = { 1, 6, 24 }`, `Auction.MAX_LISTED = 10`, `Auction.MAX_BIDS = 20`, `Auction.LATE_SECONDS = 120`, `Auction.RAISE = 0.05`.
- `Auction.canList(data, req: { cardId, tier, variant, serial, startBid, hours, buyNow: number? }): (boolean, string?)` — reasons: `"BadRequest"` (wrong types, unknown card, tier or variant), `"BadLength"`, `"BadPrice"`, `"NotOwned"` (the stack doesn't hold that serial), `"InDeck"` (it is the only copy of that card and tier across every variant, and the deck has that card and tier), `"TooManyListings"`.
- `Auction.list(data, id: string, req, now: number): Listed` — takes the serial out with `Inventory.take`, stores the entry with `live = false` and `endsAt = now + hours * 3600`, returns it. Call only after `canList`.
- `Auction.record(id: string, seller: number, sellerName: string, listed: Listed): Record`
- `Auction.ended(record: Record, now: number): boolean` — cancelled, or `now >= endsAt`.
- `Auction.minBid(record: Record): number` — `startBid` with no bid; otherwise `math.max(bid + 1, math.ceil(bid * 1.05))`.
- `Auction.price(record: Record, amount: number): number` — what this bid costs: `buyNow` when there is one and `amount >= buyNow`, else `amount`.
- `Auction.canBid(data, userId: number, record: Record, amount: number, now: number): (boolean, string?)` — reasons: `"BadRequest"`, `"Ended"`, `"OwnListing"`, `"AlreadyHighest"`, `"TooLow"`, `"TooManyBids"` (20 entries and none for this auction), `"NotEnoughCredits"` (the price, less anything already held for this auction, is more than `data.credits`).
- `Auction.hold(data, id: string, price: number, endsAt: number)` — moves Credits so the bid entry holds exactly `price`: takes the difference from `data.credits` when an older, lower entry for this auction exists.
- `Auction.accept(record: Record, userId: number, name: string, amount: number, now: number): Record?` — the new record, or nil if this bid can't be taken now (ended, cancelled, own listing, already highest, below `minBid`). Sets `bid` to `Auction.price`, the bidder and name; Buy Now sets `endsAt = now`; otherwise a bid with `endsAt - now <= 120` sets `endsAt = now + 120`. Never changes its argument (UpdateAsync may call it twice).
- `Auction.cancel(record: Record, userId: number, now: number): Record?` — a copy with `cancelled = true`, or nil unless the caller is the seller, there is no bid and it hasn't ended.

- [ ] **Step 1: Write the failing tests,** one `it` per reason in `canList` and `canBid`, plus:
  - Review Focus 5: `canList` and `canBid` return `"BadRequest"` for a fraction, a negative, `0/0`, `math.huge` and a string in every numeric field, and `"BadPrice"` for a price above `Config.MaxCredits`.
  - `list` on a stack with serials 3 to 5: listing 4 leaves runs `{ 3, 3, 5, 5 }`, count 2, and an entry with serial 4, `live = false`, `endsAt = now + 6 * 3600` for 6 hours.
  - `minBid`: 100 with no bid and `startBid` 100; 106 after a bid of 100; 11 after 10; 2 after 1.
  - Review Focus 3: with `buyNow = 500`, `price(record, 9000)` is 500, and `accept(record, 2, "B", 9000, now)` gives `bid = 500`, `endsAt = now`.
  - `accept`: a bid 30 seconds before the end moves `endsAt` to `now + 120`; a bid an hour before leaves it; a second bid of 105 over 100 returns nil; the record passed in is unchanged after every call.
  - `hold`: with 1000 Credits, `hold(data, id, 300, e)` leaves 700 and an entry of 300; then `hold(data, id, 450, e)` leaves 550 and an entry of 450.
  - `cancel`: nil for a stranger, nil once there is a bid, nil after the end.
- [ ] **Step 2: Run. Expected: fail. Step 3: Implement. Step 4: Run the checks. Expected: pass.**
- [ ] **Step 5: Commit** "Add the auction rules for listing and bidding".

---

### Task 3: Settling rules

**Files:**
- Modify: `src/shared/CardCore/Auction.luau`
- Test: `tests/auction_spec.luau`

**Interfaces:**
- `Auction.settle(data, userId: number, id: string, record: Record?, now: number): string` — does whatever is due for this save's entries under `id`, and says what it did:
  - Listed entry, no record: `live == false` → `"Publish"` (the caller creates the record; nothing changes here). `live == true` → the card goes back with `Inventory.give`, the entry goes → `"Returned"`.
  - Listed entry, record not ended → `"Wait"`. Record ended with a bidder → entry goes, `data.credits` rises by `record.bid` capped at `Config.MaxCredits` → `"Paid"`. Ended with no bidder, or cancelled → card back, entry goes → `"Returned"`.
  - Bid entry, no record → Credits back, entry goes → `"Refunded"`. Record names another bidder → the same. Record names this player with a bid lower than the entry holds → the difference comes back and the entry is lowered → `"Wait"` if not ended.
  - Bid entry, record ended, this player is the bidder → if `record.winnerDone` or `data.market.settled[id]`: entry goes, nothing is given → `"Done"`. Otherwise the card arrives with `Inventory.give`, `settled[id] = true`, entry goes → `"Collected"`.
  - No entry of either kind → `"None"`.
- `Auction.finish(record: Record, side: "seller" | "winner"): Record?` — a copy with that side marked done; nil (delete the record) when the seller is done and there is no bidder, or both are done.
- `Auction.cleared(data, id: string)` — drops `settled[id]`; called once the record is known to say `winnerDone`.

- [ ] **Step 1: Write the failing tests.** Build each case from real calls (`list`, `hold`, `accept`) so the saves are ones the rules themselves produced:
  - Won: seller and winner saves plus an ended record. Winner settles → `"Collected"`, holds the serial, Credits not returned. Seller settles → `"Paid"`, Credits up by the bid, no card.
  - Review Focus 2: each of those run a second time returns `"Done"` or `"None"` and changes nothing. A winner save reloaded from before the collect but with `record.winnerDone = true` returns `"Done"` and gains nothing.
  - Unsold: the seller settles an ended record with no bid → `"Returned"`, the same serial back in the stack; again → `"None"`.
  - Cancelled: the same through `cancel`.
  - Outbid: bidder A's save against a record naming B → `"Refunded"`, Credits whole again; again → `"None"`.
  - Crash after listing, before the record: `settle(data, 1, id, nil, now)` with `live = false` → `"Publish"`, save unchanged. With `live = true` → `"Returned"`.
  - Crash after holding, before the record took the bid: the record still names the previous bidder → `"Refunded"`.
  - Review Focus 4: the seller settles `"Paid"` and `finish(record, "seller")` keeps the record; months later (`now` far past) the winner settles `"Collected"` and `finish(..., "winner")` returns nil. The other order too.
  - Totals: in every case above, count the copies of the serial across both stacks and both listed entries, and the Credits across both balances and bid entries, before and after: one copy always, and Credits unchanged except by nothing (no cut, so the total is constant).
- [ ] **Step 2: Run. Expected: fail. Step 3: Implement. Step 4: Run the checks.**
- [ ] **Step 5: Commit** "Add the auction rules for settling each side".

---

### Task 4: The shared store

**Files:**
- Create: `src/server/AuctionStore.luau`

**Interfaces** (all yield; all return nil or false on failure after a `warn`, never throw):
- `AuctionStore.read(id: string): (boolean, Record?)` — ok, and the record or nil if there is none.
- `AuctionStore.create(record: Record): boolean` — `UpdateAsync` that writes only if the key is empty; true if the record is there afterwards with this seller.
- `AuctionStore.change(id: string, transform: (Record?) -> Record?): (boolean, Record?)` — `UpdateAsync`; `transform` returning nil leaves the record alone. Answers ok and the record as stored after the call.
- `AuctionStore.remove(id: string): boolean`
- `AuctionStore.show(record: Record)` and `AuctionStore.hide(record: Record)` — put or drop the summary `{ id, cardId, tier, variant, serial, price, buyNow, endsAt, sellerName }` (price is `bid or startBid`) in the MemoryStore sorted map `Auctions_<cardId>`, sort key `endsAt`, expiry `endsAt - now + 300` seconds (at least 60).
- `AuctionStore.browse(cardId: string): { any }?` — up to 200 summaries, soonest first.
- `AuctionStore.announce(id: string)` and `AuctionStore.heard: RBXScriptSignal` — MessagingService topic `Auctions`; the signal fires with the id on every server, including the one that announced.
- When `ProfileStore.DataStoreState` is `"NoAccess"` or `"NoInternet"` every call uses module tables instead, and `announce` fires `heard` directly. Same reasoning and comment as `SerialCounter.luau`.

- [ ] **Step 1: Read** `src/server/SerialCounter.luau` for the pattern.
- [ ] **Step 2: Write `AuctionStore.luau`.**
- [ ] **Step 3: Run the checks. Commit** "Add the auction store: records, the browsing map and announcements".

---

### Task 5: Requests and checks

**Files:**
- Create: `src/server/AuctionServer.luau`
- Modify: `src/shared/CardCore/Requests.luau`, `src/server/PlayerCards.luau` (snapshot), `src/server/CardCore.server.luau` (start it and register remotes), `src/server/PackServer.luau` only if the rebirth remote needs the new reason passed through
- Test: the requests spec (`grep -l "Requests.parse" tests`)

**Interfaces:**
- `Requests.parseListing(raw: any): { cardId, tier, variant, serial, startBid, hours, buyNow: number? }?` and `Requests.parseBid(raw: any): { id: string, amount: number }?` — nil for anything that isn't exactly the right shape and types (strings bounded to 64 characters). They check shape only; `Auction` checks meaning.
- Remotes, registered with the `remote(name, handler)` helper in `CardCore.server.luau`, each answering `{ ok = true, ... }` or `{ ok = false, code = reason }`:
  - `ListCard` — parse; `canList`; `id = HttpService:GenerateGUID(false)`; mark the id busy; `Auction.list`; `PlayerCards.changed`; `saveAndWait` (on failure put the card back with `Inventory.give`, drop the entry, answer `"SaveFailed"`); `AuctionStore.create`; on success set `live = true`, `show`, `announce`; clear busy. If `create` fails the entry stays with `live = false` and a later check publishes it.
  - `PlaceBid` — parse; `read` (missing → `"Gone"`); `canBid`; mark busy; `hold` the price; `changed`; `saveAndWait` (on failure undo the hold, `"SaveFailed"`); `AuctionStore.change(id, accept)`; if the stored record doesn't name this player at this price, run `Auction.settle` to return the Credits and answer `"TooLow"` with `min = Auction.minBid(stored)`; otherwise `show`, `announce`. Clear busy.
  - `CancelListing` — `change(id, cancel)`; if cancelled: `hide`, `announce`, then check that entry.
  - `BrowseAuctions` — a valid card id → `{ ok = true, auctions = ... }` from a 10-second per-card cache of `AuctionStore.browse`.
  - `MyAuctions` — the save's `market.listed` and `market.bids`.
- **Busy ids (Review Focus 1):** a module table of `player → { [id] = true }`, never saved. `check` skips a busy id. It is cleared in a `finally`-style path so an error can't leave an id busy.
- `check(player, id)` — skip if busy; `read`; on a failed read do nothing; `Auction.settle`; then by its answer:
  - `"Publish"` → `create`, set `live = true`, `show`.
  - `"Paid"` or `"Returned"` → `changed`, `saveAndWait`, then `change(id, finish seller)` (delete when it returns nil-to-delete), `hide`.
  - `"Collected"` → `changed`, `saveAndWait`, then `change(id, finish winner)`, then `Auction.cleared`.
  - `"Done"` → `Auction.cleared` if the record says `winnerDone`.
  - `"Refunded"` → `changed`.
  - One check per player per id at a time.
- When checks run: every entry when a save loads (spaced 0.5 seconds apart); the entry named by `AuctionStore.heard` for every loaded player who holds it; any entry whose `endsAt` has passed, looked at by a loop every 5 seconds and retried at most every 30 seconds; every entry every 300 seconds.
- `PlayerCards.snapshot` gains `market = { listed = data.market.listed, bids = data.market.bids }`.

- [ ] **Step 1: Write the failing parser tests** (Review Focus 5): good shapes parse; each of a missing field, a string where a number belongs, a fraction, a negative, `0/0`, `math.huge`, a 65-character id, a table for an id, and extra nesting returns nil.
- [ ] **Step 2: Run. Expected: fail. Step 3: Implement the parsers. Run. Expected: pass.**
- [ ] **Step 4: Write `AuctionServer.luau`** and wire it in.
- [ ] **Step 5: Read it against the ordering rule** in Global Constraints, request by request, and against Review Focus 1. Write each path's order as a comment above the handler.
- [ ] **Step 6: Run the checks. Commit** "Run auctions on the server: requests, checks and settling".

---

### Task 6: A walkthrough River can run, and docs

**Files:**
- Create: `src/server/AuctionWalk.luau`
- Modify: `docs/specs/auction-house.md` (status), `docs/specs/cards.md` (save fields, remotes), `docs/HANDOFF.md`

**Interfaces:**
- `AuctionWalk` returns a function. In Studio's command bar during Play: `require(game.ServerScriptService.CardCoreServer.AuctionWalk)()`. It refuses outside Studio. Using the first loaded player and their lowest-numbered card, it prints each step and what the save holds after it:
  1. Lists the card for 1 hour at 1 Credit, shows the record, then cancels it and shows the card back with its serial.
  2. Lists it again with Buy Now at 10 Credits; a stand-in bidder (user id 0, a save kept in memory) buys it; shows the seller paid 10 and the card gone from the seller.
- It says in its first printed line that step 2 gives the tester 10 Credits from nowhere and removes one card, in Studio only.

- [ ] **Step 1: Write `AuctionWalk.luau`** using `AuctionServer`'s own request functions, exposed for it, not copies of them.
- [ ] **Step 2: Update the docs:** what was built, the save's version 6 fields, the five remotes, and under "not checked": nothing run in Play beyond the walkthrough, and two servers bidding on one auction.
- [ ] **Step 3: Run the checks. Commit** "Add an auction walkthrough for Studio and update the specs".
- [ ] **Step 4: Hand to River:** the command to paste, what each printed line should say, and that their save loses one card and gains 10 Credits.
