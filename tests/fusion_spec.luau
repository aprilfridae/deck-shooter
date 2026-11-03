local harness = require("./harness")
local Deck = require("../src/shared/CardCore/Deck")
local Fusion = require("../src/shared/CardCore/Fusion")
local Inventory = require("../src/shared/CardCore/Inventory")
local SaveData = require("../src/shared/CardCore/SaveData")

local describe, it, expect = harness.describe, harness.it, harness.expect

local function base()
	return 0.5 -- Variant.roll gives Base
end

local function req(cardId, tier, flags)
	flags = flags or {}
	return {
		cardId = cardId,
		tier = tier,
		useCatalyst = flags.useCatalyst == true,
		includeVariants = flags.includeVariants == true,
	}
end

describe("Fusion", function()
	it("turns 5 Field into 1 Black-Site for 100 Credits", function()
		local data = SaveData.new()
		Inventory.add(data, "arc_mine", "Field", "Base", 5)
		data.credits = 150
		local ok, result = Fusion.fuse(data, req("arc_mine", "Field"), base)
		expect(ok).toBe(true)
		expect(result).toEqual({ cardId = "arc_mine", tier = "BlackSite", variant = "Base" })
		expect(Inventory.count(data, "arc_mine", "Field")).toBe(0)
		expect(Inventory.count(data, "arc_mine", "BlackSite")).toBe(1)
		expect(data.credits).toBe(50)
	end)

	it("charges 600 for Black-Site to Prototype", function()
		local data = SaveData.new()
		Inventory.add(data, "arc_mine", "BlackSite", "Base", 5)
		data.credits = 600
		local ok, result = Fusion.fuse(data, req("arc_mine", "BlackSite"), base)
		expect(ok).toBe(true)
		expect(result.tier).toBe("Prototype")
		expect(data.credits).toBe(0)
	end)

	it("keeps copies past the 5 it spends", function()
		local data = SaveData.new()
		Inventory.add(data, "arc_mine", "Field", "Base", 7)
		data.credits = 100
		Fusion.fuse(data, req("arc_mine", "Field"), base)
		expect(Inventory.count(data, "arc_mine", "Field")).toBe(2)
	end)

	it("refuses Prototype with TopTier", function()
		local data = SaveData.new()
		Inventory.add(data, "arc_mine", "Prototype", "Base", 5)
		data.credits = 9999
		local ok, code = Fusion.fuse(data, req("arc_mine", "Prototype"), base)
		expect(ok).toBe(false)
		expect(code).toBe("TopTier")
	end)

	it("refuses unknown cards and tiers", function()
		local data = SaveData.new()
		local _, card = Fusion.fuse(data, req("nope", "Field"), base)
		expect(card).toBe("UnknownCard")
		local _, tier = Fusion.fuse(data, req("arc_mine", "Mythic"), base)
		expect(tier).toBe("InvalidTier")
	end)

	it("refuses 4 copies without a Catalyst", function()
		local data = SaveData.new()
		Inventory.add(data, "arc_mine", "Field", "Base", 4)
		data.credits = 100
		local _, code = Fusion.fuse(data, req("arc_mine", "Field"), base)
		expect(code).toBe("NotEnoughCopies")
	end)

	it("needs only 4 copies with a Catalyst, spends it, and still charges the fee", function()
		local data = SaveData.new()
		Inventory.add(data, "arc_mine", "Field", "Base", 4)
		data.catalysts, data.credits = 2, 100
		local ok = Fusion.fuse(data, req("arc_mine", "Field", { useCatalyst = true }), base)
		expect(ok).toBe(true)
		expect(data.catalysts).toBe(1)
		expect(data.credits).toBe(0)
		expect(Inventory.count(data, "arc_mine", "Field")).toBe(0)
		expect(Inventory.count(data, "arc_mine", "BlackSite")).toBe(1)
	end)

	it("does not spend a Catalyst the request did not ask for", function()
		local data = SaveData.new()
		Inventory.add(data, "arc_mine", "Field", "Base", 5)
		data.catalysts, data.credits = 1, 100
		Fusion.fuse(data, req("arc_mine", "Field"), base)
		expect(data.catalysts).toBe(1)
	end)

	it("returns NoCatalyst with no Catalyst", function()
		local data = SaveData.new()
		Inventory.add(data, "arc_mine", "Field", "Base", 5)
		data.credits = 100
		local _, code = Fusion.fuse(data, req("arc_mine", "Field", { useCatalyst = true }), base)
		expect(code).toBe("NoCatalyst")
	end)

	it("can produce a variant result", function()
		local data = SaveData.new()
		Inventory.add(data, "arc_mine", "Field", "Base", 5)
		data.credits = 100
		local _, result = Fusion.fuse(data, req("arc_mine", "Field"), function()
			return 0
		end)
		expect(result.variant).toBe("ZeroDay")
		expect(Inventory.count(data, "arc_mine", "BlackSite", "ZeroDay")).toBe(1)
	end)

	-- Review Focus 1
	it("moves an equipped slot up when its last copy is spent", function()
		local data = SaveData.new()
		Inventory.add(data, "phase_dash", "Field", "Base", 4) -- plus the starter = 5
		data.credits = 100
		Fusion.fuse(data, req("phase_dash", "Field"), base)
		expect(data.deck[1]).toEqual({ cardId = "phase_dash", tier = "BlackSite" })
		expect((Deck.check(data, data.deck))).toBe(true)
	end)

	it("leaves the slot alone when a copy remains at that tier", function()
		local data = SaveData.new()
		Inventory.add(data, "phase_dash", "Field", "Base", 5)
		data.credits = 100
		Fusion.fuse(data, req("phase_dash", "Field"), base)
		expect(data.deck[1].tier).toBe("Field")
	end)

	-- Review Focus 2
	it("refuses to spend a variant unless confirmed", function()
		local data = SaveData.new()
		Inventory.add(data, "arc_mine", "Field", "Base", 3)
		Inventory.add(data, "arc_mine", "Field", "Chromatic", 2)
		data.credits = 100
		local ok, code = Fusion.fuse(data, req("arc_mine", "Field"), base)
		expect(ok).toBe(false)
		expect(code).toBe("VariantsNotConfirmed")
		expect(Inventory.count(data, "arc_mine", "Field", "Chromatic")).toBe(2)
		expect(data.credits).toBe(100)
	end)

	it("uses Base copies first and only needed variants when confirmed", function()
		local data = SaveData.new()
		Inventory.add(data, "arc_mine", "Field", "Base", 3)
		Inventory.add(data, "arc_mine", "Field", "Chromatic", 2)
		Inventory.add(data, "arc_mine", "Field", "ZeroDay", 1)
		data.credits = 100
		local ok = Fusion.fuse(data, req("arc_mine", "Field", { includeVariants = true }), base)
		expect(ok).toBe(true)
		expect(Inventory.count(data, "arc_mine", "Field", "Base")).toBe(0)
		expect(Inventory.count(data, "arc_mine", "Field", "Chromatic")).toBe(0)
		expect(Inventory.count(data, "arc_mine", "Field", "ZeroDay")).toBe(1)
	end)

	it("spends the rarest variant last", function()
		local data = SaveData.new()
		Inventory.add(data, "arc_mine", "Field", "Redacted", 4)
		Inventory.add(data, "arc_mine", "Field", "ZeroDay", 2)
		data.credits = 100
		Fusion.fuse(data, req("arc_mine", "Field", { includeVariants = true }), base)
		expect(Inventory.count(data, "arc_mine", "Field", "Redacted")).toBe(0)
		expect(Inventory.count(data, "arc_mine", "Field", "ZeroDay")).toBe(1)
	end)

	-- Review Focus 3
	it("changes nothing when Credits run short", function()
		local data = SaveData.new()
		Inventory.add(data, "arc_mine", "Field", "Base", 5)
		data.catalysts, data.credits = 1, 99
		local ok, code = Fusion.fuse(data, req("arc_mine", "Field", { useCatalyst = true }), base)
		expect(ok).toBe(false)
		expect(code).toBe("NotEnoughCredits")
		expect(data.catalysts).toBe(1)
		expect(data.credits).toBe(99)
		expect(Inventory.count(data, "arc_mine", "Field")).toBe(5)
		expect(Inventory.count(data, "arc_mine", "BlackSite")).toBe(0)
	end)
end)
