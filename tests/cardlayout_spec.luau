local harness = require("./harness")
local CardLayout = require("../src/shared/CardCore/CardLayout")

local describe, it, expect = harness.describe, harness.it, harness.expect

describe("CardLayout", function()
	it("keeps the longest rarity text clear of the serial", function()
		local serialLeft = CardLayout.SERIAL.right - 4 * 0.6 * CardLayout.SERIAL.size
		expect(CardLayout.rarityRight("prototype chromatic") < serialLeft).toBe(true)
	end)

	it("keeps every rect inside the card", function()
		for _, name in { "MONOGRAM", "RAYS", "STAR_BIG", "STAR_SMALL", "NAME", "BARCODE", "LOW_SERIAL", "LOW_GLOW", "CROSSHAIR", "MEASURE" } do
			local r = CardLayout[name]
			expect(r.x >= 0 and r.y >= 0 and r.x + r.w <= 1280 and r.y + r.h <= 2048).toBe(true)
		end
	end)

	it("ends the barcode on the bottom margin", function()
		expect(CardLayout.BARCODE.y + CardLayout.BARCODE.h).toBe(2048 - 45)
	end)

	it("halves particles on small cards and never returns less than one", function()
		expect(CardLayout.count(24, 400)).toBe(24)
		expect(CardLayout.count(24, 100)).toBe(12)
		expect(CardLayout.count(1, 20)).toBe(1)
	end)
end)
