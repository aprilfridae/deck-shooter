local harness = require("./harness")
local Requests = require("../src/shared/CardCore/Requests")

local describe, it, expect = harness.describe, harness.it, harness.expect

local function slots()
	return {
		{ cardId = "phase_dash", tier = "Field" },
		{ cardId = "overclock", tier = "BlackSite" },
		{ cardId = "recon_pulse", tier = "Prototype" },
	}
end

describe("Requests.parseFuse", function()
	it("accepts a valid request", function()
		local r = Requests.parseFuse({
			cardId = "recon_pulse",
			tier = "Field",
			useCatalyst = true,
			includeVariants = true,
		})
		expect(r).toEqual({ cardId = "recon_pulse", tier = "Field", useCatalyst = true, includeVariants = true })
	end)

	-- Review Focus 4
	it("rejects garbage without throwing", function()
		local junk: { any } = {
			42,
			"x",
			true,
			{},
			{ cardId = {} },
			{ cardId = "recon_pulse", tier = 0 / 0 },
			{ cardId = "recon_pulse", tier = {} },
			{ cardId = 0 / 0, tier = "Field" },
			{ cardId = string.rep("a", 100000), tier = "Field" },
		}
		for _, raw in junk do
			expect(Requests.parseFuse(raw)).toBeNil()
		end
		expect(Requests.parseFuse(nil)).toBeNil()
	end)

	it("treats non-boolean flags as false", function()
		local r = Requests.parseFuse({ cardId = "recon_pulse", tier = "Field", useCatalyst = "yes", includeVariants = 1 })
		expect(r.useCatalyst).toBe(false)
		expect(r.includeVariants).toBe(false)
	end)

	it("drops extra fields", function()
		local r = Requests.parseFuse({ cardId = "recon_pulse", tier = "Field", credits = 999999 })
		expect(r).toEqual({ cardId = "recon_pulse", tier = "Field", useCatalyst = false, includeVariants = false })
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
