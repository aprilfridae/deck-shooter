local harness = require("./harness")
local CardMotion = require("../src/shared/Guns/Hud/CardMotion")

local describe, it, expect = harness.describe, harness.it, harness.expect

local function near(a: number, b: number): boolean
	return math.abs(a - b) < 1e-6
end

describe("CardMotion", function()
	it("sweeps the shine across, holds it off the card, and repeats", function()
		local time = CardMotion.SHINE_TIME
		expect(near(CardMotion.shineOffset(0), -1)).toBe(true)
		expect(near(CardMotion.shineOffset(time * 0.55), 1)).toBe(true)
		expect(near(CardMotion.shineOffset(time * 0.9), 1)).toBe(true)
		expect(near(CardMotion.shineOffset(time), -1)).toBe(true)
		expect(math.abs(CardMotion.shineOffset(time * 0.275)) < 1e-6).toBe(true)
	end)

	it("pings outward and fades", function()
		local radius, clear = CardMotion.ping(0)
		expect(near(radius, 7)).toBe(true)
		expect(near(clear, 0.1)).toBe(true)
		radius, clear = CardMotion.ping(CardMotion.PING_TIME - 1e-9)
		expect(near(radius, 30)).toBe(true)
		expect(near(clear, 1)).toBe(true)
	end)

	it("breathes between full size and 78 percent", function()
		local scale, clear = CardMotion.breathe(0, 3, 0)
		expect(near(scale, 1)).toBe(true)
		expect(near(clear, 0)).toBe(true)
		scale, clear = CardMotion.breathe(1.5, 3, 0)
		expect(near(scale, 0.78)).toBe(true)
		expect(near(clear, 0.45)).toBe(true)
		expect(near((CardMotion.breathe(0, 3, 1.5)), 0.78)).toBe(true) -- half a cycle apart
	end)

	it("carries a dot once round its ring in one period, either way", function()
		local x, y = CardMotion.orbit(0, 6, 1)
		expect(near(x, -1)).toBe(true)
		expect(near(y, 0)).toBe(true)
		local x2, y2 = CardMotion.orbit(1.5, 6, 1)
		local x3, y3 = CardMotion.orbit(1.5, 6, -1)
		expect(near(x2, x3)).toBe(true)
		expect(near(y2, -y3)).toBe(true)
		x, y = CardMotion.orbit(6, 6, 1)
		expect(near(x, -1)).toBe(true)
		expect(near(y, 0)).toBe(true)
	end)

	it("sweeps the red band down, then holds it off the card", function()
		expect(near(CardMotion.sweepDown(0), -1)).toBe(true)
		expect(near(CardMotion.sweepDown(1), 0)).toBe(true)
		expect(near(CardMotion.sweepDown(2), 1)).toBe(true)
		expect(near(CardMotion.sweepDown(4.9), 1)).toBe(true)
	end)

	it("flickers the acronym twice in each repeat", function()
		expect(CardMotion.flicker(0)).toBe(0)
		expect(CardMotion.flicker(3.2 * 0.46)).toBe(0.3)
		expect(CardMotion.flicker(3.2 * 0.71)).toBe(0.15)
	end)

	it("raises embers from the bottom edge and keeps them on the card", function()
		local x, y, size, clear = CardMotion.ember(0, 0)
		expect(x).toBe(45)
		expect(near(y, 1780)).toBe(true)
		expect(size).toBe(8)
		expect(near(clear, 1)).toBe(true)
		local _, half = CardMotion.ember(0, 1.3)
		expect(near(half, 1330)).toBe(true)
		for index = 0, 23 do
			for _, time in { 0, 1, 2.5 } do
				local ex, ey = CardMotion.ember(index, time)
				expect(ex >= 45 and ex <= 1235 and ey >= 0 and ey <= 2048).toBe(true)
			end
		end
	end)

	it("blinks plus marks that stay on the card", function()
		local x, y, shown = CardMotion.mark(0, 0)
		expect(x).toBe(90)
		expect(y).toBe(120)
		expect(shown).toBe(true)
		local _, _, later = CardMotion.mark(0, 1.0)
		expect(later).toBe(false)
		for index = 0, 13 do
			local mx, my = CardMotion.mark(index, 0)
			expect(mx >= 0 and mx <= 1280 and my >= 0 and my <= 2048).toBe(true)
		end
	end)

	it("draws the measuring line, holds it, then fades it", function()
		local reveal, clear = CardMotion.measure(0)
		expect(near(reveal, 0)).toBe(true)
		expect(near(clear, 0)).toBe(true)
		reveal, clear = CardMotion.measure(1.75)
		expect(near(reveal, 1)).toBe(true)
		expect(near(clear, 0)).toBe(true)
		local _, gone = CardMotion.measure(4.75)
		expect(near(gone, 1)).toBe(true)
	end)

	it("slides the grid and the foil at a steady pace", function()
		expect(near(CardMotion.gridShift(2), 0.5)).toBe(true)
		expect(near(CardMotion.foilShift(3), 0.5)).toBe(true)
		expect(near(CardMotion.rainbowShift(1.3), 0.5)).toBe(true)
	end)

	it("twinkles from nothing to full size and back, never below nothing", function()
		local _, _, size = CardMotion.twinkle(0, 0)
		expect(near(size, 0)).toBe(true)
		_, _, size = CardMotion.twinkle(0, 1.1)
		expect(math.abs(size - 154 * 0.28) < 0.01).toBe(true)
		for time = 0, 10, 0.37 do
			for index = 0, 8 do
				local _, _, now = CardMotion.twinkle(index, time)
				expect(now >= 0).toBe(true)
			end
		end
	end)

	it("slides a loop of colours round without a seam", function()
		local points = CardMotion.loop(4, 0)
		expect(#points).toBe(5)
		for index, point in points do
			expect(near(point.time, (index - 1) / 4)).toBe(true)
			expect(point.from).toBe((index - 1) % 4 + 1)
			expect(near(point.mix, 0)).toBe(true)
		end
		points = CardMotion.loop(4, 0.125)
		expect(#points).toBe(6)
		expect(points[1].time).toBe(0)
		expect(points[1].from).toBe(1)
		expect(points[1].to).toBe(2)
		expect(near(points[1].mix, 0.5)).toBe(true)
		expect(near(points[2].time, 0.125)).toBe(true)
		expect(points[2].from).toBe(2)
		expect(points[6].time).toBe(1)
		expect(points[6].from).toBe(1)
		expect(near(points[6].mix, 0.5)).toBe(true)
		-- Times always climb, whatever the phase, or Roblox rejects the gradient.
		for phase = 0, 2, 0.013 do
			local last = -1
			for _, point in CardMotion.loop(6, phase) do
				expect(point.time > last).toBe(true)
				last = point.time
			end
			expect(last).toBe(1)
		end
	end)

	it("pulses the low serial's glow", function()
		expect(near(CardMotion.glow(0), 0.25)).toBe(true)
		expect(near(CardMotion.glow(0.8), 0)).toBe(true)
	end)
end)
