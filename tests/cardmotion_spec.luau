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

	it("pulses outward and fades", function()
		local scale, clear = CardMotion.pulse(0)
		expect(near(scale, 1)).toBe(true)
		expect(near(clear, 0.3)).toBe(true)
		scale, clear = CardMotion.pulse(CardMotion.PULSE_TIME - 1e-9)
		expect(near(scale, 1.14)).toBe(true)
		expect(near(clear, 1)).toBe(true)
	end)

	it("pings outward and fades", function()
		local radius, clear = CardMotion.ping(0)
		expect(near(radius, 7)).toBe(true)
		expect(near(clear, 0.1)).toBe(true)
		radius, clear = CardMotion.ping(CardMotion.PING_TIME - 1e-9)
		expect(near(radius, 30)).toBe(true)
		expect(near(clear, 1)).toBe(true)
	end)

	it("scrambles the serial, then settles on it", function()
		expect(CardMotion.scramble("01", 2)).toBe("01")
		expect(CardMotion.scramble("01", CardMotion.SCRAMBLE_TIME + 2)).toBe("01")
		for time = 0, 0.8, 0.05 do
			expect(#CardMotion.scramble("01", time)).toBe(2)
		end
		expect(CardMotion.scramble("01", 0.05) ~= "01").toBe(true)
	end)
end)
