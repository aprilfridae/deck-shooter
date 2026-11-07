local harness = require("./harness")
local PanelMotion = require("../src/shared/Guns/Hud/PanelMotion")

local describe, it, expect = harness.describe, harness.it, harness.expect

local function near(a: number, b: number): boolean
	return math.abs(a - b) < 0.0001
end

describe("PanelMotion", function()
	it("shakes gently while a closing panel is still leaving", function()
		expect(PanelMotion.shakeStart() < PanelMotion.CLOSE_TIME / 2).toBe(true)
		expect(math.abs(PanelMotion.landShake(0).x) <= 0.006).toBe(true)
	end)

	it("closes quicker than it opens", function()
		expect(PanelMotion.moveTime(false) < PanelMotion.moveTime(true)).toBe(true)
		expect(PanelMotion.moveTime(true)).toBe(PanelMotion.DURATION)
	end)

	it("closes on the opening curve, quick and then released", function()
		expect(PanelMotion.sheet(0, 1, 0.3)).toBe(PanelMotion.share(0, 1, 0.3))
		expect(near(PanelMotion.sheet(1, 0, 0.3), 1 - PanelMotion.share(0, 1, 0.3))).toBe(true)
		expect(PanelMotion.sheet(1, 0, 0.1) < 1).toBe(true)
		expect(PanelMotion.sheet(1, 0, 0.3) < 0.5).toBe(true)
		expect(near(PanelMotion.sheet(1, 0, 1), 0)).toBe(true)
	end)

	it("eases the camera into a closing move", function()
		expect(PanelMotion.viewShare(1, 0, 0) >= 1).toBe(true)
		expect(1 - PanelMotion.viewShare(1, 0, 0.05) < (1 - PanelMotion.sheet(1, 0, 0.05)) / 5).toBe(true)
	end)

	it("opens a row smoothly and lands on 1", function()
		expect(PanelMotion.expand(0)).toBe(0)
		expect(PanelMotion.expand(0.001) > 0).toBe(true)
		expect(near(PanelMotion.expand(PanelMotion.EXPAND_TIME), 1)).toBe(true)
		expect(near(PanelMotion.expand(10), 1)).toBe(true)
	end)

	it("decodes at a low frame rate", function()
		expect(PanelMotion.DECODE_FPS < PanelMotion.FPS).toBe(true)
		local held = 0.5 / PanelMotion.DECODE_FPS
		expect(PanelMotion.decode("HELLO", held)).toBe("")
	end)

	it("starts a decode with nothing on screen", function()
		expect(PanelMotion.decode("HELLO", 0)).toBe("")
	end)

	it("runs noise out in front of the text", function()
		local shown = PanelMotion.decode("AAAAAAAAAAAAAAAAAAAA", 2 / PanelMotion.DECODE_FPS)
		expect(#shown > 0).toBe(true)
		expect(#shown < 20).toBe(true)
		expect(string.find(shown, "[^A]") ~= nil).toBe(true)
	end)

	it("settles on the exact text", function()
		local text = "FIRST TO 5.\nSECOND LINE"
		expect(PanelMotion.decode(text, 10)).toBe(text)
	end)

	it("keeps spaces and line breaks in place while decoding", function()
		local shown = PanelMotion.decode("AB CD\nEF GH", 2 / PanelMotion.DECODE_FPS)
		for index = 1, #shown do
			local letter = string.sub("AB CD\nEF GH", index, index)
			if letter == " " or letter == "\n" then
				expect(string.sub(shown, index, index)).toBe(letter)
			end
		end
	end)

	it("holds the same noise for a whole frame", function()
		local frame = 3 / PanelMotion.DECODE_FPS
		local text = string.rep("X", 30)
		expect(PanelMotion.decode(text, frame)).toBe(PanelMotion.decode(text, frame + 0.01))
	end)

	it("eases the camera in gently, then matches the panel", function()
		expect(PanelMotion.viewShare(0, 1, 0)).toBe(0)
		expect(near(PanelMotion.viewShare(0, 1, 1), 1)).toBe(true)
		expect(PanelMotion.viewShare(0, 1, 0.05) < PanelMotion.share(0, 1, 0.05) / 5).toBe(true)
		expect(PanelMotion.viewShare(0, 1, 0.5)).toBe(PanelMotion.share(0, 1, 0.5))
	end)

	it("drops the camera away with the panel when closing", function()
		expect(PanelMotion.viewShare(1, 0, 0.5)).toBe(PanelMotion.sheet(1, 0, 0.5))
	end)

	it("fades the blur out before a closing panel has left", function()
		expect(PanelMotion.closeFade(0)).toBe(1)
		expect(PanelMotion.closeFade(0.1)).toBe(1)
		expect(PanelMotion.closeFade(0.4)).toBe(0)
		expect(PanelMotion.closeFade(1)).toBe(0)
		local middle = PanelMotion.closeFade(0.3)
		expect(middle > 0 and middle < 1).toBe(true)
	end)

	it("smears further back than the last frame travelled", function()
		local trail = PanelMotion.trail(0.5, 1)
		expect(trail[#trail].share < 0.5).toBe(true)
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

	it("keeps the view's shift small enough for Roblox to accept", function()
		expect(PanelMotion.safeShift(0.5)).toBe(0.5)
		expect(PanelMotion.safeShift(-0.5)).toBe(-0.5)
		expect(PanelMotion.safeShift(5)).toBe(PanelMotion.MOST_SHIFT)
		expect(PanelMotion.safeShift(-5)).toBe(-PanelMotion.MOST_SHIFT)
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

	it("wobbles smoothly from nothing back to nothing", function()
		expect(near(PanelMotion.landShake(0).x, 0)).toBe(true)
		expect(PanelMotion.landShake(PanelMotion.SHAKE_TIME).x).toBe(0)
		expect(PanelMotion.landShake(-0.1).x).toBe(0)
		local step = 1 / 120
		local lowest, highest = 0, 0
		for time = 0, PanelMotion.SHAKE_TIME, step do
			local x = PanelMotion.landShake(time).x
			expect(math.abs(PanelMotion.landShake(time + step).x - x) < 0.0015).toBe(true)
			lowest = math.min(lowest, x)
			highest = math.max(highest, x)
		end
		expect(lowest < 0 and highest > 0).toBe(true)
	end)
end)
