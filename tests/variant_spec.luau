local harness = require("./harness")
local Variant = require("../src/shared/CardCore/Variant")

local describe, it, expect = harness.describe, harness.it, harness.expect

local function at(x: number)
	return function()
		return x
	end
end

describe("Variant", function()
	it("rolls exact odds at each boundary", function()
		expect(Variant.roll(at(0))).toBe("ZeroDay")
		expect(Variant.roll(at(0.00019))).toBe("ZeroDay")
		expect(Variant.roll(at(0.0002))).toBe("Redacted")
		expect(Variant.roll(at(0.0021))).toBe("Redacted")
		expect(Variant.roll(at(0.0022))).toBe("Chromatic")
		expect(Variant.roll(at(0.0221))).toBe("Chromatic")
		expect(Variant.roll(at(0.0222))).toBe("Base")
		expect(Variant.roll(at(0.999))).toBe("Base")
	end)

	it("lists variants from common to rare", function()
		expect(Variant.order).toEqual({ "Base", "Chromatic", "Redacted", "ZeroDay" })
	end)

	it("rejects unknown variants", function()
		expect(Variant.isValid("Chromatic")).toBe(true)
		expect(Variant.isValid("Shiny")).toBe(false)
		expect(Variant.isValid(1)).toBe(false)
	end)
end)
