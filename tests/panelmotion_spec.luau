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

	it("moves the view's centre a quarter of the way across the screen", function()
		-- At 90 degrees tall on a square screen, the edge of the view is 1 unit out per unit of depth.
		expect(near(PanelMotion.viewShift(90, 1), 0.5)).toBe(true)
		expect(near(PanelMotion.viewShift(90, 2), 1)).toBe(true)
	end)

	it("blurs the view only while it travels, up to a limit", function()
		expect(PanelMotion.viewBlur(0)).toBe(0)
		expect(PanelMotion.viewBlur(0.1) > 0).toBe(true)
		expect(PanelMotion.viewBlur(-0.1)).toBe(PanelMotion.viewBlur(0.1))
		expect(PanelMotion.viewBlur(0.2) > PanelMotion.viewBlur(0.1)).toBe(true)
		expect(PanelMotion.viewBlur(5)).toBe(PanelMotion.viewBlur(10))
	end)

	it("leans the view with the way it travels", function()
		expect(PanelMotion.viewLean(0)).toBe(0)
		expect(PanelMotion.viewLean(0.1) ~= 0).toBe(true)
		expect(near(PanelMotion.viewLean(-0.1), -PanelMotion.viewLean(0.1))).toBe(true)
	end)

	it("glows while it travels, up to full", function()
		expect(PanelMotion.glow(0)).toBe(0)
		expect(PanelMotion.glow(0.05) > 0).toBe(true)
		expect(PanelMotion.glow(-0.05)).toBe(PanelMotion.glow(0.05))
		expect(PanelMotion.glow(5)).toBe(1)
	end)

	it("leaves no smear when the panel stayed put", function()
		expect(#PanelMotion.smear(0, math.random)).toBe(0)
	end)

	it("keeps every smear row on the screen", function()
		for _ = 1, 50 do
			for _, row in PanelMotion.smear(0.27, math.random) do
				expect(row.top >= 0 and row.top + row.height <= 1).toBe(true)
				expect(row.length > 0 and row.length <= 1).toBe(true)
			end
		end
	end)

	it("smears further the faster the panel moves", function()
		local function middle()
			return 0.5
		end
		local slow = PanelMotion.smear(0.05, middle)
		local fast = PanelMotion.smear(-0.2, middle)
		expect(#fast > 0).toBe(true)
		expect(fast[1].length > slow[1].length).toBe(true)
	end)

	it("shakes hardest on landing, then fades to nothing", function()
		local first = PanelMotion.landShake(0)
		local second = PanelMotion.landShake(1 / PanelMotion.FPS)
		local late = PanelMotion.landShake(PanelMotion.SHAKE_TIME - 1 / PanelMotion.FPS)
		expect(first.x ~= 0).toBe(true)
		expect(first.x * second.x < 0).toBe(true)
		expect(math.abs(late.x) < math.abs(first.x)).toBe(true)
		expect(PanelMotion.landShake(PanelMotion.SHAKE_TIME).x).toBe(0)
		expect(PanelMotion.landShake(-0.1).x).toBe(0)
	end)
end)
