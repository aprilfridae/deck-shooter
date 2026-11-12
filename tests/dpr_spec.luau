local harness = require("./harness")
local Config = require("../src/shared/CardCore/Config")
local Dpr = require("../src/shared/CardCore/Dpr")

local describe, it, expect = harness.describe, harness.it, harness.expect

local function deckOf(a: string, b: string, c: string)
	return {
		{ cardId = "phase_dash", tier = a },
		{ cardId = "overclock", tier = b },
		{ cardId = "siphon", tier = c },
	}
end

describe("Dpr", function()
	it("sums tier points across the deck", function()
		expect(Dpr.compute(deckOf("Field", "Field", "Field"), { 0, 0 })).toBe(300)
		expect(Dpr.compute(deckOf("BlackSite", "Field", "Field"), { 0, 0 })).toBe(312)
		expect(Dpr.compute(deckOf("BlackSite", "BlackSite", "BlackSite"), { 0, 0 })).toBe(336)
		expect(Dpr.compute(deckOf("Prototype", "Prototype", "Prototype"), { 0, 0 })).toBe(375)
	end)

	it("adds a smaller weight for gun upgrades", function()
		expect(Dpr.compute(deckOf("Field", "Field", "Field"), { 2, 1 })).toBe(309)
	end)

	it("leaves a reachable 10-15% Aspiration band above common decks", function()
		local field = Dpr.compute(deckOf("Field", "Field", "Field"), { 0, 0 })
		local blackSite = Dpr.compute(deckOf("BlackSite", "BlackSite", "BlackSite"), { 0, 0 })
		local prototype = Dpr.compute(deckOf("Prototype", "Prototype", "Prototype"), { 0, 0 })
		for _, pair in { { field, blackSite }, { blackSite, prototype } } do
			local gain = pair[2] / pair[1]
			expect(gain >= 1.10 and gain <= 1.15).toBe(true)
		end
	end)

	it("makes one gun level worth less than one card tier step", function()
		expect(Config.GunPointsPerLevel < Config.TierPower.BlackSite - Config.TierPower.Field).toBe(true)
	end)
end)
