# The market screen

**Status:** built on 2026-11-11 on `feature/market-screen`. The rules pass their tests. None of the screen has been seen in Play, and bidding between two players has not been tried. This is the third of three pieces of the player market: serials (`serials.md`), the auction house (`auction-house.md`), then this screen.

**Covers:** what players see and click to browse, bid, buy, sell and collect. The rules of auctions are in `auction-house.md` and don't change here, except for how the browsing list is kept.

## The idea

River's words: "a grid of all the cards with their art, not so much text". The market is a wall of cards for sale. Each one is the real card face, with its serial where the card prints it. The only text under a card is its price and how long is left. Everything else happens when you click one.

Success is River opening the market in Play, finding a card by searching and sorting, bidding on it from one box, and listing a card of their own, all matching the mockup.

## Where it lives

- A new `MARKET` row in the Outpost menu, third, between `PACKS` and `LOADOUT`. The rows below it renumber.
- The Market stall's prompt opens `MARKET`. Today it opens `PACKS`.
- The panel is the same Bone panel with Deep Navy text as the other pages.
- The page is laid out like `PACKS` and `PLAY` (River, 2026-11-11): the big `MARKET` title and its rule, then square buttons on three equal columns.

## The three tabs

`BROWSE`, `SELL` and `MINE` across the top of the panel. `MINE` shows how many listings and bids you have. The player's Credits show at the top right; they are the Credits you can spend, so Credits set aside in bids are not in the number.

### Browse

- **The grid:** every auction as a card, five across, scrolling down. Each is a live card face with the auction's own serial on it, so serials 1 to 10 show the rainbow number.
- **Under each card:** the current price on the left and the time left on the right. A small line below reads `BUY NOW` and its price when the auction has one, or `YOU ARE WINNING` on a card you lead, which also gets a thick navy outline.
- **Time left** counts down on screen. It reads like `2H 05M`, `38M`, `1M 12S`, and turns Hazard Red for the last 2 minutes.
- **Search:** a box at the top left. Typing narrows the grid to cards whose name contains the text, ignoring case and spaces, so `phase` and `phased` both find Phase Dash.
- **Sort:** three buttons at the top right. One is always on.
  - `ENDING SOON` (the default): least time left first.
  - `SERIAL`: lowest serial first.
  - `RARITY`: rarest first. Prototype beats Redline beats Field; within a tier, Zero-Day beats Chromatic beats Redacted beats plain. Ties go to the one ending sooner.
- **Empty:** with nothing for sale it says `NOTHING FOR SALE YET`; with a search that finds nothing, `NO CARDS MATCH`.
- **Freshness:** the list is fetched when the tab opens and every 10 seconds while it is open. Prices can be a few seconds old; the bid box always checks the real one.

### The bid box

Clicking a card in the grid opens a box over the panel:

- The card, large, with its full effects.
- The current bid, the time left and the seller's name.
- A box to type a bid, filled in with the least you can bid, and a `BID` button.
- A `BUY NOW` button with its price, when the auction has one.
- A line for what went wrong, in plain words: `YOU NEED 2,783 OR MORE`, `NOT ENOUGH CREDITS`, `THIS AUCTION HAS ENDED`, `YOU ARE ALREADY WINNING`, `TRY AGAIN IN A MOMENT`. A bid that was too low because someone got in first shows the new least bid and fills it in.
- On your own listing the bid controls are replaced by `YOUR LISTING`, and `CANCEL` if nobody has bid.
- A bid takes a second or two to confirm. The buttons show `...` and can't be pressed again while it does.
- Clicking outside the box closes it.

### Sell

- **Pick a card:** a grid of the player's own numbered cards, one per card, tier and variant, each showing its lowest serial. Clicking one opens that stack's serials to choose from when there is more than one. Starter cards and cards waiting for a number aren't shown.
- **The form:** the chosen card on the left; on the right a starting bid, an optional Buy Now price, and a length of `1H`, `6H` or `24H` (6 hours is picked to start).
- A line says: `YOU GET THE FULL PRICE. THE CARD LEAVES YOUR COLLECTION UNTIL IT SELLS OR COMES BACK.`
- `LIST FOR AUCTION` sends it. Refusals show in plain words: `BUY NOW MUST BE MORE THAN THE STARTING BID`, `THAT IS YOUR LAST COPY AND IT IS IN YOUR DECK`, `YOU HAVE 10 LISTINGS ALREADY`.
- After listing, the screen goes to `MINE`.

### Mine

Two short grids, in the same card style as Browse:

- **Your listings:** each with its current price, or `NO BIDS`, and its time left. Clicking one opens the bid box in its "your listing" form.
- **Your bids:** each with your bid and the time left, marked `WINNING` or `OUTBID`. An outbid card stays until its Credits have come back, which is a moment.
- With neither, it says `YOU HAVE NOTHING IN THE MARKET`.

## Telling players what happened

A short line slides in at the top of the screen, anywhere in the Outpost, when:

- you are outbid: `OUTBID ON PHASE DASH 0042. YOUR CREDITS ARE BACK.`
- you win: `YOU WON PHASE DASH 0042`
- your card sells: `SOLD PHASE DASH 0042 FOR 4,200`
- your card comes back unsold: `PHASE DASH 0042 DID NOT SELL`

Things that settled while you were away show the same lines, one after another, when you next load in.

## What changes in the auction house

Browsing was built as one list per card, because the first plan was to pick a card first. One wall of everything needs one list.

- **One browsing list for every card,** in place of one per card. `BrowseAuctions` takes nothing and answers the whole list.
- **Smaller entries.** Roblox's memory store allows a game about 64 KB plus 1 KB for each player online. Each entry is cut to the least that draws a card: the auction's id, the card, tier, variant and serial, the price, Buy Now, the end time and whether there is a bid. The seller's name comes from the auction's record when the bid box opens.
- **A ceiling of 600 auctions,** soonest to end first. Search and sort work on those. An auction past the ceiling still runs and settles; it shows once others end. With few players online the memory limit is reached before 600, and auctions that don't fit behave the same way.
- **Each server reads the list once every 10 seconds** while anyone has the market open, and every player on it shares that copy.
- The server tells a player's client which auction ended and how, so the lines above can be shown.

## As built, where it differs from the mockup

- **Under a card** there is room for about nine letters, so the price is short past 99,999 (`120K`, `1.2M`) and the time is one word (`2H`, `38M`, `45S`). The bid box shows both in full. The small line reads `BUY 5,000` or `WINNING`.
- **At most 40 cards are drawn at once.** Each is a live card face. Past 40 the page says how many there are and to search.
- **The tabs are three square buttons** across the page's full width, under the big `MARKET` title. The search box sits under the first tab and the three sorts share the width under the other two. The first sort reads `SOONEST`, which fits its button.
- **Your Credits** show in the menu's income line at the top right, as on every page. The page has no Credits line of its own.
- **The label font sheets gained** `, ' ( ) ?`, for prices and plain sentences.
- **To fill the market when testing alone:** during Play in Studio, Server view, run `game.ServerStorage.MarketFill:Fire()`. It lists up to five of your numbered cards. Nobody can bid on their own listing, so bidding needs a second player.

## Cost

A wall of live cards is heavy. Cards in the grids draw at the small-card setting (half the particles) and only while on screen, as cards do everywhere else. Only the bid box's card runs every effect.

## What could go wrong

- **Text entry** uses Roblox's own text box, as profile comments do, because the game's fonts are drawn from image sheets and can't be typed into. The box's font won't match the rest of the page.
- **Stale prices** are expected. The bid box is the place the real price shows.
- **Phones** aren't designed here. The grid is laid out for the screen sizes the other panels support.
- **The memory limit** can hide auctions when listings far outnumber players online, for example overnight. They still run. If this bites, the list can move to a slower store that has no such limit.

## How it's built

- `AuctionStore.luau` keeps one sorted map, with the compact entry, and reads it in pages up to the ceiling. `AuctionServer.luau`'s browse request and cache follow.
- A pure module holds what the screen decides without Roblox: filtering by search text, the three sort orders, the rarity ranking, formatting time left and prices, and turning a refusal code into its line.
- `MarketPanel.luau` is the page, built with `PanelKit`, `CardGrid` and `CardFace` like the other panels. `OutpostMenu.client.luau` gains the row and points the stall's prompt at it.
- `PlayerCards`'s snapshot already carries the player's listings and bids.
- A server-to-client event carries "this auction settled for you, this way".

## Order of work

1. The single browsing list in the auction house.
2. The pure screen rules. Tested.
3. Browse and the bid box. River checks in Play.
4. Sell and Mine. River checks in Play.
5. The lines that tell you what happened.

## Tests

Lune tests cover the pure rules: search matching, each sort order and its ties, the rarity ranking for every tier and variant, time and price formatting at their edges, and every refusal code having a line. The look, the text boxes and the feel of bidding are River's to judge in Play. Bidding against another player needs two players.
