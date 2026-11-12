local harness = require("./harness")
local Cards = require("../src/shared/CardCore/Cards")
local Tier = require("../src/shared/CardCore/Tier")

local describe, it, expect = harness.describe, harness.it, harness.expect

describe("Cards", function()
	it("pins spec values", function()
		expect(Cards.stat("phase_dash", "Prototype", "distance")).toBe(16)
		expect(Cards.stat("phase_dash", "Field", "distance")).toBe(8)
		expect(Cards.stat("phase_dash", "BlackSite", "cooldown")).toBe(13)
		expect(Cards.stat("overclock", "BlackSite", "fireRateBonus")).toBe(0.22)
		expect(Cards.stat("aegis_shell", "Prototype", "shieldHp")).toBe(104)
		expect(Cards.stat("switchback", "Prototype", "range")).toBe(80)
		expect(Cards.stat("kickplate", "Field", "height")).toBe(24)
		expect(Cards.stat("siphon", "BlackSite", "speedSteal")).toBe(0.22)
		expect(#Cards.sets.set_01).toBe(6)
		expect(#Cards.ids).toBe(6)
	end)

	it("no longer has Recon Pulse", function()
		expect(Cards.isValid("recon_pulse")).toBe(false)
	end)

	it("makes Prototype about twice Field on every stat", function()
		for _, id in Cards.ids do
			local card = Cards.byId[id]
			for stat, values in card.stats do
				local low = card.lowerIsBetter and card.lowerIsBetter[stat]
				local ratio = if low then values[1] / values[3] else values[3] / values[1]
				expect(ratio >= 1.4 - 1e-9 and ratio <= 2 + 1e-9).toBe(true)
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
		expect(Cards.stat("aegis_shell", "Prototype", "duration")).toBe(5)
	end)

	it("pushes enemies whenever an Aegis Shell ends", function()
		expect(Cards.byId.aegis_shell.perk).toBe("end_knockback")
	end)

	it("has no ceiling exemptions left", function()
		for _, id in Cards.ids do
			expect(Cards.byId[id].ceilingExempt).toBeNil()
		end
	end)

	it("gives each card its spec cooldown", function()
		expect(Cards.cooldown("phase_dash", "Field")).toBe(16)
		expect(Cards.cooldown("phase_dash", "Prototype")).toBe(10)
		expect(Cards.cooldown("overclock", "BlackSite")).toBe(25)
		expect(Cards.cooldown("siphon", "Field")).toBe(18)
		expect(Cards.cooldown("switchback", "Prototype")).toBe(12)
		expect(Cards.cooldown("aegis_shell", "Prototype")).toBe(25)
	end)

	it("scales perks by tier", function()
		expect(Cards.perkScale("Field")).toBe(0.5)
		expect(Cards.perkScale("BlackSite")).toBe(0.75)
		expect(Cards.perkScale("Prototype")).toBe(1)
	end)

	it("gives Phase Dash and Aegis Shell a perk, and nothing else", function()
		for _, id in Cards.ids do
			local perk = Cards.byId[id].perk
			if id == "phase_dash" or id == "aegis_shell" then
				expect(type(perk)).toBe("string")
			else
				expect(perk).toBeNil()
			end
		end
	end)

	it("recognises only real card ids", function()
		expect(Cards.isValid("aegis_shell")).toBe(true)
		expect(Cards.isValid("arc_mine")).toBe(false)
		expect(Cards.isValid("nope")).toBe(false)
		expect(Cards.isValid(7)).toBe(false)
	end)
end)
