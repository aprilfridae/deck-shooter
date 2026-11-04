local harness = require("./harness")
local Cards = require("../src/shared/CardCore/Cards")
local Tier = require("../src/shared/CardCore/Tier")

local describe, it, expect = harness.describe, harness.it, harness.expect

describe("Cards", function()
	it("pins spec values", function()
		expect(Cards.stat("phase_dash", "Prototype", "distance")).toBe(16)
		expect(Cards.stat("phase_dash", "BlackSite", "cooldown")).toBe(11)
		expect(Cards.stat("overclock", "BlackSite", "fireRateBonus")).toBe(0.17)
		expect(Cards.stat("recon_pulse", "Field", "revealTime")).toBe(2)
		expect(Cards.stat("aegis_shell", "Prototype", "shieldHp")).toBe(64)
		expect(Cards.stat("arc_mine", "BlackSite", "slowPct")).toBe(0.28)
		expect(#Cards.sets.set_01).toBe(5)
		expect(#Cards.ids).toBe(5)
	end)

	it("stays inside the 20-25% ceiling on every stat", function()
		for _, id in Cards.ids do
			local card = Cards.byId[id]
			for stat, values in card.stats do
				local low = card.lowerIsBetter and card.lowerIsBetter[stat]
				local ratio = if low then values[1] / values[3] else values[3] / values[1]
				expect(ratio >= 1.20 - 1e-9 and ratio <= 1.25 + 1e-9).toBe(true)
			end
		end
	end)

	it("never gets worse by tier, and each tier beats the one below", function()
		for _, id in Cards.ids do
			local card = Cards.byId[id]
			for step = 2, #Tier.order do
				local better = false
				for stat, values in card.stats do
					local low = card.lowerIsBetter and card.lowerIsBetter[stat]
					local gain = if low then values[step - 1] - values[step] else values[step] - values[step - 1]
					expect(gain >= 0).toBe(true)
					better = better or gain > 0
				end
				expect(better).toBe(true)
			end
		end
	end)

	it("applies the Prototype data changes", function()
		expect(Cards.stat("aegis_shell", "Prototype", "duration")).toBe(3.75)
		expect(Cards.stat("arc_mine", "Prototype", "slowSeconds")).toBe(1.875)
		expect(Cards.byId.arc_mine.perk).toBe("hidden_until_triggered")
	end)

	it("has no ceiling exemptions left", function()
		for _, id in Cards.ids do
			expect(Cards.byId[id].ceilingExempt).toBeNil()
		end
	end)

	it("gives each card its spec cooldown", function()
		expect(Cards.cooldown("phase_dash", "Field")).toBe(12)
		expect(Cards.cooldown("phase_dash", "Prototype")).toBe(10)
		expect(Cards.cooldown("overclock", "BlackSite")).toBe(25)
		expect(Cards.cooldown("recon_pulse", "Field")).toBe(20)
		expect(Cards.cooldown("aegis_shell", "Prototype")).toBe(25)
		expect(Cards.cooldown("arc_mine", "Field")).toBe(30)
	end)

	it("scales perks by tier", function()
		expect(Cards.perkScale("Field")).toBe(0.8)
		expect(Cards.perkScale("BlackSite")).toBe(0.9)
		expect(Cards.perkScale("Prototype")).toBe(1)
	end)

	it("gives every card a perk except Overclock", function()
		for _, id in Cards.ids do
			if id ~= "overclock" then
				expect(type(Cards.byId[id].perk)).toBe("string")
			end
		end
		expect(Cards.byId.overclock.perk).toBeNil()
	end)

	it("recognises only real card ids", function()
		expect(Cards.isValid("arc_mine")).toBe(true)
		expect(Cards.isValid("nope")).toBe(false)
		expect(Cards.isValid(7)).toBe(false)
	end)
end)
