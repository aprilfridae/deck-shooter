-- The rules of auctions (docs/specs/auction-house.md). Pure: the server modules do the data store calls.
--
-- Nothing is ever moved between two players' saves. A listed card and a bid's Credits stay in their owner's save,
-- under the auction's id, in `data.market`. One shared record per auction says who is winning. Each save then
-- settles its own side by comparing its entry with that record, so a crash at any point leaves something a later
-- load can finish, and nothing can be copied or lost.
local Cards = require("./Cards")
local Config = require("./Config")
local Inventory = require("./Inventory")
local Tier = require("./Tier")
local Variant = require("./Variant")

export type Record = {
	id: string,
	seller: number,
	sellerName: string,
	cardId: string,
	tier: string,
	variant: string,
	serial: number,
	startBid: number,
	buyNow: number?,
	endsAt: number,
	bid: number?,
	bidder: number?,
	bidderName: string?,
	cancelled: boolean?,
	sellerDone: boolean?, -- the seller's save has its Credits or its card back, and that save is written
	winnerDone: boolean?, -- the winner's save has the card, and that save is written
}

local Auction = {
	LENGTHS = { 1, 6, 24 }, -- hours (River, 2026-11-11)
	MAX_LISTED = 10,
	MAX_BIDS = 20,
	LATE_SECONDS = 120, -- a bid this close to the end pushes the end back this far, so nobody loses to a snipe
	RAISE = 0.05, -- each bid beats the last by at least this share
}

-- A whole number of at least 0 that isn't NaN or infinite.
local function sane(n: any): boolean
	return type(n) == "number" and n == n and n ~= math.huge and n >= 0 and n == math.floor(n)
end

local function size(entries: { [string]: any }): number
	local total = 0
	for _ in entries do
		total += 1
	end
	return total
end

local function holds(data: any, key: string, serial: number): boolean
	local found = data.serials and data.serials[key]
	if not found then
		return false
	end
	for index = 1, #found.runs, 2 do
		if serial >= found.runs[index] and serial <= found.runs[index + 1] then
			return true
		end
	end
	return false
end

local function inDeck(data: any, cardId: string, tier: string): boolean
	for _, slot in data.deck do
		if slot.cardId == cardId and slot.tier == tier then
			return true
		end
	end
	return false
end

function Auction.canList(data: any, req: any): (boolean, string?)
	if type(req) ~= "table" or not Cards.isValid(req.cardId) or not Tier.isValid(req.tier) or not Variant.isValid(req.variant) then
		return false, "BadRequest"
	elseif not sane(req.serial) or not sane(req.startBid) or not sane(req.hours) or (req.buyNow ~= nil and not sane(req.buyNow)) then
		return false, "BadRequest"
	elseif not table.find(Auction.LENGTHS, req.hours) then
		return false, "BadLength"
	elseif req.startBid < 1 or req.startBid > Config.MaxCredits then
		return false, "BadPrice"
	elseif req.buyNow ~= nil and (req.buyNow <= req.startBid or req.buyNow > Config.MaxCredits) then
		return false, "BadPrice"
	elseif not holds(data, Inventory.key(req.cardId, req.tier, req.variant), req.serial) then
		-- Starter cards and cards still waiting for a serial have no number, so they can never match.
		return false, "NotOwned"
	elseif Inventory.count(data, req.cardId, req.tier) == 1 and inDeck(data, req.cardId, req.tier) then
		return false, "InDeck"
	elseif size(data.market.listed) >= Auction.MAX_LISTED then
		return false, "TooManyListings"
	end
	return true, nil
end

-- Moves the card out of the collection and into the save's listed entry. Call only after canList.
-- `live` turns true once the shared record exists.
function Auction.list(data: any, id: string, req: any, now: number): any
	Inventory.take(data, Inventory.key(req.cardId, req.tier, req.variant), req.serial)
	local listed = {
		cardId = req.cardId,
		tier = req.tier,
		variant = req.variant,
		serial = req.serial,
		startBid = req.startBid,
		buyNow = req.buyNow,
		endsAt = now + req.hours * 3600,
		live = false,
	}
	data.market.listed[id] = listed
	return listed
end

function Auction.record(id: string, seller: number, sellerName: string, listed: any): Record
	return {
		id = id,
		seller = seller,
		sellerName = sellerName,
		cardId = listed.cardId,
		tier = listed.tier,
		variant = listed.variant,
		serial = listed.serial,
		startBid = listed.startBid,
		buyNow = listed.buyNow,
		endsAt = listed.endsAt,
	}
end

function Auction.ended(record: Record, now: number): boolean
	return record.cancelled == true or now >= record.endsAt
end

-- The least the next bid can be.
function Auction.minBid(record: Record): number
	local bid = record.bid
	if not bid then
		return record.startBid
	end
	return math.max(bid + 1, math.ceil(bid * (1 + Auction.RAISE)))
end

-- What a bid of this amount costs: never more than Buy Now.
function Auction.price(record: Record, amount: number): number
	local buyNow = record.buyNow
	return if buyNow and amount >= buyNow then buyNow else amount
end

local function refusal(userId: number, record: Record, amount: number, now: number): string?
	if Auction.ended(record, now) then
		return "Ended"
	elseif record.seller == userId then
		return "OwnListing"
	elseif record.bidder == userId then
		return "AlreadyHighest"
	elseif amount < Auction.minBid(record) then
		return "TooLow"
	end
	return nil
end

function Auction.canBid(data: any, userId: number, record: any, amount: any, now: number): (boolean, string?)
	if type(record) ~= "table" or not sane(amount) then
		return false, "BadRequest"
	end
	local refused = refusal(userId, record, amount, now)
	if refused then
		return false, refused
	end
	local price = Auction.price(record, amount)
	local held = data.market.bids[record.id]
	if price > Config.MaxCredits then
		return false, "BadPrice"
	elseif not held and size(data.market.bids) >= Auction.MAX_BIDS then
		return false, "TooManyBids"
	elseif price - (if held then held.amount else 0) > data.credits then
		return false, "NotEnoughCredits"
	end
	return true, nil
end

-- Sets Credits aside so the bid entry holds exactly `price`. An older, lower bid on the same auction that hasn't
-- been refunded yet counts toward it.
function Auction.hold(data: any, id: string, price: number, endsAt: number)
	local held = data.market.bids[id]
	data.credits -= price - (if held then held.amount else 0)
	data.market.bids[id] = { amount = price, endsAt = endsAt }
end

-- What the record becomes if this bid is taken, or nil if it can't be taken now. Never changes the record it is
-- given, because UpdateAsync may call it more than once.
function Auction.accept(record: Record, userId: number, name: string, amount: number, now: number): Record?
	if not sane(amount) or refusal(userId, record, amount, now) then
		return nil
	end
	local taken = table.clone(record)
	taken.bid = Auction.price(record, amount)
	taken.bidder = userId
	taken.bidderName = name
	if record.buyNow and amount >= record.buyNow then
		taken.endsAt = now -- Buy Now ends it at once
	elseif record.endsAt - now <= Auction.LATE_SECONDS then
		taken.endsAt = now + Auction.LATE_SECONDS
	end
	return taken
end

-- The seller may cancel only while nobody has bid.
function Auction.cancel(record: Record, userId: number, now: number): Record?
	if record.seller ~= userId or record.bidder or Auction.ended(record, now) then
		return nil
	end
	local cancelled = table.clone(record)
	cancelled.cancelled = true
	return cancelled
end

local function settleListed(data: any, userId: number, id: string, listed: any, record: Record?, now: number): string
	local market = data.market
	local function back(): string
		local key = Inventory.key(listed.cardId, listed.tier, listed.variant)
		if not Inventory.give(data, key, listed.serial) and not holds(data, key, listed.serial) then
			return "Wait" -- the stack is full: the card stays listed until there is room
		end
		market.listed[id] = nil
		return "Returned"
	end

	if not record then
		-- No record and never confirmed: the server died between saving the listing and creating its record.
		-- A record that was confirmed and has vanished can't be sold from, so the card comes home.
		return if listed.live then back() else "Publish"
	elseif record.seller ~= userId then
		return "Wait"
	elseif record.sellerDone then
		-- The record says this side was settled and saved. An entry that survives that is a stale copy.
		market.listed[id] = nil
		return "Done"
	elseif not Auction.ended(record, now) then
		listed.live = true
		listed.endsAt = record.endsAt
		return "Wait"
	elseif record.bidder and not record.cancelled then
		market.listed[id] = nil
		data.credits = math.min(data.credits + (record.bid :: number), Config.MaxCredits)
		return "Paid"
	end
	return back()
end

local function settleBid(data: any, userId: number, id: string, held: any, record: Record?, now: number): string
	local market = data.market
	if not record or record.bidder ~= userId then
		-- Outbid, or the record never took this bid. The Credits never left this save, so they just come back.
		market.bids[id] = nil
		data.credits = math.min(data.credits + held.amount, Config.MaxCredits)
		return "Refunded"
	end
	local bid = record.bid :: number
	if bid < held.amount then
		data.credits = math.min(data.credits + held.amount - bid, Config.MaxCredits)
		held.amount = bid
	end
	held.endsAt = record.endsAt
	if not Auction.ended(record, now) then
		return "Wait"
	elseif record.winnerDone or market.settled[id] then
		market.bids[id] = nil
		return "Done"
	end
	local key = Inventory.key(record.cardId, record.tier, record.variant)
	if not Inventory.give(data, key, record.serial) and not holds(data, key, record.serial) then
		return "Wait" -- the stack is full: the card waits in the auction until there is room
	end
	-- The note is what stops this card being collected twice if the server dies before the record is marked.
	market.settled[id] = true
	market.bids[id] = nil
	return "Collected"
end

-- Does whatever is due for this save's entry under `id`, given the shared record as it stands (nil if there is
-- none), and says what it did:
--   "Publish"   a listed card has no record yet: the caller creates one
--   "Wait"      nothing is due yet
--   "Paid"      the seller got the winning bid
--   "Returned"  the seller got the card back (unsold, cancelled, or its record is gone)
--   "Refunded"  a bidder got Credits back
--   "Collected" the winner got the card
--   "Done"      this side was already settled; only a leftover entry was cleared
--   "None"      this save has nothing in this auction
function Auction.settle(data: any, userId: number, id: string, record: Record?, now: number): string
	local listed = data.market.listed[id]
	if listed then
		return settleListed(data, userId, id, listed, record, now)
	end
	local held = data.market.bids[id]
	if held then
		return settleBid(data, userId, id, held, record, now)
	end
	return "None"
end

-- The record with one side marked as settled, and whether it can now be deleted: the seller is done and there is
-- either no winner or the winner is done too.
function Auction.finish(record: Record, side: "seller" | "winner"): (Record, boolean)
	local marked = table.clone(record)
	if side == "seller" then
		marked.sellerDone = true
	else
		marked.winnerDone = true
	end
	local sold = marked.bidder ~= nil and not marked.cancelled
	return marked, marked.sellerDone == true and (not sold or marked.winnerDone == true)
end

-- Drops the save's note for an auction, once its record is known to say the winner is done.
function Auction.cleared(data: any, id: string)
	data.market.settled[id] = nil
end

return Auction
