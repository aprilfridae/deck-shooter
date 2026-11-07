local harness = require("./harness")
local Rebirth = require("../src/shared/CardCore/Rebirth")
local SaveData = require("../src/shared/CardCore/SaveData")

local describe, it, expect = harness.describe, harness.it, harness.expect

describe("Rebirth", function()
	it("costs 25000, then 2.5 times the last", function()
		expect(Rebirth.price(0)).toBe(25000)
		expect(Rebirth.price(1)).toBe(62500)
		expect(Rebirth.price(2)).toBe(156250)
	end)

	it("needs the full price", function()
		local data = SaveData.new()
		data.credits = 24999
		local ok, code = Rebirth.perform(data)
		expect(ok).toBe(false)
		expect(code).toBe("NotEnoughCredits")
		expect(data.rebirths).toBe(0)
		expect(data.credits).toBe(24999)
	end)

	it("goes through at exactly the price", function()
		local data = SaveData.new()
		data.credits = 25000
		expect((Rebirth.perform(data))).toBe(true)
		expect(data.credits).toBe(0)
	end)

	it("takes all Credits and keeps everything else", function()
		local data = SaveData.new()
		data.credits = 80000
		data.creditRemainder = 0.5
		data.packs.Prototype = 3
		data.catalysts = 2
		local stacks, deck = table.clone(data.stacks), data.deck
		expect((Rebirth.perform(data))).toBe(true)
		expect(data.credits).toBe(0)
		expect(data.creditRemainder).toBe(0)
		expect(data.rebirths).toBe(1)
		expect(data.packs.Prototype).toBe(3)
		expect(data.catalysts).toBe(2)
		expect(data.deck).toBe(deck)
		for key, count in stacks do
			expect(data.stacks[key]).toBe(count)
		end
	end)
end)
