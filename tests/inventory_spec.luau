local harness = require("./harness")
local Inventory = require("../src/shared/CardCore/Inventory")
local SaveData = require("../src/shared/CardCore/SaveData")

local describe, it, expect = harness.describe, harness.it, harness.expect

describe("SaveData.new", function()
	it("starts with no Credits or Catalysts", function()
		local data = SaveData.new()
		expect(data.version).toBe(1)
		expect(data.credits).toBe(0)
		expect(data.creditRemainder).toBe(0)
		expect(data.catalysts).toBe(0)
		expect(data.gunLevels).toEqual({ 0, 0 })
	end)

	it("starts with 3 equipped Field starter cards", function()
		local data = SaveData.new()
		expect(data.deck).toEqual({
			{ cardId = "phase_dash", tier = "Field" },
			{ cardId = "overclock", tier = "Field" },
			{ cardId = "recon_pulse", tier = "Field" },
		})
		expect(Inventory.count(data, "phase_dash", "Field")).toBe(1)
		expect(Inventory.count(data, "overclock", "Field", "Base")).toBe(1)
		expect(Inventory.count(data, "recon_pulse", "Field")).toBe(1)
	end)

	it("gives each player separate tables", function()
		local a, b = SaveData.new(), SaveData.new()
		a.deck[1].tier = "Prototype"
		a.stacks.x = 1
		a.gunLevels[1] = 9
		expect(b.deck[1].tier).toBe("Field")
		expect(b.stacks.x).toBeNil()
		expect(b.gunLevels[1]).toBe(0)
	end)
end)

describe("Inventory", function()
	it("round-trips a stack key", function()
		local key = Inventory.key("arc_mine", "BlackSite", "ZeroDay")
		expect(key).toBe("arc_mine:BlackSite:ZeroDay")
		local cardId, tier, variant = Inventory.parse(key)
		expect(cardId).toBe("arc_mine")
		expect(tier).toBe("BlackSite")
		expect(variant).toBe("ZeroDay")
	end)

	it("returns nil when parsing a malformed key", function()
		expect((Inventory.parse("arc_mine:Field"))).toBeNil()
		expect((Inventory.parse("a:b:c:d"))).toBeNil()
		expect((Inventory.parse(""))).toBeNil()
	end)

	it("never goes negative, and clears empty stacks", function()
		local data = SaveData.new()
		Inventory.add(data, "arc_mine", "Field", "Base", 2)
		expect(Inventory.remove(data, "arc_mine", "Field", "Base", 3)).toBe(false)
		expect(Inventory.count(data, "arc_mine", "Field", "Base")).toBe(2)
		expect(Inventory.remove(data, "arc_mine", "Field", "Base", 2)).toBe(true)
		expect(data.stacks["arc_mine:Field:Base"]).toBeNil()
	end)

	it("sums all variants when no variant is given", function()
		local data = SaveData.new()
		Inventory.add(data, "arc_mine", "Field", "Chromatic", 1)
		Inventory.add(data, "arc_mine", "Field", "Base", 2)
		Inventory.add(data, "arc_mine", "BlackSite", "Base", 7)
		expect(Inventory.count(data, "arc_mine", "Field")).toBe(3)
	end)

	it("knows whether a card is owned at any tier", function()
		local data = SaveData.new()
		expect(Inventory.ownsCard(data, "arc_mine")).toBe(false)
		Inventory.add(data, "arc_mine", "Prototype", "Redacted", 1)
		expect(Inventory.ownsCard(data, "arc_mine")).toBe(true)
	end)
end)
