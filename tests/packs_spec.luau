local harness = require("./harness")
local Cards = require("../src/shared/CardCore/Cards")
local Config = require("../src/shared/CardCore/Config")
local Packs = require("../src/shared/CardCore/Packs")
local SaveData = require("../src/shared/CardCore/SaveData")

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

local function owned(data: any): number
	local sum = 0
	for _, count in data.stacks do
		sum += count
	end
	return sum
end

describe("The pile", function()
	it("waits 3 seconds between rolls", function()
		expect(Packs.canRoll(nil, 0)).toBe(true)
		expect(Packs.canRoll(10, 12.99)).toBe(false)
		expect(Packs.canRoll(10, 13)).toBe(true)
	end)

	it("adds a rolled pack to the pile", function()
		local data = SaveData.new()
		local ok, pack = Packs.roll(data, at(0.99))
		expect(ok).toBe(true)
		expect(pack).toBe("Field")
		expect(data.packs.Field).toBe(1)
	end)

	it("uses the player's luck for a roll", function()
		local data = SaveData.new()
		data.rebirths = 5
		local _, pack = Packs.roll(data, at(0.3)) -- the rare total is 0.35 at luck 1.75
		expect(pack ~= "Field").toBe(true)
	end)

	it("stops rolling a rarity at the limit", function()
		local data = SaveData.new()
		data.packs.Field = Config.MaxStackCount
		local ok, code = Packs.roll(data, at(0.99))
		expect(ok).toBe(false)
		expect(code).toBe("PileFull")
		expect(data.packs.Field).toBe(Config.MaxStackCount)
	end)

	it("opens a pack into 3 cards and spends it", function()
		local data = SaveData.new()
		data.packs.BlackSite = 1
		local before = owned(data)
		local ok, cards = Packs.open(data, "BlackSite", math.random)
		expect(ok).toBe(true)
		expect(#cards).toBe(3)
		expect(data.packs.BlackSite).toBe(0)
		expect(owned(data)).toBe(before + 3)
	end)

	it("refuses a pack the player doesn't have", function()
		local ok, code = Packs.open(SaveData.new(), "ZeroDay", math.random)
		expect(ok).toBe(false)
		expect(code).toBe("NoPacks")
	end)

	it("opens the commonest first", function()
		local data = SaveData.new()
		data.packs.Prototype = 1
		data.packs.BlackSite = 1
		expect(Packs.nextToOpen(data)).toBe("BlackSite")
		expect(Packs.nextToOpen(SaveData.new())).toBe(nil)
	end)

	it("opens a whole pile into counts", function()
		local data = SaveData.new()
		data.packs.Field = 1000
		data.packs.ZeroDay = 2
		local before = owned(data)
		local result = Packs.openAll(data, math.random)
		expect(result.opened).toBe(1002)
		expect(Packs.pile(data)).toBe(0)
		local sum = 0
		for _, count in result.cards do
			sum += count
		end
		expect(sum).toBe(3006)
		expect(owned(data)).toBe(before + 3006)
	end)

	it("gives a Zero-Day pack its Zero-Day card in a whole pile too", function()
		local data = SaveData.new()
		data.packs.ZeroDay = 50
		local zeroDays = 0
		for key, count in Packs.openAll(data, math.random).cards do
			if string.find(key, "ZeroDay", 1, true) then
				zeroDays += count
			end
		end
		expect(zeroDays >= 50).toBe(true)
	end)

	it("keeps a million-pack result small", function()
		local data = SaveData.new()
		data.packs.Field = Config.MaxStackCount
		local keys = 0
		for _ in Packs.openAll(data, math.random).cards do
			keys += 1
		end
		expect(keys <= 72).toBe(true) -- 6 cards, 3 tiers, 4 variants
	end)
end)

describe("Receipts", function()
	it("never opens twice for the same receipt", function()
		local data = SaveData.new()
		data.packs.Field = 5
		expect((Packs.redeem(data, "a", math.random))).toBe("Opened")
		data.packs.Field = 5
		expect((Packs.redeem(data, "a", math.random))).toBe("Repeat")
		expect(data.packs.Field).toBe(5)
	end)

	it("banks a purchase made with an empty pile", function()
		local data = SaveData.new()
		expect((Packs.redeem(data, "a", math.random))).toBe("Banked")
		expect(data.openAllCredits).toBe(1)
		expect((Packs.redeem(data, "a", math.random))).toBe("Repeat")
		expect(data.openAllCredits).toBe(1)
	end)

	it("spends a banked purchase on a pile", function()
		local data = SaveData.new()
		expect(select(2, Packs.useCredit(data, math.random))).toBe("NoCredit")
		data.openAllCredits = 1
		expect(select(2, Packs.useCredit(data, math.random))).toBe("NoPacks")
		expect(data.openAllCredits).toBe(1)
		data.packs.Field = 2
		expect((Packs.useCredit(data, math.random))).toBe(true)
		expect(data.openAllCredits).toBe(0)
		expect(data.packs.Field).toBe(0)
	end)

	it("remembers only the newest receipts", function()
		local data = SaveData.new()
		for index = 1, Config.ReceiptMemory + 5 do
			Packs.redeem(data, `r{index}`, math.random)
		end
		expect(#data.receipts).toBe(Config.ReceiptMemory)
		expect(data.receipts[#data.receipts]).toBe(`r{Config.ReceiptMemory + 5}`)
	end)
end)
