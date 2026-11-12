local harness = require("./harness")
local CardLook = require("../src/shared/CardCore/CardLook")
local Cards = require("../src/shared/CardCore/Cards")
local Variant = require("../src/shared/CardCore/Variant")

local describe, it, expect = harness.describe, harness.it, harness.expect

describe("CardLook", function()
	it("gives each card its own two letter monogram", function()
		expect(CardLook.monogram("phase_dash")).toBe("PD")
		expect(CardLook.monogram("aegis_shell")).toBe("AS")
		local seen = {}
		for _, id in Cards.ids do
			local monogram = CardLook.monogram(id)
			expect(#monogram).toBe(2)
			expect(seen[monogram]).toBe(nil)
			seen[monogram] = true
		end
	end)

	it("shows Black-Site as Redline", function()
		expect(CardLook.tierName("BlackSite")).toBe("REDLINE")
		expect(CardLook.tierName("Field")).toBe("FIELD")
		expect(CardLook.tierName("Prototype")).toBe("PROTOTYPE")
	end)

	it("names the tier and any variant", function()
		expect(CardLook.rarityText("Field", "Base")).toBe("FIELD")
		expect(CardLook.rarityText("BlackSite", Variant.ZeroDay)).toBe("REDLINE ZERO-DAY")
		expect(CardLook.rarityText("Prototype", Variant.Chromatic)).toBe("PROTOTYPE CHROMATIC")
	end)

	it("drops the set code when the rarity text would reach it", function()
		expect(CardLook.showsSetCode("Field", "Base")).toBe(true)
		expect(CardLook.showsSetCode("Field", Variant.ZeroDay)).toBe(true)
		expect(CardLook.showsSetCode("Prototype", Variant.ZeroDay)).toBe(false)
	end)

	it("picks a look: Zero-Day at any tier, otherwise the tier", function()
		expect(CardLook.look("BlackSite", "Base")).toBe("Redline")
		expect(CardLook.look("Field", Variant.ZeroDay)).toBe("ZeroDay")
		expect(CardLook.look("Field", Variant.Redacted)).toBe("Field")
	end)

	it("pads serials to two digits, and shows a gap with none", function()
		expect(CardLook.serialText(7)).toBe("07")
		expect(CardLook.serialText(1284)).toBe("1284")
		expect(CardLook.serialText(nil)).toBe("--")
	end)

	it("shrinks the big serial past two digits", function()
		expect(CardLook.bigSerialSize("01")).toBe(1)
		expect(CardLook.bigSerialSize("1284")).toBe(0.5)
	end)

	it("prints the name in capitals with no spaces", function()
		expect(CardLook.faceName("Phase Dash")).toBe("PHASEDASH")
		expect(CardLook.faceName("Overclock")).toBe("OVERCLOCK")
	end)

	it("prints the rarity in lowercase, tier then variant", function()
		expect(CardLook.faceRarity("Field", "Base")).toBe("field")
		expect(CardLook.faceRarity("BlackSite", "Base")).toBe("redline")
		expect(CardLook.faceRarity("Field", Variant.ZeroDay)).toBe("field zero-day")
		expect(#CardLook.faceRarity("Prototype", Variant.Chromatic)).toBe(19) -- the longest; CardLayout checks it fits
	end)

	it("pads a serial to four digits and shows longer ones in full", function()
		expect(CardLook.faceSerial(42)).toBe("0042")
		expect(CardLook.faceSerial(12345)).toBe("12345")
		expect(CardLook.faceSerial(nil)).toBe("----")
	end)

	it("gives serials 1 to 10 the low look and no others", function()
		for _, serial in { 1, 10 } do
			expect(CardLook.isLowSerial(serial)).toBe(true)
		end
		for _, serial in { 0, -3, 11, 1000 } do
			expect(CardLook.isLowSerial(serial)).toBe(false)
		end
		expect(CardLook.isLowSerial(nil)).toBe(false)
		expect(CardLook.lowSerialText(1)).toBe("01")
		expect(CardLook.lowSerialText(10)).toBe("10")
	end)

	it("has a stand-in serial for each card in Studio, one of them low", function()
		expect(CardLook.studioSerial("phase_dash")).toBe(1)
		expect(CardLook.studioSerial("overclock")).toBe(7)
		expect(CardLook.studioSerial("recon_pulse")).toBe(42)
		expect(CardLook.studioSerial("aegis_shell")).toBe(117)
		expect(CardLook.studioSerial("no_such_card")).toBe(nil)
	end)
end)
