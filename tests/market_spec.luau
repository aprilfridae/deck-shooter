local harness = require("./harness")
local Auction = require("../src/shared/CardCore/Auction")
local Cards = require("../src/shared/CardCore/Cards")
local Market = require("../src/shared/CardCore/Market")

local describe, it, expect = harness.describe, harness.it, harness.expect

local function record(changes: any?): any
	local made: any = Auction.record("a1", 7, "Seller", {
		cardId = "aegis_shell",
		tier = "Prototype",
		variant = "Base",
		serial = 4,
		startBid = 100,
		buyNow = 500,
		endsAt = 9000,
	})
	for field, value in changes or {} do
		made[field] = if value == "none" then nil else value
	end
	return made
end

local function listing(id: string, tier: string, variant: string, serial: number, endsAt: number, cardId: string?): any
	return { id = id, cardId = cardId or "phase_dash", tier = tier, variant = variant, serial = serial, price = 10, endsAt = endsAt, hasBid = false }
end

local function ids(listings: { any }): { string }
	local out = {}
	for _, item in listings do
		table.insert(out, item.id)
	end
	return out
end

local function nameOf(cardId: string): string
	return Cards.byId[cardId].name
end

describe("Market entries", function()
	it("packs an auction small and unpacks it whole", function()
		local shown = Market.unpack(Market.pack(record({ bid = 250, bidder = 9 })))
		expect(shown).toEqual({
			id = "a1",
			cardId = "aegis_shell",
			tier = "Prototype",
			variant = "Base",
			serial = 4,
			price = 250,
			buyNow = 500,
			endsAt = 9000,
			hasBid = true,
		})
		local plain = Market.unpack(Market.pack(record({ buyNow = "none" }))) :: any
		expect(plain.price).toBe(100)
		expect(plain.hasBid).toBe(false)
		expect(plain.buyNow).toBe(nil)
	end)

	it("refuses a malformed entry", function()
		expect(Market.unpack("junk")).toBe(nil)
		for _, change in { { i = "none" }, { s = "four" }, { e = 12.5 }, { c = 5 }, { p = -1 } } :: { any } do
			local entry = Market.pack(record())
			for field, value in change do
				entry[field] = if value == "none" then nil else value
			end
			expect(Market.unpack(entry)).toBe(nil)
		end
	end)
end)

describe("Market search and sort", function()
	it("matches a card's name whatever the capitals or spaces", function()
		expect(Market.matches("phase", "Phase Dash")).toBe(true)
		expect(Market.matches("PHASED", "Phase Dash")).toBe(true)
		expect(Market.matches("  ", "Overclock")).toBe(true)
		expect(Market.matches("", "Overclock")).toBe(true)
		expect(Market.matches("shell x", "Aegis Shell")).toBe(false)
		expect(Market.matches("a.c", "Aegis Shell")).toBe(false) -- typed text is never a pattern
	end)

	it("ranks rarity by tier, then variant", function()
		expect(Market.rarity("Prototype", "Base") > Market.rarity("BlackSite", "ZeroDay")).toBe(true)
		expect(Market.rarity("BlackSite", "Base") > Market.rarity("Field", "ZeroDay")).toBe(true)
		expect(Market.rarity("Field", "ZeroDay") > Market.rarity("Field", "Chromatic")).toBe(true)
		expect(Market.rarity("Field", "Chromatic") > Market.rarity("Field", "Redacted")).toBe(true)
		expect(Market.rarity("Field", "Redacted") > Market.rarity("Field", "Base")).toBe(true)
	end)

	it("sorts three ways, breaking ties by which ends sooner", function()
		local list = {
			listing("a", "Field", "Base", 50, 300),
			listing("b", "Prototype", "Base", 900, 100),
			listing("c", "BlackSite", "ZeroDay", 7, 200),
			listing("d", "Field", "Base", 50, 150),
		}
		local before = ids(list)
		expect(ids(Market.sorted(list, "soon"))).toEqual({ "b", "d", "c", "a" })
		expect(ids(Market.sorted(list, "serial"))).toEqual({ "c", "d", "a", "b" })
		expect(ids(Market.sorted(list, "rarity"))).toEqual({ "b", "c", "d", "a" })
		expect(ids(list)).toEqual(before)
	end)

	it("filters by search, then sorts", function()
		local list = {
			listing("a", "Field", "Base", 5, 300, "phase_dash"),
			listing("b", "Field", "Base", 2, 100, "overclock"),
			listing("c", "Field", "Base", 1, 200, "phase_dash"),
		}
		expect(ids(Market.visible(list, "phase", "serial", nameOf))).toEqual({ "c", "a" })
		expect(ids(Market.visible(list, "", "soon", nameOf))).toEqual({ "b", "c", "a" })
		expect(Market.visible(list, "zzz", "soon", nameOf)).toEqual({})
		expect(Market.visible({}, "", "soon", nameOf)).toEqual({})
	end)
end)

describe("Market wording", function()
	it("says how long is left, and when it's urgent", function()
		local cases: { { any } } = {
			{ 0, "ENDED", false },
			{ -5, "ENDED", false },
			{ 45, "45S", true },
			{ 72, "1M 12S", true },
			{ 120, "2M", true },
			{ 121, "2M", false },
			{ 2280, "38M", false },
			{ 7500, "2H 05M", false },
			{ 36000, "10H", false },
			{ 75600, "21H", false },
		}
		for _, case in cases do
			local text, urgent = Market.timeLeft(case[1])
			expect(text).toBe(case[2])
			expect(urgent).toBe(case[3])
		end
	end)

	it("says how long is left in one short word, for under a card", function()
		local cases: { { any } } = { { 0, "ENDED" }, { 45, "45S" }, { 72, "1M" }, { 2280, "38M" }, { 7500, "2H" }, { 75600, "21H" } }
		for _, case in cases do
			expect((Market.shortTime(case[1]))).toBe(case[2])
		end
		local _, urgent = Market.shortTime(72)
		expect(urgent).toBe(true)
	end)

	it("writes a price short enough to sit under a card", function()
		local cases: { { any } } = {
			{ 0, "0" },
			{ 999, "999" },
			{ 12480, "12,480" },
			{ 99999, "99,999" },
			{ 100000, "100K" },
			{ 123456, "123K" },
			{ 999999, "999K" },
			{ 1000000, "1.0M" },
			{ 1250000, "1.2M" },
			{ 12500000, "12M" },
			{ 3400000000, "3.4B" },
		}
		for _, case in cases do
			expect(Market.short(case[1])).toBe(case[2])
			expect(#Market.short(case[1]) <= 6).toBe(true)
		end
	end)

	it("writes Credits with commas", function()
		expect(Market.credits(0)).toBe("0")
		expect(Market.credits(999)).toBe("999")
		expect(Market.credits(1000)).toBe("1,000")
		expect(Market.credits(12480)).toBe("12,480")
		expect(Market.credits(1234567)).toBe("1,234,567")
	end)

	it("reads a typed amount, or refuses it", function()
		expect(Market.parseAmount("2783")).toBe(2783)
		expect(Market.parseAmount("2,783")).toBe(2783)
		expect(Market.parseAmount(" 2 783 ")).toBe(2783)
		expect(Market.parseAmount("0")).toBe(0)
		for _, text in { "", "   ", "abc", "12.5", "-5", "1e9", string.rep("9", 30) } do
			expect(Market.parseAmount(text)).toBe(nil)
		end
	end)

	it("has a plain line for every refusal", function()
		expect(Market.refusal("TooLow", 2783)).toBe("YOU NEED 2,783 OR MORE")
		expect(Market.refusal("TooLow")).toBe("SOMEONE BID HIGHER")
		local lines = {
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
		for code, line in lines do
			expect(Market.refusal(code)).toBe(line)
		end
		for _, code in { "Busy", "Unavailable", "SaveFailed", "RateLimited", "Failed", "NeverHeardOfIt" } do
			expect(Market.refusal(code)).toBe("TRY AGAIN IN A MOMENT")
		end
	end)

	it("writes the news of what settled", function()
		local function news(kind: string, serial: number, price: number?): string
			return Market.news({ kind = kind, cardName = "Phase Dash", serial = serial, price = price })
		end
		expect(news("Outbid", 42)).toBe("OUTBID ON PHASE DASH 0042. YOUR CREDITS ARE BACK.")
		expect(news("Won", 42)).toBe("YOU WON PHASE DASH 0042")
		expect(news("Sold", 42, 4200)).toBe("SOLD PHASE DASH 0042 FOR 4,200")
		expect(news("Unsold", 42)).toBe("PHASE DASH 0042 DID NOT SELL")
		expect(news("Won", 7)).toBe("YOU WON PHASE DASH 07")
	end)
end)
