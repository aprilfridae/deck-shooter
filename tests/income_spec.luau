local harness = require("./harness")
local Cards = require("../src/shared/CardCore/Cards")
local Income = require("../src/shared/CardCore/Income")
local Inventory = require("../src/shared/CardCore/Inventory")
local SaveData = require("../src/shared/CardCore/SaveData")

local describe, it, expect = harness.describe, harness.it, harness.expect

local function empty()
	local data = SaveData.new()
	data.stacks = {}
	return data
end

local function earned(data)
	return data.credits + data.creditRemainder
end

describe("Income.ratePerSecond", function()
	it("pays the spec rate per tier", function()
		for tier, rate in { Field = 0.1, BlackSite = 0.6, Prototype = 3.5 } do
			local data = empty()
			Inventory.add(data, "aegis_shell", tier, "Base", 1)
			expect(Income.ratePerSecond(data)).toBeCloseTo(rate)
		end
	end)

	it("pays half from the 11th copy", function()
		local data = empty()
		Inventory.add(data, "aegis_shell", "Field", "Base", 11)
		expect(Income.ratePerSecond(data)).toBeCloseTo(1.05)
	end)

	it("counts the soft cap per card and tier", function()
		local data = empty()
		Inventory.add(data, "aegis_shell", "Field", "Base", 10)
		Inventory.add(data, "aegis_shell", "BlackSite", "Base", 1)
		Inventory.add(data, "overclock", "Field", "Base", 1)
		expect(Income.ratePerSecond(data)).toBeCloseTo(1.7)
	end)

	it("multiplies by the variant", function()
		local data = empty()
		Inventory.add(data, "aegis_shell", "Field", "Chromatic", 1)
		expect(Income.ratePerSecond(data)).toBeCloseTo(0.15)
	end)

	it("puts the best-paying copies under the cap", function()
		local data = empty()
		Inventory.add(data, "aegis_shell", "Field", "Base", 10)
		Inventory.add(data, "aegis_shell", "Field", "Chromatic", 1)
		expect(Income.ratePerSecond(data)).toBeCloseTo(1.1) -- .15 + 9(.1) + .05
	end)

	it("adds 10% for a full set at any tier", function()
		local data = empty()
		for _, id in Cards.sets.set_01 do
			Inventory.add(data, id, "Field", "Base", 1)
		end
		expect(Income.ratePerSecond(data)).toBeCloseTo(0.66) -- 6 cards at .1, plus 10%
	end)

	it("gives no set bonus for a partial set", function()
		local data = SaveData.new()
		expect(Income.ratePerSecond(data)).toBeCloseTo(0.3)
	end)

	it("applies boost", function()
		local data = SaveData.new()
		expect(Income.ratePerSecond(data, 2)).toBeCloseTo(0.6)
	end)

	it("ignores stacks for unknown cards", function()
		local data = empty()
		data.stacks["removed_card:Field:Base"] = 3
		expect(Income.ratePerSecond(data)).toBeCloseTo(0)
	end)
end)

describe("Income.accrue", function()
	it("accumulates fractions across ticks", function()
		local data = SaveData.new()
		for _ = 1, 10 do
			Income.accrue(data, 1)
		end
		expect(earned(data)).toBeCloseTo(3)
		expect(data.credits == math.floor(data.credits)).toBe(true)
		expect(data.creditRemainder < 1).toBe(true)
	end)

	it("clamps a long tick to 5 seconds", function()
		local data = SaveData.new()
		Income.accrue(data, 3600)
		expect(earned(data)).toBeCloseTo(1.5)
	end)

	it("pays nothing for dt 0, negative or NaN", function()
		local data = SaveData.new()
		Income.accrue(data, 0)
		Income.accrue(data, -5)
		Income.accrue(data, 0 / 0)
		expect(earned(data)).toBe(0)
	end)

	it("pays nothing for an infinite dt", function()
		local data = SaveData.new()
		Income.accrue(data, math.huge)
		expect(earned(data)).toBe(0)
	end)

	it("never writes a non-finite amount into Credits", function()
		local data = SaveData.new()
		data.credits = 40
		data.stacks["aegis_shell:Prototype:ZeroDay"] = 1.7e308
		Income.accrue(data, 1)
		Income.accrue(data, 1)
		expect(data.credits).toBe(40)
		expect(data.creditRemainder).toBe(0)
	end)

	it("applies boost", function()
		local data = SaveData.new()
		Income.accrue(data, 1, 2)
		expect(earned(data)).toBeCloseTo(0.6)
	end)
end)
