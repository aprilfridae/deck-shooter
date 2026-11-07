local harness = require("./harness")
local CardIndex = require("../src/shared/CardCore/CardIndex")
local Inventory = require("../src/shared/CardCore/Inventory")
local Variant = require("../src/shared/CardCore/Variant")

local describe, it, expect = harness.describe, harness.it, harness.expect

describe("CardIndex", function()
	it("lists every card at every tier", function()
		local index = CardIndex.build({})
		expect(#index.cards).toBe(4)
		expect(#index.cards[1].tiers).toBe(3)
		expect(index.total).toBe(12)
		expect(index.owned).toBe(0)
	end)

	it("adds up copies across variants", function()
		local stacks = {
			[Inventory.key("overclock", "Field", "Base")] = 2,
			[Inventory.key("overclock", "Field", "Holo")] = 1,
			[Inventory.key("overclock", "Prototype", "Base")] = 1,
		}
		local index = CardIndex.build(stacks)
		expect(index.owned).toBe(2)
		for _, card in index.cards do
			if card.cardId == "overclock" then
				expect(card.tiers[1].count).toBe(3)
				expect(card.tiers[2].count).toBe(0)
				expect(card.tiers[3].count).toBe(1)
			end
		end
	end)

	it("shows the rarest variant owned at each tier", function()
		local stacks = {
			[Inventory.key("phase_dash", "Field", "Base")] = 2,
			[Inventory.key("phase_dash", "Field", "ZeroDay")] = 1,
		}
		for _, card in CardIndex.build(stacks).cards do
			if card.cardId == "phase_dash" then
				expect(card.tiers[1].count).toBe(3)
				expect(card.tiers[1].variant).toBe(Variant.ZeroDay)
				expect(card.tiers[2].variant).toBe(Variant.Base)
			end
		end
		expect(CardIndex.variant(stacks, "phase_dash", "Field")).toBe(Variant.ZeroDay)
		expect(CardIndex.variant(stacks, "overclock", "Field")).toBe(Variant.Base)
	end)

	it("keeps the cards in name order", function()
		local index = CardIndex.build({})
		for i = 2, #index.cards do
			expect(index.cards[i - 1].name < index.cards[i].name).toBe(true)
		end
	end)

	it("ignores a card that no longer exists", function()
		local index = CardIndex.build({ [Inventory.key("gone", "Field", "Base")] = 1 })
		expect(index.owned).toBe(0)
	end)

	it("lists only what is owned for choosing a card", function()
		local stacks = {
			[Inventory.key("overclock", "Field", "Base")] = 2,
			[Inventory.key("overclock", "BlackSite", "Base")] = 1,
			[Inventory.key("recon_pulse", "Field", "Base")] = 1,
		}
		local owned = CardIndex.owned(stacks)
		expect(#owned).toBe(3)
		expect(owned[1].cardId).toBe("overclock")
		expect(owned[1].tier).toBe("Field")
		expect(owned[2].tier).toBe("BlackSite")
		expect(owned[3].cardId).toBe("recon_pulse")
	end)
end)
