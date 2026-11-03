local harness = require("./harness")
local Tier = require("../src/shared/CardCore/Tier")

local describe, it, expect = harness.describe, harness.it, harness.expect

describe("Tier", function()
	it("orders tiers from Field to Prototype", function()
		expect(Tier.order).toEqual({ "Field", "BlackSite", "Prototype" })
		expect(Tier.index("Prototype")).toBe(3)
	end)

	it("steps to the next tier and stops at the top", function()
		expect(Tier.next("Field")).toBe("BlackSite")
		expect(Tier.next("BlackSite")).toBe("Prototype")
		expect(Tier.next("Prototype")).toBeNil()
	end)

	it("rejects anything that is not a tier", function()
		expect(Tier.isValid("Legendary")).toBe(false)
		expect(Tier.isValid(42)).toBe(false)
		expect(Tier.isValid("Field")).toBe(true)
	end)
end)
