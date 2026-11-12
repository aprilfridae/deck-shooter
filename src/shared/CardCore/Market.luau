-- What the market screen decides without Roblox (docs/specs/market-screen.md): the small entry each auction has
-- in the browsing list, searching and sorting that list, and the words players read.
local CardLook = require("./CardLook")
local Config = require("./Config")
local Tier = require("./Tier")

export type Listing = {
	id: string,
	cardId: string,
	tier: string,
	variant: string,
	serial: number,
	price: number, -- the current bid, or the starting bid while there is none
	buyNow: number?,
	endsAt: number,
	hasBid: boolean,
}

local Market = {}

local URGENT = 120 -- seconds: the last stretch, when a bid pushes the end back
local VARIANT_RANK = { Base = 0, Redacted = 1, Chromatic = 2, ZeroDay = 3 }
local TRY_AGAIN = "TRY AGAIN IN A MOMENT"
local REFUSALS = {
	NotEnoughCredits = "NOT ENOUGH CREDITS",
	Ended = "THIS AUCTION HAS ENDED",
	Gone = "THIS AUCTION HAS ENDED",
	AlreadyHighest = "YOU ARE ALREADY WINNING",
	OwnListing = "THAT IS YOUR OWN LISTING",
	TooManyBids = "YOU HAVE 20 BIDS ALREADY",
	TooManyListings = "YOU HAVE 10 LISTINGS ALREADY",
	BadPrice = "BUY NOW MUST BE MORE THAN THE STARTING BID",
	InDeck = "THAT IS YOUR LAST COPY AND IT IS IN YOUR DECK",
	NotOwned = "YOU DON'T HAVE THAT CARD",
	CantCancel = "IT HAS A BID, SO IT CAN'T BE CANCELLED",
}

local function whole(n: any): boolean
	return type(n) == "number" and n == n and n ~= math.huge and n >= 0 and n == math.floor(n)
end

-- An auction's entry in the browsing list. Roblox's memory store gives a game about 64 KB plus 1 KB for each
-- player online, so the entry is the least that draws a card, with one-letter names. The seller's name is left out
-- and fetched when the bid box opens.
function Market.pack(record: any): any
	return {
		i = record.id,
		c = record.cardId,
		t = record.tier,
		v = record.variant,
		s = record.serial,
		p = record.bid or record.startBid,
		b = record.buyNow,
		e = record.endsAt,
		h = if record.bid then true else nil,
	}
end

function Market.unpack(entry: any): Listing?
	if type(entry) ~= "table" or type(entry.i) ~= "string" or type(entry.c) ~= "string" then
		return nil
	elseif type(entry.t) ~= "string" or type(entry.v) ~= "string" or not (whole(entry.s) and whole(entry.p) and whole(entry.e)) then
		return nil
	elseif entry.b ~= nil and not whole(entry.b) then
		return nil
	end
	return {
		id = entry.i,
		cardId = entry.c,
		tier = entry.t,
		variant = entry.v,
		serial = entry.s,
		price = entry.p,
		buyNow = entry.b,
		endsAt = entry.e,
		hasBid = entry.h == true,
	}
end

local function plain(text: string): string
	return (string.gsub(string.lower(text), "%s", ""))
end

-- Whether a card's name holds the searched text, whatever the capitals or spaces.
function Market.matches(search: string, cardName: string): boolean
	local wanted = plain(search)
	return wanted == "" or string.find(plain(cardName), wanted, 1, true) ~= nil
end

-- Higher is rarer: tier first, then variant.
function Market.rarity(tier: string, variant: string): number
	return (table.find(Tier.order, tier) or 0) * 10 + (VARIANT_RANK[variant] or 0)
end

-- A new list in the chosen order. Ties go to whichever ends sooner.
function Market.sorted(listings: { Listing }, mode: string): { Listing }
	local sorted = table.clone(listings)
	table.sort(sorted, function(a: Listing, b: Listing): boolean
		if mode == "serial" and a.serial ~= b.serial then
			return a.serial < b.serial
		elseif mode == "rarity" then
			local first, second = Market.rarity(a.tier, a.variant), Market.rarity(b.tier, b.variant)
			if first ~= second then
				return first > second
			end
		end
		if a.endsAt ~= b.endsAt then
			return a.endsAt < b.endsAt
		end
		return a.id < b.id -- so the order never flickers between two redraws
	end)
	return sorted
end

function Market.visible(listings: { Listing }, search: string, mode: string, nameOf: (string) -> string): { Listing }
	local found = {}
	for _, listing in listings do
		if Market.matches(search, nameOf(listing.cardId)) then
			table.insert(found, listing)
		end
	end
	return Market.sorted(found, mode)
end

-- How long is left, and whether it's the urgent last stretch.
function Market.timeLeft(seconds: number): (string, boolean)
	if seconds <= 0 then
		return "ENDED", false
	end
	local urgent = seconds <= URGENT
	local left = math.floor(seconds)
	if left < 60 then
		return `{math.max(left, 1)}S`, urgent
	elseif left < 120 then
		return string.format("1M %02dS", left - 60), urgent
	elseif left < 3600 then
		return `{left // 60}M`, urgent
	elseif left < 36000 then
		return string.format("%dH %02dM", left // 3600, left % 3600 // 60), urgent
	end
	return `{left // 3600}H`, urgent
end

function Market.credits(amount: number): string
	local digits = string.format("%d", amount)
	local grouped = string.gsub(string.reverse(digits), "(%d%d%d)", "%1,")
	grouped = string.reverse(grouped)
	return if string.sub(grouped, 1, 1) == "," then string.sub(grouped, 2) else grouped
end

-- A typed price as a number, or nil if it isn't whole Credits the game can hold.
function Market.parseAmount(text: string): number?
	local digits = string.gsub(text, "[%s,]", "")
	if digits == "" or string.find(digits, "%D") or #digits > 16 then
		return nil
	end
	local amount = tonumber(digits)
	return if amount and amount <= Config.MaxCredits then amount else nil
end

-- The line for a request the server refused.
function Market.refusal(code: string, min: number?): string
	if code == "TooLow" then
		return if min then `YOU NEED {Market.credits(min)} OR MORE` else "SOMEONE BID HIGHER"
	end
	return REFUSALS[code] or TRY_AGAIN
end

local function printed(serial: number): string
	return if CardLook.isLowSerial(serial) then CardLook.lowSerialText(serial) else CardLook.faceSerial(serial)
end

-- The line for something that settled.
function Market.news(item: { kind: string, cardName: string, serial: number, price: number? }): string
	local card = `{string.upper(item.cardName)} {printed(item.serial)}`
	if item.kind == "Outbid" then
		return `OUTBID ON {card}. YOUR CREDITS ARE BACK.`
	elseif item.kind == "Won" then
		return `YOU WON {card}`
	elseif item.kind == "Sold" then
		return `SOLD {card} FOR {Market.credits(item.price or 0)}`
	end
	return `{card} DID NOT SELL`
end

return Market
