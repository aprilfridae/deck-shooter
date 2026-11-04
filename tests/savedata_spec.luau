local harness = require("./harness")
local Deck = require("../src/shared/CardCore/Deck")
local Inventory = require("../src/shared/CardCore/Inventory")
local SaveData = require("../src/shared/CardCore/SaveData")

local describe, it, expect = harness.describe, harness.it, harness.expect

local function withStack(key: string, n: number)
	local raw = SaveData.new()
	raw.stacks[key] = n
	return raw
end

describe("SaveData.load", function()
	it("takes a removed card out of the deck and refills it", function()
		local raw = SaveData.new()
		raw.stacks["arc_mine:Field:Base"] = 3
		raw.deck[1] = { cardId = "arc_mine", tier = "Field" }
		local loaded = SaveData.load(raw)
		for _, slot in loaded.deck do
			expect(slot.cardId == "arc_mine").toBe(false)
		end
		expect(#loaded.deck).toBe(3)
	end)

	it("returns a new save for nil or a non-table", function()
		for _, raw in { false, 42, "save" } do
			expect(SaveData.load(raw)).toEqual(SaveData.new())
		end
		expect(SaveData.load(nil)).toEqual(SaveData.new())
	end)

	it("round-trips a valid save unchanged", function()
		local raw = SaveData.new()
		raw.credits = 123
		raw.creditRemainder = 0.25
		raw.catalysts = 2
		raw.gunLevels = { 3, 1 }
		Inventory.add(raw, "aegis_shell", "BlackSite", "Chromatic", 2)
		expect(SaveData.load(raw)).toEqual(raw)
	end)

	it("fills fields missing from an older save", function()
		local loaded = SaveData.load({ version = 1, credits = 5 })
		expect(loaded.credits).toBe(5)
		expect(loaded.catalysts).toBe(0)
		expect(#loaded.deck).toBe(3)
	end)

	-- Review Focus 5
	it("refuses a save from a newer build", function()
		local loaded, code = SaveData.load({ version = 99 })
		expect(loaded).toBeNil()
		expect(code).toBe("NewerVersion")
	end)

	it("drops stacks with 0, negative, NaN or fractional counts", function()
		for _, n in { 0, -1, 0 / 0, 1.5, math.huge } do
			local loaded = SaveData.load(withStack("aegis_shell:Field:Base", n))
			expect(loaded.stacks["aegis_shell:Field:Base"]).toBeNil()
		end
	end)

	it("drops malformed stack keys", function()
		local raw = SaveData.new()
		raw.stacks["no_colons"] = 1
		raw.stacks["aegis_shell:Mythic:Base"] = 1
		raw.stacks["aegis_shell:Field:Shiny"] = 1
		raw.stacks[7] = 1
		local loaded = SaveData.load(raw)
		expect(loaded.stacks["no_colons"]).toBeNil()
		expect(loaded.stacks["aegis_shell:Mythic:Base"]).toBeNil()
		expect(loaded.stacks["aegis_shell:Field:Shiny"]).toBeNil()
		expect(loaded.stacks[7]).toBeNil()
	end)

	it("keeps stacks for unknown card ids, so a removed card can return", function()
		local loaded = SaveData.load(withStack("retired_card:Field:Base", 2))
		expect(loaded.stacks["retired_card:Field:Base"]).toBe(2)
	end)

	it("resets negative or NaN credits and catalysts to 0", function()
		local raw = SaveData.new()
		raw.credits = -5
		raw.creditRemainder = 0 / 0
		raw.catalysts = -1
		local loaded = SaveData.load(raw)
		expect(loaded.credits).toBe(0)
		expect(loaded.creditRemainder).toBe(0)
		expect(loaded.catalysts).toBe(0)
	end)

	it("drops absurdly large stack counts", function()
		local loaded = SaveData.load(withStack("aegis_shell:Prototype:ZeroDay", 1.7e308))
		expect(loaded.stacks["aegis_shell:Prototype:ZeroDay"]).toBeNil()
		local also = SaveData.load(withStack("aegis_shell:Prototype:ZeroDay", 1e7))
		expect(also.stacks["aegis_shell:Prototype:ZeroDay"]).toBeNil()
	end)

	it("keeps large but believable values", function()
		local raw = withStack("aegis_shell:Field:Base", 1000000)
		raw.credits = 2 ^ 53
		local loaded = SaveData.load(raw)
		expect(loaded.stacks["aegis_shell:Field:Base"]).toBe(1000000)
		expect(loaded.credits).toBe(2 ^ 53)
	end)

	it("resets absurdly large credits, catalysts and gun levels", function()
		local raw = SaveData.new()
		raw.credits = 1e300
		raw.catalysts = 1e300
		raw.gunLevels = { 1e300, 2 }
		local loaded = SaveData.load(raw)
		expect(loaded.credits).toBe(0)
		expect(loaded.catalysts).toBe(0)
		expect(loaded.gunLevels).toEqual({ 0, 2 })
	end)

	it("resets bad gun levels", function()
		local raw = SaveData.new()
		raw.gunLevels = { -1, "x" }
		expect(SaveData.load(raw).gunLevels).toEqual({ 0, 0 })
	end)

	it("moves a slot to the highest owned tier of that card", function()
		local raw = SaveData.new()
		raw.stacks["phase_dash:Field:Base"] = nil
		raw.stacks["phase_dash:BlackSite:Base"] = 1
		raw.stacks["phase_dash:Prototype:Chromatic"] = 1
		local loaded = SaveData.load(raw)
		expect(loaded.deck[1]).toEqual({ cardId = "phase_dash", tier = "Prototype" })
	end)

	it("replaces a lost card with another owned card", function()
		local raw = SaveData.new()
		raw.stacks["phase_dash:Field:Base"] = nil
		raw.stacks["aegis_shell:BlackSite:Base"] = 1
		local loaded = SaveData.load(raw)
		expect(loaded.deck[1]).toEqual({ cardId = "aegis_shell", tier = "BlackSite" })
	end)

	it("grants a starter copy when nothing else is owned", function()
		local raw = SaveData.new()
		raw.stacks = {}
		local loaded = SaveData.load(raw)
		expect(loaded.deck).toEqual(SaveData.new().deck)
		expect(Inventory.count(loaded, "phase_dash", "Field")).toBe(1)
	end)

	it("always returns a deck that passes Deck.check", function()
		local badDecks: { any } = {
			{},
			"deck",
			{ { cardId = "nope", tier = "Field" } },
			{ { cardId = 1, tier = {} }, 5, "x" },
			{
				{ cardId = "overclock", tier = "Field" },
				{ cardId = "overclock", tier = "Field" },
				{ cardId = "overclock", tier = "Field" },
			},
			{
				{ cardId = "phase_dash", tier = "Field" },
				{ cardId = "overclock", tier = "Field" },
				{ cardId = "recon_pulse", tier = "Field" },
				{ cardId = "aegis_shell", tier = "Field" },
			},
		}
		for _, deck in badDecks do
			local raw = SaveData.new()
			raw.deck = deck
			local loaded = SaveData.load(raw)
			expect((Deck.check(loaded, loaded.deck))).toBe(true)
		end
	end)

	it("does not grant extra copies to a save with a valid deck", function()
		local raw = SaveData.new()
		local loaded = SaveData.load(raw)
		expect(Inventory.count(loaded, "overclock", "Field")).toBe(1)
	end)
end)
