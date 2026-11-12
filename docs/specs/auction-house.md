# The auction house

**Status:** built on 2026-11-11 on `feature/auction-house` (which builds on `feature/serials`), and passing its tests. River ran the walkthrough in Studio on 2026-11-11 and every step matched, but with API access off, so only the in-memory stand-ins were used: the real data store, memory store and messaging calls have not run. Two servers bidding on one auction has not been tried. This is the second of three pieces of the player market: serials (`serials.md`), the auction house, then the market screen.

**Covers:** the rules of auctions and the server that runs them: listing, bidding, Buy Now, ending, and getting your card or Credits. The screens are the next spec. Until they exist there is nothing to click, so this piece is proven by tests and by server checks.

## Why

Lucky pulls should be worth something to other players. An auction lets a player sell one exact copy, like "Aegis Shell, Zero-Day, serial 04", for Credits, to anyone on any server.

Success is: a card or a Credit can never be copied or lost, whatever a server or a player does mid-trade, and a player who isn't in the game when an auction ends finds what they're owed waiting.

## How it plays

- **Listing:** the seller picks one numbered card, a starting bid, a length of 1, 6 or 24 hours, and optionally a Buy Now price. The card leaves their collection while it is listed.
- **Bidding:** a bid's Credits are set aside the moment it is placed. A bidder who is outbid gets them back.
- **Buy Now:** paying the Buy Now price ends the auction at once and wins it.
- **The end:** the highest bidder gets the card, with its serial. The seller gets the whole winning price; the market takes no cut (River's choice). With no bids, the card goes back to the seller.
- **Offline:** whatever a player is owed is settled the next time their save loads.

## Rules

| Rule | Value |
| --- | --- |
| Starting bid | 1 Credit or more, whole Credits |
| Buy Now | Optional. Must be more than the starting bid |
| Next bid | At least 5% over the current bid, and at least 1 Credit more. The first bid may equal the starting bid |
| Late bids | A bid in the last 2 minutes moves the end to 2 minutes after that bid |
| Cancelling | The seller may cancel only while there are no bids |
| Listings at once | 10 per player |
| Open bids at once | 20 per player |
| Highest price | The save's Credit limit |

A player may not:

- bid on their own listing, or bid again while they are already the highest bidder;
- list a starter card or a card still waiting for its serial;
- list the last copy of a card that is in their deck;
- rebirth while they have Credits set aside in bids. A rebirth trades all your Credits for luck, and Credits parked in a bid would dodge that.

Income and Deck Power Rating count only cards in the collection, so a listed card earns nothing.

## How it stays safe

Nothing is ever moved between two players' saves directly. Three things hold the state:

1. **Each save holds its own side.** A listed card is taken out of the collection and kept in the save under its auction, with its card, tier, variant and serial. A bid's Credits are taken out of the balance and kept in the save under that auction.
2. **Each auction has one shared record** that every server can read: what is for sale, the seller, the end time, and the current highest bid and bidder. It changes only through `UpdateAsync`, so two bids arriving together can't both win.
3. **Each save remembers what it has settled,** so nothing is collected twice.

Every step is ordered so that a crash at any point leaves something a later load can finish:

| Step | What happens | If the server dies midway |
| --- | --- | --- |
| List | The card moves into the save's "listed" entry and the save is written. Then the shared record is created. | The save has an entry with no record. On the next load the record is created, by the auction's own id, so it can't be made twice. |
| Bid | The Credits move into the save's "bid" entry. Then the shared record is asked to accept the bid. | The save holds a bid the record doesn't show. On the next check the Credits go back. |
| Close | Once the time is up, a server closes the record to bids through the same one-at-a-time update that takes bids. Nothing is handed over before that. | A late bid that landed first wins and the auction runs on. A record left unclosed is closed by the next check. |
| Outbid | The record now names someone else. | Nothing is at risk: the old bidder's Credits are still in their own save and return on their next check. |
| Win | The winner's save takes the card and notes the auction as settled, in one write. | Either the write landed or it didn't. The note is what stops a second collection. |
| Sold | The seller's save drops the listed entry and adds the price, in one write. | The same: the entry is there or it isn't. |
| Unsold or cancelled | The seller's save turns the listed entry back into the card. | The same. |

A check compares one save entry with its shared record and does whichever of those steps is due. Checks run when a save loads, when an auction's end time passes, when another server announces a change to that auction, and every 5 minutes as a backstop.

**What a save trusts:** the shared record is the truth about who is winning and when it ends. A save's own entries are the truth about what that player has put in. Neither is ever inferred from the other without a check.

## The shared parts

- **Records:** DataStore `Auctions_v1`, one key per auction. A record is deleted once both sides have settled.
- **Browsing:** a MemoryStore sorted map per card, holding a short summary of each live auction (card, tier, variant, serial, current price, Buy Now, end time, seller's name), sorted by end time. It is only a window for browsing. If it loses an entry the auction still ends and settles correctly; it just can't be seen.
- **Announcements:** a MessagingService topic tells every server when an auction gets a bid, ends or is cancelled, so the players involved are checked at once instead of at the 5-minute backstop.
- **Time** is the server's UTC clock.
- **In Studio without API access** all three are kept in memory, so the rules can be tried with one player.

## What the client can ask

Remote requests, each checked on the server and each answering ok or a reason:

- `ListCard` — card, tier, variant, serial, starting bid, hours, Buy Now or none.
- `PlaceBid` — auction id and amount. An amount at or above Buy Now buys it.
- `CancelListing` — auction id.
- `BrowseAuctions` — a card id; answers that card's live auctions, soonest to end first.
- `MyAuctions` — answers the player's own listings and bids with their current state.

The snapshot the client already receives gains the player's listed cards and open bids, so the HUD's Credits never include money that is set aside.

## What could go wrong

- **Roblox's limits.** Each bid is one write to one record. Checks are spread out by the announcements, so a player with 30 open entries does not read 30 records every few seconds. If a hot auction gets many bids at once, late ones are told to try again.
- **A lost shared record.** If a record vanishes while a save still holds a listed card, the card goes back to the seller. If it vanishes while a save holds a bid, the Credits go back. Nobody gains.
- **Clocks.** Servers can disagree by a second or two. The record's end time decides; a bid that arrives after it is refused.
- **Players leaving mid-request.** Every request finishes its save changes before it yields, or is undone by the next check.
- **The window is not the truth.** A price shown in browsing can be a few seconds old. A bid below the real price is refused with the real price in the answer.

## How it's built

- A pure rules module holds everything that can be decided without Roblox: whether a listing or bid is allowed, the next minimum bid, the late-bid extension, what a record becomes when a bid is accepted, and what a save entry should do given its record (wait, refund, collect, pay out, return).
- `Inventory.luau` gains putting one numbered copy back into a stack.
- `SaveData.luau` gains the save's market entries (listed cards, bids, settled auctions) and cleans them on load. The save version moves to 6; a version 5 save simply gains empty entries.
- A server module owns the shared record, the browsing map and the announcements, in the way `SerialCounter.luau` owns the counter. Another runs the requests and the checks.
- `Rebirth.luau` refuses while bids are open.

**As built:** the rules are `CardCore/Auction.luau`; the shared parts `server/AuctionStore.luau` (records in DataStore `Auctions_v1`, the browsing window in MemoryStore maps `Auctions_<cardId>`, announcements on topic `Auctions`); the requests and checks `server/AuctionServer.luau`. A save's entries are `market.listed`, `market.bids` and `market.settled`, at save version 6. The walkthrough is `server/AuctionWalk.luau`: during Play in Studio, with the Server view selected, run `game.ServerStorage.AuctionWalk:Fire()` in the command bar and read the Output window.

## Order of work

1. The rules module and the save's market entries. Pure, tested.
2. The shared record, browsing map and announcements on the server, with their in-memory stand-ins.
3. The requests and the checks.
4. A server-side script River can run in Studio's command bar that walks one auction from listing to settlement and prints each step, since there is no screen yet.

## Tests

Lune tests cover the rules: every refusal in the tables above; minimum bids and the late-bid extension; Buy Now; and, for each row of the safety table, a save and record caught at every point a crash could leave them, checked to end with exactly one card and the right Credits on each side. The DataStore, MemoryStore and MessagingService calls, and two servers bidding on one auction, are not covered by tests and need the live game with two players.
