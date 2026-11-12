# Market Screen Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the `MARKET` page of the Outpost menu: a searchable, sortable wall of cards for sale, a bid box, selling, your own auctions, and lines that tell you what happened.

**Architecture:** Everything the screen decides without Roblox (search, sort, formatting, the words for each refusal) is one pure module, `Market.luau`, tested in Lune. The auction house's browsing list becomes one compact list for every card. `MarketPanel.luau` draws the page from `PanelKit`, `CardFace` and a small grid of its own, and talks to the server only through `CardData.ask`.

**Tech Stack:** Luau (Roblox, Rojo), the existing Outpost menu modules, Lune tests.

**Spec:** `docs/specs/market-screen.md` (read it first). The mockup is `assets/preview/market-mockup.html`. Auction rules: `docs/specs/auction-house.md`.

## Global Constraints

- Branch `feature/market-screen` in `H:\SplitDeck`. Rojo serves this folder live; don't restart it. Never edit scripts through the Studio MCP and never start or stop Play: River does all Play testing.
- Checks before every commit, from `/h/SplitDeck`: `lune run "$TEMP/sd/compile.luau" | tail -1`, `lune run "$TEMP/sd/globals.luau" | tail -1`, `lune run "$TEMP/sd/consts.luau" | tail -1`, `lune run tests/run.luau | grep -E "^FAIL|expected|passed"`.
- Commit messages end with `Co-Authored-By: Claude Fable 5.2 <noreply@anthropic.com>`. Never commit `assets/`, place files or keys.
- The page is Bone with Deep Navy text, from `PanelKit.PAPER` and `PanelKit.INK`. The only other colours are Hazard Red for a timer in its last 2 minutes and the cards themselves. No green.
- The market's own buttons and boxes have rounded corners (6 pixels at a 1080-high screen, scaled with the unit). The menu's rows don't change.
- Sizes and places are shares of `MenuPanel.unit()`, as in every other panel. The page runs from `PanelKit.MARGIN` (0.025) to `PanelKit.RIGHT` (0.475).
- Text the player reads is in capitals, plain words, from `Market.luau`. No refusal code is ever shown raw.
- Do not change `Auction.luau`'s rules or `AuctionServer.luau`'s ordering rule.
- Comments say why, in plain words, and name River and the date where a choice was theirs.

## Review Focus

1. The list answers late, after the player has left the page or switched tab. Nothing draws into a page that is gone.
2. A player types a bid that isn't a number, is empty, has commas or spaces, or is enormous. The box says what's wrong; nothing is sent that the server would have to refuse as a bad request.
3. An auction in the grid ends, is bought or is cancelled while its bid box is open. The box says so and closes cleanly.
4. The player's own snapshot changes (outbid, sold) while `MINE` is open. The tab redraws.
5. A search that matches nothing, an empty market, and a player with no numbered cards on `SELL`. Each shows its line, not a blank page or an error.

Tests for 2 and the pure half of 5 are in Task 2. The rest are checked by reading in Tasks 3 and 4 and by River in Play.

---

### Task 1: One browsing list, and news of what settled

**Files:**
- Create: `src/shared/CardCore/Market.luau` (the entry packing only, in this task)
- Modify: `src/server/AuctionStore.luau`, `src/server/AuctionServer.luau`
- Test: `tests/market_spec.luau` (add to both lists in `tests/run.luau`)

**Interfaces:**
- `Market.pack(record): any` — the browsing entry for an auction record: `{ i = id, c = cardId, t = tier, v = variant, s = serial, p = bid or startBid, b = buyNow, e = endsAt, h = true when there is a bid }`. `Market.unpack(entry): Listing?` — `{ id, cardId, tier, variant, serial, price, buyNow, endsAt, hasBid }`, or nil for anything malformed.
- `AuctionStore.show`, `hide` and `browse` use one sorted map, `Auctions_all`, holding `Market.pack` entries. `browse()` takes nothing and reads pages of 200 until it has 600 or runs out, soonest to end first. The in-memory stand-in matches.
- `BrowseAuctions` takes nothing and answers `{ ok = true, auctions = { packed entries }, now = number }` from one 10-second cache for the whole server.
- New request `AuctionInfo` (an auction id) answers `{ ok = true, auction = Market.pack(record), sellerName, seller = userId, min = Auction.minBid(record), closed = boolean, now }` or `{ ok = false, code = "Gone" }`. At most one a second per player.
- New RemoteEvent `MarketNews` under `PlayerCards.remotes`. `AuctionServer.check` sends `{ kind, cardId, tier, variant, serial, price }` after a settle: `"Refunded"` → kind `"Outbid"`; `"Collected"` → `"Won"`; `"Paid"` → `"Sold"`; `"Returned"` on a record that ended with no bid → `"Unsold"` (a cancelled listing sends nothing). The card comes from the record, or from the save's entry read before settling when there is no record.
- News for a player whose client hasn't asked yet is kept, up to 20 lines, and handed over by a new request `MarketNewsWaiting` that answers `{ ok = true, news = {...} }` and empties it.

- [ ] **Step 1: Write the failing tests:** `unpack(pack(record))` round-trips a record with a bid and Buy Now, and one with neither (`price` is the starting bid, `hasBid` false, `buyNow` nil); `unpack` returns nil for a string, an entry missing its id, a non-numeric serial, and a fractional end time.
- [ ] **Step 2: Run. Expected: fail. Step 3: Implement `pack` and `unpack`. Run. Expected: pass.**
- [ ] **Step 4: Change `AuctionStore` and `AuctionServer`** as above. `AuctionWalk.luau` keeps working unchanged.
- [ ] **Step 5: Run the checks. Commit** "Keep one browsing list for every card, and send news of what settled".

---

### Task 2: The screen's rules

**Files:**
- Modify: `src/shared/CardCore/Market.luau`
- Test: `tests/market_spec.luau`

**Interfaces** (all pure):
- `Market.matches(search: string, cardName: string): boolean` — true when the search, lowercased with spaces removed, is empty or is found in the name treated the same way.
- `Market.rarity(tier: string, variant: string): number` — higher is rarer: the tier's place in `Tier.order` times 10, plus 3 for Zero-Day, 2 for Chromatic, 1 for Redacted, 0 for Base.
- `Market.sorted(listings: { Listing }, mode: "soon" | "serial" | "rarity"): { Listing }` — a new list. `soon`: `endsAt` rising. `serial`: serial rising, then `endsAt`. `rarity`: `Market.rarity` falling, then `endsAt`.
- `Market.visible(listings, search: string, mode, nameOf: (cardId: string) -> string): { Listing }` — filtered by `matches`, then `sorted`.
- `Market.timeLeft(seconds: number): (string, boolean)` — the text and whether it is urgent (120 seconds or less and not ended). 0 or less: `"ENDED"`. Under 60: `"45S"`. Under 120: `"1M 12S"`. Under an hour: `"38M"`. Under 10 hours: `"2H 05M"`. Otherwise `"21H"`. Minutes and hours round down.
- `Market.credits(amount: number): string` — whole Credits with commas: `"12,480"`.
- `Market.parseAmount(text: string): number?` — a typed price: digits with any spaces or commas removed; nil if empty, not all digits, or above `Config.MaxCredits`.
- `Market.refusal(code: string, min: number?): string` — the line for a server answer. `TooLow` → `"YOU NEED " .. credits(min) .. " OR MORE"` (without a `min`: `"SOMEONE BID HIGHER"`); `NotEnoughCredits` → `"NOT ENOUGH CREDITS"`; `Ended` and `Gone` → `"THIS AUCTION HAS ENDED"`; `AlreadyHighest` → `"YOU ARE ALREADY WINNING"`; `OwnListing` → `"THAT IS YOUR OWN LISTING"`; `TooManyBids` → `"YOU HAVE 20 BIDS ALREADY"`; `TooManyListings` → `"YOU HAVE 10 LISTINGS ALREADY"`; `BadPrice` → `"BUY NOW MUST BE MORE THAN THE STARTING BID"`; `InDeck` → `"THAT IS YOUR LAST COPY AND IT IS IN YOUR DECK"`; `NotOwned` → `"YOU DON'T HAVE THAT CARD"`; `CantCancel` → `"IT HAS A BID, SO IT CAN'T BE CANCELLED"`; anything else, including `Busy`, `Unavailable`, `SaveFailed`, `RateLimited` and `Failed` → `"TRY AGAIN IN A MOMENT"`.
- `Market.news(item: { kind, cardName, serial, price }): string` — `Outbid` → `"OUTBID ON PHASE DASH 0042. YOUR CREDITS ARE BACK."`; `Won` → `"YOU WON PHASE DASH 0042"`; `Sold` → `"SOLD PHASE DASH 0042 FOR 4,200"`; `Unsold` → `"PHASE DASH 0042 DID NOT SELL"`. The serial is `CardLook.faceSerial`, and `CardLook.lowSerialText` for 1 to 10.

- [ ] **Step 1: Write the failing tests,** one `it` per function, with these pinned:
  - `matches("phase", "Phase Dash")`, `matches("PHASED", "Phase Dash")`, `matches("  ", "Overclock")` true; `matches("shell x", "Aegis Shell")` false.
  - `rarity`: Prototype Base beats Redline Zero-Day; Field Zero-Day beats Field Chromatic beats Field Redacted beats Field Base.
  - `sorted`: three listings whose three orders all differ; ties in serial and rarity go to the earlier `endsAt`; the list passed in is unchanged.
  - `visible` with a search that matches nothing returns an empty list (Review Focus 5).
  - `timeLeft`: 0 → `"ENDED", false`; 45 → `"45S", true`; 72 → `"1M 12S", true`; 120 → `"2M", true`; 121 → `"2M", false`; 2280 → `"38M"`; 7500 → `"2H 05M"`; 36000 → `"10H"`; 75600 → `"21H"`.
  - `credits`: 0 → `"0"`, 999 → `"999"`, 1000 → `"1,000"`, 12480 → `"12,480"`, 1234567 → `"1,234,567"`.
  - Review Focus 2, `parseAmount`: `"2783"`, `"2,783"` and `" 2 783 "` → 2783; `""`, `"abc"`, `"12.5"`, `"-5"`, `"1e9"` and a 30-digit number → nil.
  - `refusal`: every code named above gives its line, an unknown code gives `"TRY AGAIN IN A MOMENT"`, and `TooLow` with `min = 2783` reads `"YOU NEED 2,783 OR MORE"`.
  - `news`: the four lines above exactly, and a serial of 7 reads `07`.
- [ ] **Step 2: Run. Expected: fail. Step 3: Implement. Step 4: Run the checks. Expected: pass.**
- [ ] **Step 5: Commit** "Add the market screen's rules: search, sort and wording".

---

### Task 3: Browse and the bid box

**Files:**
- Create: `src/client/MarketPanel.luau`
- Modify: `src/client/PanelKit.luau` (a `rounded` option), `src/client/OutpostMenu.client.luau`

**Interfaces:**
- `PanelKit.button` options gain `rounded: boolean?`, which adds a `UICorner` of `0.0056` units. Nothing else about buttons changes.
- `MarketPanel.fill(page: Frame)` draws the page; `MarketPanel.stop()` ends its timers, like `SettingsPanel.stop()`.
- `OutpostMenu`: `BUTTONS` becomes `{ "PLAY", "PACKS", "MARKET", "LOADOUT", "PROFILE", "SETTINGS" }`; `fillPage` calls `MarketPanel.fill`; leaving the page calls `MarketPanel.stop`; the `MarketPrompt` handler shows `"MARKET"` and its comment says so.

Layout, in units from the page's top left:

| Part | Where |
| --- | --- |
| Tabs `BROWSE`, `SELL`, `MINE` | Text buttons on line 0.02, starting at `MARGIN`, 0.055 apart. The open one is underlined. `MINE` reads `MINE · N` when the player has N listings and bids. |
| Credits | Right-aligned at `RIGHT` on the same line: `CREDITS 12,480`, from the snapshot. |
| Rule | Under the tabs at 0.03. |
| Search box | Left `MARGIN`, top 0.04, width 0.2, height 0.022. Placeholder `SEARCH`. A Roblox `TextBox` styled as `CommentsPanel`'s is, with rounded corners. |
| Sort buttons | Right-aligned to `RIGHT` at top 0.04: `ENDING SOON`, `SERIAL`, `RARITY`, each 0.07 wide and 0.022 tall, 0.004 apart, rounded. The chosen one is `active`. |
| Grid | From top 0.072 to the bottom of the page, scrolling. Five columns. A cell is 0.0852 wide with 0.006 between; the card is 0.0852 wide and 0.1363 tall; below it 0.03 for two lines of text; rows are 0.1783 apart. |
| Under a card | Line one: the price at the cell's left in `LabelBold`, the time left right-aligned in `Label`. Line two, smaller: `BUY NOW 5,000`, or `YOU ARE WINNING`, or nothing. |

- A card you lead (your snapshot has a bid on that auction and the entry's price equals it) gets a 3-pixel navy stroke.
- The card faces are `CardFace.new` with `serial` set to the auction's serial and the cell's width, which is under the small-card width so they draw with half the particles.
- The list is asked for with `CardData.ask("BrowseAuctions")` when `BROWSE` opens and every 10 seconds while it is open; the grid redraws only when the visible list's ids or prices change. Time-left labels are updated once a second from `now` in the answer plus the time since.
- Typing in the search box or pressing a sort button redraws from the list already held, with no request.
- **Review Focus 1:** every reply checks `page.Parent` and that the tab is still the one it was asked for before drawing.

The bid box, opened by clicking a card:

- A navy scrim over the page at 0.5 transparency that closes the box when clicked; the box itself is Bone, centred, 0.36 wide and 0.2 tall, with rounded corners.
- Left: the card at 0.1 wide with every effect (a width above the small-card width).
- Right: the current bid large with `CURRENT BID` or `STARTING BID` under it, the time left, `SOLD BY name`, a `TextBox` holding the least bid, a `BID` button, and `BUY NOW 5,000` when there is one. One line under them for refusals.
- It opens at once from the grid's entry and asks `AuctionInfo` to fill in the seller and the real price; `Gone`, `closed` or an ended time shows `THIS AUCTION HAS ENDED` and removes the buttons (Review Focus 3).
- `BID` runs `Market.parseAmount` on the text; nil shows `ENTER A WHOLE NUMBER` and sends nothing (Review Focus 2). Otherwise `CardData.ask("PlaceBid", { id, amount })`. `BUY NOW` sends the Buy Now price.
- While a request is out both buttons read `...` and ignore clicks.
- On success the box closes and the list is fetched again. On refusal the line shows `Market.refusal(code, min)`, and a `min` is written into the text box.
- When `seller` is the player: no bid controls, the words `YOUR LISTING`, and a `CANCEL` button when the entry has no bid, which sends `CancelListing`.

- [ ] **Step 1: Add `rounded` to `PanelKit.button`.**
- [ ] **Step 2: Write `MarketPanel.luau`** with the tabs, Browse and the bid box. `SELL` and `MINE` show `COMING NEXT` for now.
- [ ] **Step 3: Wire it into `OutpostMenu.client.luau`.**
- [ ] **Step 4: Read it against Review Focus 1, 2 and 3.**
- [ ] **Step 5: Run the checks. Commit** "Add the market page: a wall of cards for sale and a bid box".
- [ ] **Step 6: Hand to River.** With no second player there is nothing to bid on, so tell them how to fill the wall: run `game.ServerStorage.AuctionWalk:Fire()` won't leave listings up, so add a second Studio-only event in `CardCore.server.luau`, `MarketFill`, that lists up to five of the first player's numbered cards for 1 hour at 100 Credits with Buy Now at 500. Say that these are their own listings, so the bid box will show `YOUR LISTING`; bidding needs a second player (Studio's Test tab can start a local server with two players).

---

### Task 4: Sell and Mine

**Files:**
- Modify: `src/client/MarketPanel.luau`

**Interfaces:**
- `SELL`, step one: a grid in the same cell style of the player's numbered stacks, from `snapshot.stacks` and `snapshot.lowest`, one cell per card, tier and variant, showing the lowest serial. Under each: `N COPIES` when more than one. Stacks with no numbered copy aren't shown. With none at all: `YOU HAVE NO NUMBERED CARDS TO SELL`.
- The snapshot carries only each stack's lowest serial, so choosing another serial needs the runs. Add `serials = data.serials` to `PlayerCards.snapshot`'s `market` table is wrong (it is large for nobody's benefit); instead add a request `MySerials` (card, tier, variant) that answers that stack's runs. Clicking a cell with more than one numbered copy asks it and shows a short list of serials to pick from (the first 50, lowest first); with one copy it goes straight to the form.
- `SELL`, step two, the form: the card at 0.1 wide on the left with `CHANGE CARD` under it; on the right `STARTING BID` and `BUY NOW (OPTIONAL)` text boxes, three length buttons `1H`, `6H`, `24H` with 6 chosen, the line `YOU GET THE FULL PRICE. THE CARD LEAVES YOUR COLLECTION UNTIL IT SELLS OR COMES BACK.`, and `LIST FOR AUCTION`.
- `LIST FOR AUCTION` parses both boxes with `Market.parseAmount` (an empty Buy Now is none; a bad one shows `ENTER A WHOLE NUMBER`), then `CardData.ask("ListCard", {...})`. Success switches to `MINE`. A refusal shows `Market.refusal`.
- `MINE`: the heading `YOUR LISTINGS` and a row of cells from `snapshot.market.listed`, then `YOUR BIDS` and a row from `snapshot.market.bids`. A listing shows its starting bid until the browsing list or an `AuctionInfo` gives its current price, then that, or `NO BIDS`; a bid shows your amount and `WINNING` or `OUTBID` by comparing with the browsing list's price for that auction. Clicking either opens the bid box. With neither: `YOU HAVE NOTHING IN THE MARKET`.
- `MINE` and the Credits line redraw when `CardData`'s snapshot changes (Review Focus 4).

- [ ] **Step 1: Add the `MySerials` request** to `AuctionServer.luau` with a parser in `Requests.luau` and a parser test (good shape parses; a bad card id, tier or variant returns nil).
- [ ] **Step 2: Write Sell and Mine.**
- [ ] **Step 3: Read it against Review Focus 4 and 5.**
- [ ] **Step 4: Run the checks. Commit** "Add selling and your own auctions to the market page".
- [ ] **Step 5: Hand to River:** list a card from `SELL`, see it in `MINE` and on the wall, cancel it from its box, see it come back.

---

### Task 5: Telling players what happened

**Files:**
- Modify: `src/client/OutpostMenu.client.luau` or a small new `src/client/MarketNews.client.luau` if the menu script is the wrong home for something that must run outside the menu

**Interfaces:**
- Listens to `MarketNews`, and on start asks `MarketNewsWaiting`. Each item becomes `Market.news(...)` with the card's name from `Cards.byId`, and is shown with `PullReveal.notice`, one after another, each for about 4 seconds.
- Shown anywhere in the Outpost, not during a match.

- [ ] **Step 1: Read `PullReveal.notice`** to see how it queues and where it draws; use it as it is if it already queues, and queue in front of it if it doesn't.
- [ ] **Step 2: Write it. Step 3: Run the checks. Commit** "Tell players when they are outbid, win or sell".

---

### Task 6: Docs

**Files:**
- Modify: `docs/specs/market-screen.md` (status, anything tuning changed), `docs/specs/auction-house.md` (the single browsing list, `AuctionInfo`, `MarketNews`, `MySerials`), `docs/specs/outpost-ui.md` (the new row and the stall's prompt), `docs/specs/outpost.md` (the stall opens the market), `docs/HANDOFF.md`

- [ ] **Step 1: Update each** to what was built and what River has and hasn't checked. Under "not checked": bidding between two real players, and the memory limit with many listings.
- [ ] **Step 2: Commit** "Update the specs for the market screen".
