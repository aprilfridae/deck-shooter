local harness = require("./harness")
local PullMotion = require("../src/shared/CardCore/PullMotion")

local describe, it, expect = harness.describe, harness.it, harness.expect

describe("PullMotion", function()
	it("fans the middle card straight and the others out evenly", function()
		local leftX, leftTilt = PullMotion.fan(1)
		local midX, midTilt = PullMotion.fan(2)
		local rightX, rightTilt = PullMotion.fan(3)
		expect(midX).toBe(0)
		expect(midTilt).toBe(0)
		expect(leftX).toBe(-rightX)
		expect(leftTilt).toBe(-rightTilt)
	end)

	it("runs the opening's steps in order", function()
		local times = PullMotion.phases()
		expect(times.rip > 0).toBe(true)
		expect(times.slide > times.rip).toBe(true)
		expect(times.spread > times.slide).toBe(true)
		expect(times.build > times.spread).toBe(true)
		expect(times.flip > times.build).toBe(true)
		expect(times.rest > times.flip).toBe(true)
	end)

	it("shakes every pack the same before flipping", function()
		local times = PullMotion.phases()
		expect(times.flip - times.build).toBeCloseTo(0.9)
		expect(times.rest).toBeCloseTo(3.35)
	end)

	it("peels the strip from one end to the other", function()
		expect(PullMotion.peel(0, 1, 6)).toBe(0)
		expect(PullMotion.peel(0.2, 1, 6) > 0).toBe(true)
		expect(PullMotion.peel(0.2, 6, 6)).toBe(0)
		expect(PullMotion.peel(1, 1, 6)).toBe(1)
		expect(PullMotion.peel(1, 6, 6)).toBe(1)
	end)

	it("puts the best card in the middle", function()
		local order = PullMotion.fanOrder({
			{ tier = "Prototype", variant = "Base" },
			{ tier = "BlackSite", variant = "Base" },
			{ tier = "Field", variant = "Base" },
		})
		expect(#order).toBe(3)
		expect(order[2].tier).toBe("Prototype")
	end)

	it("keeps every card when it reorders them", function()
		local plain = { tier = "Field", variant = "Base" }
		local order = PullMotion.fanOrder({ plain, plain })
		expect(#order).toBe(2)
		expect(order[1]).toBe(plain)
	end)

	it("flashes harder for rarer cards and not at all for a plain Field", function()
		local field = PullMotion.flash({ tier = "Field", variant = "Base" })
		local redline = PullMotion.flash({ tier = "BlackSite", variant = "Base" })
		local chromatic = PullMotion.flash({ tier = "BlackSite", variant = "Chromatic" })
		local zero = PullMotion.flash({ tier = "Field", variant = "ZeroDay" })
		expect(field).toBe(0)
		expect(redline > 0).toBe(true)
		expect(chromatic > redline).toBe(true)
		expect(zero > chromatic).toBe(true)
	end)

	it("keeps only a few Auto Open pulls waiting", function()
		local chromatic = { tier = "Field", variant = "Chromatic" }
		expect(PullMotion.keepsRare(0, chromatic)).toBe(true)
		expect(PullMotion.keepsRare(PullMotion.RARE_QUEUE - 1, chromatic)).toBe(true)
		expect(PullMotion.keepsRare(PullMotion.RARE_QUEUE, chromatic)).toBe(false)
	end)

	it("never drops a Zero-Day", function()
		expect(PullMotion.keepsRare(100, { tier = "Field", variant = "ZeroDay" })).toBe(true)
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
