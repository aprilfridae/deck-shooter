local harness = require("./harness")
local PullMotion = require("../src/shared/CardCore/PullMotion")

local describe, it, expect = harness.describe, harness.it, harness.expect

describe("PullMotion", function()
	it("builds longer for rarer cards", function()
		local field = PullMotion.buildTime({ tier = "Field", variant = "Base" })
		local redline = PullMotion.buildTime({ tier = "BlackSite", variant = "Base" })
		local proto = PullMotion.buildTime({ tier = "Prototype", variant = "Base" })
		local zero = PullMotion.buildTime({ tier = "Field", variant = "ZeroDay" })
		expect(field < redline).toBe(true)
		expect(redline < proto).toBe(true)
		expect(proto < zero).toBe(true)
	end)

	it("adds to the build for a rare variant", function()
		local plain = PullMotion.buildTime({ tier = "BlackSite", variant = "Base" })
		expect(PullMotion.buildTime({ tier = "BlackSite", variant = "Redacted" }) > plain).toBe(true)
	end)

	it("fans the middle card straight and the others out evenly", function()
		local leftX, leftTilt = PullMotion.fan(1)
		local midX, midTilt = PullMotion.fan(2)
		local rightX, rightTilt = PullMotion.fan(3)
		expect(midX).toBe(0)
		expect(midTilt).toBe(0)
		expect(leftX).toBe(-rightX)
		expect(leftTilt).toBe(-rightTilt)
	end)

	it("lists the rarest first", function()
		local list = PullMotion.quickList({
			["overclock:Field:Base"] = 40,
			["overclock:Field:ZeroDay"] = 1,
			["overclock:Prototype:Base"] = 2,
		})
		expect(list[1].variant).toBe("ZeroDay")
		expect(list[2].tier).toBe("Prototype")
		expect(list[3].count).toBe(40)
		expect(list[3].cardId).toBe("overclock")
	end)
end)
