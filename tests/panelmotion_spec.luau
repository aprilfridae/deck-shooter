local harness = require("./harness")
local PanelMotion = require("../src/shared/Guns/Hud/PanelMotion")

local describe, it, expect = harness.describe, harness.it, harness.expect

describe("PanelMotion", function()
	it("holds each position for a frame at 12 frames a second", function()
		expect(PanelMotion.held(0)).toBe(0)
		expect(PanelMotion.held(0.04)).toBe(0)
		expect(PanelMotion.held(1 / 12)).toBe(0.25)
		expect(PanelMotion.held(10)).toBe(1)
	end)

	it("leaves fading copies between two held frames", function()
		local trail = PanelMotion.trail(0, 0.5)
		expect(#trail).toBe(PanelMotion.COPIES)
		expect(trail[1].share > 0 and trail[1].share < 0.5).toBe(true)
		expect(trail[1].transparency < trail[#trail].transparency).toBe(true)
	end)

	it("leaves no copies when the panel stayed put", function()
		expect(#PanelMotion.trail(1, 1)).toBe(0)
	end)
end)
