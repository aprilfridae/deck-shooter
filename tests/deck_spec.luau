local harness = require("./harness")
local Deck = require("../src/shared/CardCore/Deck")
local Inventory = require("../src/shared/CardCore/Inventory")
local SaveData = require("../src/shared/CardCore/SaveData")

local describe, it, expect = harness.describe, harness.it, harness.expect

local function slot(cardId, tier)
	return { cardId = cardId, tier = tier or "Field" }
end

describe("Deck", function()
	it("accepts 3 different owned cards", function()
		local data = SaveData.new()
		Inventory.add(data, "aegis_shell", "Field", "Base", 1)
		local slots = { slot("aegis_shell"), slot("overclock"), slot("recon_pulse") }
		expect(Deck.set(data, slots)).toBe(true)
		expect(data.deck[1].cardId).toBe("aegis_shell")
	end)

	it("rejects 2 or 4 cards with WrongSize", function()
		local data = SaveData.new()
		local _, two = Deck.set(data, { slot("phase_dash"), slot("overclock") })
		expect(two).toBe("WrongSize")
		Inventory.add(data, "aegis_shell", "Field", "Base", 1)
		local _, four = Deck.set(data, { slot("phase_dash"), slot("overclock"), slot("recon_pulse"), slot("aegis_shell") })
		expect(four).toBe("WrongSize")
	end)

	it("rejects the same card at two tiers with DuplicateCard", function()
		local data = SaveData.new()
		Inventory.add(data, "overclock", "BlackSite", "Base", 1)
		local ok, code = Deck.set(data, { slot("overclock"), slot("overclock", "BlackSite"), slot("recon_pulse") })
		expect(ok).toBe(false)
		expect(code).toBe("DuplicateCard")
	end)

	it("rejects unknown cards and tiers", function()
		local data = SaveData.new()
		local _, card = Deck.set(data, { slot("nope"), slot("overclock"), slot("recon_pulse") })
		expect(card).toBe("UnknownCard")
		local _, tier = Deck.set(data, { slot("phase_dash", "Mythic"), slot("overclock"), slot("recon_pulse") })
		expect(tier).toBe("InvalidTier")
	end)

	it("rejects a tier the player does not own with NotOwned", function()
		local data = SaveData.new()
		local _, code = Deck.set(data, { slot("phase_dash", "Prototype"), slot("overclock"), slot("recon_pulse") })
		expect(code).toBe("NotOwned")
	end)

	it("counts a variant-only copy as owning that tier", function()
		local data = SaveData.new()
		Inventory.add(data, "aegis_shell", "BlackSite", "Chromatic", 1)
		expect(Deck.set(data, { slot("aegis_shell", "BlackSite"), slot("overclock"), slot("recon_pulse") })).toBe(true)
	end)

	it("leaves the old deck in place on failure", function()
		local data = SaveData.new()
		local before = table.clone(data.deck)
		Deck.set(data, { slot("nope"), slot("overclock"), slot("recon_pulse") })
		expect(data.deck).toEqual(before)
	end)

	it("stores a copy of the slots, not the original table", function()
		local data = SaveData.new()
		local slots = { slot("phase_dash"), slot("overclock"), slot("recon_pulse") }
		Deck.set(data, slots)
		slots[1].tier = "Prototype"
		expect(data.deck[1].tier).toBe("Field")
	end)
end)
