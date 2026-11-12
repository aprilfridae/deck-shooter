local harness = require("./harness")
local Requests = require("../src/shared/CardCore/Requests")

local describe, it, expect = harness.describe, harness.it, harness.expect

local function slots()
	return {
		{ cardId = "phase_dash", tier = "Field" },
		{ cardId = "overclock", tier = "BlackSite" },
		{ cardId = "siphon", tier = "Prototype" },
	}
end

describe("Requests.parsePack", function()
	it("accepts only real pack ids", function()
		expect(Requests.parsePack("ZeroDay")).toBe("ZeroDay")
		expect(Requests.parsePack("Nonsense")).toBe(nil)
		expect(Requests.parsePack(5)).toBe(nil)
	end)
end)

describe("Requests.parseFuse", function()
	it("accepts a valid request", function()
		local r = Requests.parseFuse({
			cardId = "siphon",
			tier = "Field",
			useCatalyst = true,
			includeVariants = true,
		})
		expect(r).toEqual({ cardId = "siphon", tier = "Field", useCatalyst = true, includeVariants = true })
	end)

	-- Review Focus 4
	it("rejects garbage without throwing", function()
		local junk: { any } = {
			42,
			"x",
			true,
			{},
			{ cardId = {} },
			{ cardId = "siphon", tier = 0 / 0 },
			{ cardId = "siphon", tier = {} },
			{ cardId = 0 / 0, tier = "Field" },
			{ cardId = string.rep("a", 100000), tier = "Field" },
		}
		for _, raw in junk do
			expect(Requests.parseFuse(raw)).toBeNil()
		end
		expect(Requests.parseFuse(nil)).toBeNil()
	end)

	it("treats non-boolean flags as false", function()
		local r = Requests.parseFuse({ cardId = "siphon", tier = "Field", useCatalyst = "yes", includeVariants = 1 })
		expect(r.useCatalyst).toBe(false)
		expect(r.includeVariants).toBe(false)
	end)

	it("drops extra fields", function()
		local r = Requests.parseFuse({ cardId = "siphon", tier = "Field", credits = 999999 })
		expect(r).toEqual({ cardId = "siphon", tier = "Field", useCatalyst = false, includeVariants = false })
	end)
end)

describe("Requests.parseDeck", function()
	it("accepts 3 valid slots", function()
		expect(Requests.parseDeck(slots())).toEqual(slots())
	end)

	it("drops extra slot fields", function()
		local raw = slots()
		raw[1].owner = "someone"
		expect(Requests.parseDeck(raw)).toEqual(slots())
	end)

	it("rejects anything that is not a 3-item array", function()
		local two = slots()
		two[3] = nil
		local four = slots()
		four[4] = { cardId = "aegis_shell", tier = "Field" }
		local extraKey: any = slots()
		extraKey.extra = 1
		for _, raw in { 42, "x", {}, two, four, extraKey } do
			expect(Requests.parseDeck(raw)).toBeNil()
		end
		expect(Requests.parseDeck(nil)).toBeNil()
	end)

	it("rejects bad slots", function()
		local badCard: any = slots()
		badCard[2] = { cardId = 5, tier = "Field" }
		local badTier: any = slots()
		badTier[2].tier = 0 / 0
		local notTable: any = slots()
		notTable[2] = "overclock"
		for _, raw in { badCard, badTier, notTable } do
			expect(Requests.parseDeck(raw)).toBeNil()
		end
	end)

	it("rejects a table that loops on itself", function()
		local raw: any = {}
		raw[1], raw[2], raw[3] = raw, raw, raw
		expect(Requests.parseDeck(raw)).toBeNil()
	end)

	it("takes a positive whole user id", function()
		expect(Requests.parseUserId(5)).toBe(5)
		expect(Requests.parseUserId(-1)).toBe(nil)
		expect(Requests.parseUserId(1.5)).toBe(nil)
		expect(Requests.parseUserId("5")).toBe(nil)
	end)

	it("takes a comment for a profile", function()
		local request = Requests.parseComment({ owner = 5, text = "hi" })
		expect(request.owner).toBe(5)
		expect(request.text).toBe("hi")
		expect(Requests.parseComment({ owner = 5, text = "" })).toBe(nil)
		expect(Requests.parseComment({ text = "hi" })).toBe(nil)
	end)

	it("takes a comment to act on", function()
		local request = Requests.parseCommentTarget({ owner = 5, author = 6 })
		expect(request.owner).toBe(5)
		expect(request.author).toBe(6)
		expect(Requests.parseCommentTarget({ owner = 5 })).toBe(nil)
	end)
end)

describe("Requests for the auction house", function()
	local function listing(): any
		return { cardId = "aegis_shell", tier = "Prototype", variant = "Base", serial = 4, startBid = 100, hours = 6, buyNow = 500 }
	end
	local BAD_NUMBERS: { any } = { 1.5, -1, 0 / 0, math.huge, "5", {}, true }

	it("parses a listing, with or without Buy Now", function()
		expect(Requests.parseListing(listing())).toEqual(listing())
		local plain = listing()
		plain.buyNow = nil
		expect(Requests.parseListing(plain)).toEqual(plain)
	end)

	it("drops fields it doesn't know", function()
		local extra = listing()
		extra.credits = 99999
		expect(Requests.parseListing(extra)).toEqual(listing())
	end)

	it("refuses a listing of the wrong shape", function()
		expect(Requests.parseListing(nil)).toBe(nil)
		expect(Requests.parseListing("junk")).toBe(nil)
		for _, field in { "cardId", "tier", "variant" } do
			for _, value in { 5, {}, string.rep("x", 65) } :: { any } do
				local bad = listing()
				bad[field] = value
				expect(Requests.parseListing(bad)).toBe(nil)
			end
		end
		for _, field in { "serial", "startBid", "hours", "buyNow" } do
			for _, value in BAD_NUMBERS do
				local bad = listing()
				bad[field] = value
				expect(Requests.parseListing(bad)).toBe(nil)
			end
		end
		for _, field in { "cardId", "serial", "startBid", "hours" } do
			local bad = listing()
			bad[field] = nil
			expect(Requests.parseListing(bad)).toBe(nil)
		end
	end)

	it("parses a bid and refuses the wrong shape", function()
		expect(Requests.parseBid({ id = "abc", amount = 250 })).toEqual({ id = "abc", amount = 250 })
		expect(Requests.parseBid({ id = "abc" })).toBe(nil)
		expect(Requests.parseBid({ amount = 5 })).toBe(nil)
		expect(Requests.parseBid({ id = "", amount = 5 })).toBe(nil)
		expect(Requests.parseBid({ id = string.rep("x", 65), amount = 5 })).toBe(nil)
		expect(Requests.parseBid({ id = { "abc" }, amount = 5 })).toBe(nil)
		expect(Requests.parseBid({ id = { id = "abc" }, amount = 5 })).toBe(nil)
		for _, value in BAD_NUMBERS do
			expect(Requests.parseBid({ id = "abc", amount = value })).toBe(nil)
		end
		expect(Requests.parseBid(nil)).toBe(nil)
	end)

	it("parses a stack and refuses a card, tier or variant that doesn't exist", function()
		local good = { cardId = "aegis_shell", tier = "Prototype", variant = "ZeroDay" }
		expect(Requests.parseStack(good)).toEqual(good)
		for _, change in { { cardId = "no_such_card" }, { tier = "Mythic" }, { variant = "Shiny" }, { cardId = 5 } } :: { any } do
			local bad = table.clone(good)
			for field, value in change do
				(bad :: any)[field] = value
			end
			expect(Requests.parseStack(bad)).toBe(nil)
		end
		expect(Requests.parseStack("junk")).toBe(nil)
	end)

	it("parses an auction id", function()
		expect(Requests.parseAuctionId("abc")).toBe("abc")
		expect(Requests.parseAuctionId("")).toBe(nil)
		expect(Requests.parseAuctionId(string.rep("x", 65))).toBe(nil)
		expect(Requests.parseAuctionId(5)).toBe(nil)
	end)
end)
