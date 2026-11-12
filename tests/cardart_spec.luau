local harness = require("./harness")
local CardArt = require("../src/shared/CardCore/CardArt")
local Cards = require("../src/shared/CardCore/Cards")

local describe, it, expect = harness.describe, harness.it, harness.expect

local function isAsset(value: string?): boolean
	return string.sub(value or "", 1, 13) == "rbxassetid://"
end

describe("CardArt", function()
	it("has an acronym, a name and a flat image in every look for every card", function()
		for _, id in Cards.ids do
			expect(isAsset(CardArt.monogram(id))).toBe(true)
			expect(isAsset(CardArt.name(id))).toBe(true)
			for _, look in { "Field", "Redline", "Prototype", "ZeroDay" } do
				expect(isAsset(CardArt.base(id, look))).toBe(true)
			end
		end
	end)

	it("has every shared layer", function()
		for _, name in { "still", "rays", "star_big", "star_small", "barcode", "swirl", "grid", "crosshair", "measure" } do
			expect(isAsset(CardArt.layer(name))).toBe(true)
		end
		expect(pcall(CardArt.layer, "no_such_layer")).toBe(false)
	end)

	it("has a number and a glow for serials 1 to 10 only", function()
		for serial = 1, 10 do
			expect(isAsset(CardArt.lowSerial(serial))).toBe(true)
			expect(isAsset(CardArt.lowGlow(serial))).toBe(true)
		end
		for _, serial in { 0, 11 } do
			expect(CardArt.lowSerial(serial)).toBe(nil)
			expect(CardArt.lowGlow(serial)).toBe(nil)
		end
	end)

	it("gives nothing for a card with no art yet", function()
		expect(CardArt.base("no_such_card", "Field")).toBe(nil)
		expect(CardArt.monogram("no_such_card")).toBe(nil)
		expect(CardArt.name("no_such_card")).toBe(nil)
	end)
end)
