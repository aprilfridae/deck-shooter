local harness = require("./harness")
local PanelMotion = require("../src/shared/Guns/Hud/PanelMotion")

local describe, it, expect = harness.describe, harness.it, harness.expect

local function near(a: number, b: number): boolean
	return math.abs(a - b) < 0.0001
end

describe("PanelMotion", function()
	it("steps through a move at 30 frames a second", function()
		expect(PanelMotion.FPS).toBe(30)
		expect(PanelMotion.held(0)).toBe(0)
		expect(PanelMotion.held(0.01)).toBe(0)
		expect(PanelMotion.held(PanelMotion.DURATION)).toBe(1)
		expect(PanelMotion.held(10)).toBe(1)
	end)

	it("starts and lands on its marks", function()
		expect(near(PanelMotion.share(0, 1, 0), 0)).toBe(true)
		expect(near(PanelMotion.share(0, 1, 1), 1)).toBe(true)
		expect(near(PanelMotion.share(1, 0, 0), 1)).toBe(true)
		expect(near(PanelMotion.share(1, 0, 1), 0)).toBe(true)
	end)

	it("swings past the mark on opening, then settles", function()
		expect(PanelMotion.share(0, 1, 0.75) > 1).toBe(true)
	end)

	it("gathers itself before closing", function()
		expect(PanelMotion.share(1, 0, 0.1) > 1).toBe(true)
		expect(PanelMotion.share(1, 0, 0.9) < 0.5).toBe(true)
	end)

	it("can reverse from part way", function()
		expect(near(PanelMotion.share(0.4, 0, 1), 0)).toBe(true)
		expect(near(PanelMotion.share(0.4, 1, 0), 0.4)).toBe(true)
	end)

	it("leaves fading copies between two frames", function()
		local trail = PanelMotion.trail(0, 0.5)
		expect(#trail).toBe(PanelMotion.COPIES)
		expect(trail[1].share > 0 and trail[1].share < 0.5).toBe(true)
		expect(trail[1].transparency < trail[#trail].transparency).toBe(true)
	end)

	it("leaves no copies when the panel stayed put", function()
		expect(#PanelMotion.trail(1, 1)).toBe(0)
	end)

	it("moves the camera far enough to put the character at a quarter of the screen", function()
		-- At 90 degrees tall on a square screen, half the width at distance 10 is 10 studs.
		expect(near(PanelMotion.cameraShift(10, 90, 1), 5)).toBe(true)
		expect(PanelMotion.cameraShift(0, 70, 1.78)).toBe(0)
	end)
end)
