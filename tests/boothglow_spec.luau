local harness = require("./harness")
local BoothGlow = require("../src/shared/Guns/BoothGlow")

local describe, it, expect = harness.describe, harness.it, harness.expect

describe("BoothGlow", function()
	it("starts and ends fully on", function()
		expect(BoothGlow.level(0)).toBe(1)
		expect(BoothGlow.level(BoothGlow.TOTAL)).toBe(1)
		expect(BoothGlow.level(BoothGlow.TOTAL + 5)).toBe(1)
	end)

	it("dips while it flickers but never goes fully dark", function()
		local lowest = 1
		for time = 0, BoothGlow.TOTAL, 0.01 do
			lowest = math.min(lowest, BoothGlow.level(time))
		end
		expect(lowest < 0.4).toBe(true)
		expect(lowest > 0).toBe(true)
	end)

	it("never jumps from one moment to the next", function()
		for time = 0, BoothGlow.TOTAL, 0.01 do
			local step = math.abs(BoothGlow.level(time + 0.01) - BoothGlow.level(time))
			expect(step < 0.05).toBe(true)
		end
	end)

	it("fades the glow out smoothly with distance", function()
		expect(BoothGlow.distanceFade(0)).toBe(1)
		expect(BoothGlow.distanceFade(BoothGlow.FADE_NEAR)).toBe(1)
		local middle = BoothGlow.distanceFade((BoothGlow.FADE_NEAR + BoothGlow.FADE_FAR) / 2)
		expect(middle > BoothGlow.FADE_FLOOR and middle < 1).toBe(true)
	end)

	it("keeps a stall lit from the far end of the hall", function()
		expect(BoothGlow.FADE_FLOOR > 0).toBe(true)
		expect(BoothGlow.FADE_FAR >= 75).toBe(true)
		expect(BoothGlow.distanceFade(BoothGlow.FADE_FAR)).toBe(BoothGlow.FADE_FLOOR)
		expect(BoothGlow.distanceFade(BoothGlow.FADE_FAR + 500)).toBe(BoothGlow.FADE_FLOOR)
	end)

	it("comes back on without dipping again", function()
		local last = BoothGlow.level(BoothGlow.FLICKER)
		for time = BoothGlow.FLICKER, BoothGlow.TOTAL, 0.05 do
			local level = BoothGlow.level(time)
			expect(level >= last).toBe(true)
			last = level
		end
	end)
end)
