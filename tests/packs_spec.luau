local harness = require("./harness")
local Cards = require("../src/shared/CardCore/Cards")
local Packs = require("../src/shared/CardCore/Packs")

local describe, it, expect = harness.describe, harness.it, harness.expect

local function total(outcomes: { any }): number
	local sum = 0
	for _, entry in outcomes do
		expect(entry.chance >= 0).toBe(true)
		sum += entry.chance
	end
	return sum
end

local function chance(outcomes: { any }, name: string): number
	for _, entry in outcomes do
		if entry.name == name then
			return entry.chance
		end
	end
	return 0
end

local function near(a: number, b: number)
	expect(math.abs(a - b) < 1e-9).toBe(true)
end

local function at(value: number): () -> number
	return function()
		return value
	end
end

describe("Pack odds", function()
	it("rolls packs at the spec's odds", function()
		local odds = Packs.packOdds(1)
		near(chance(odds, "Field"), 0.8)
		near(chance(odds, "BlackSite"), 0.16)
		near(chance(odds, "Prototype"), 0.0398)
		near(chance(odds, "ZeroDay"), 0.0002)
	end)

	it("gives luck 1.75 at 5 rebirths and a Zero-Day pack at 1 in 2857", function()
		near(Packs.luck(5), 1.75)
		near(chance(Packs.packOdds(1.75), "ZeroDay"), 0.00035)
	end)

	it("raises rare outcomes and takes it from the commonest", function()
		local odds = Packs.tierOdds("ZeroDay", 1, 1.75)
		near(chance(odds, "BlackSite"), 0.525)
		near(chance(odds, "Prototype"), 0.175)
		near(chance(odds, "Field"), 0.3)
	end)

	it("keeps every table at 100 percent at absurd luck", function()
		for _, luck in { 1, 1.75, 5, 50, 15001 } do
			near(total(Packs.packOdds(luck)), 1)
			for _, pack in Packs.ids do
				for slot = 1, 3 do
					near(total(Packs.tierOdds(pack, slot, luck)), 1)
					near(total(Packs.variantOdds(pack, slot, luck)), 1)
				end
			end
		end
		expect(chance(Packs.packOdds(50), "Field")).toBe(0)
	end)

	it("leaves guaranteed outcomes alone", function()
		near(chance(Packs.tierOdds("Prototype", 1, 9), "Prototype"), 1)
		near(chance(Packs.variantOdds("ZeroDay", 1, 9), "ZeroDay"), 1)
	end)

	it("has no chance of a tier the pack can't give", function()
		expect(chance(Packs.tierOdds("BlackSite", 1, 9), "Field")).toBe(0)
		expect(chance(Packs.tierOdds("ZeroDay", 2, 9), "Field")).toBe(0)
	end)

	it("gives Prototype packs a 5 percent Zero-Day and everything else 1 in 5000", function()
		near(chance(Packs.variantOdds("Prototype", 1, 1), "ZeroDay"), 0.05)
		near(chance(Packs.variantOdds("Field", 1, 1), "ZeroDay"), 0.0002)
		near(chance(Packs.variantOdds("ZeroDay", 2, 1), "ZeroDay"), 0.0002)
		near(chance(Packs.variantOdds("Field", 1, 1), "Chromatic"), 0.02)
		near(chance(Packs.variantOdds("Field", 1, 1), "Redacted"), 0.002)
	end)

	it("picks the commonest if rounding leaves the roll past the end", function()
		local outcomes = { { name = "A", chance = 0.5 }, { name = "B", chance = 0.4999 } }
		expect(Packs.pick(outcomes, at(0.99999))).toBe("A")
	end)

	it("gives the rare outcomes to low rolls", function()
		expect(Packs.rollPack(1, at(0.00001))).toBe("ZeroDay")
		expect(Packs.rollPack(1, at(0.99))).toBe("Field")
	end)

	it("always gives a Zero-Day pack's first card as Zero-Day", function()
		expect(Packs.rollCard("ZeroDay", 1, 1, at(0.5)).variant).toBe("ZeroDay")
	end)

	it("picks evenly from every card", function()
		local seen = {}
		local value = 0
		for _ = 1, 100 do
			value = (value + 0.137) % 1
			seen[Packs.rollCard("Field", 1, 1, at(value)).cardId] = true
		end
		for _, id in Cards.ids do
			expect(seen[id]).toBe(true)
		end
	end)

	it("calls Prototype and variants rare", function()
		expect(Packs.isRare({ tier = "Field", variant = "Base" })).toBe(false)
		expect(Packs.isRare({ tier = "BlackSite", variant = "Base" })).toBe(false)
		expect(Packs.isRare({ tier = "Prototype", variant = "Base" })).toBe(true)
		expect(Packs.isRare({ tier = "Field", variant = "Chromatic" })).toBe(true)
	end)
end)
