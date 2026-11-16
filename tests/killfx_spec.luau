local harness = require("./harness")
local KillFx = require("../src/shared/Guns/KillFx")

local describe, it, expect = harness.describe, harness.it, harness.expect

describe("KillFx.scan", function()
	it("waits for the short", function()
		expect(KillFx.scan(0)).toBe(0)
		expect(KillFx.scan(KillFx.SHORT)).toBe(0)
	end)

	it("is halfway down the body halfway through", function()
		expect(KillFx.scan(KillFx.SHORT + KillFx.SCAN / 2)).toBeCloseTo(0.5)
	end)

	it("has passed the feet at the end and stays there", function()
		expect(KillFx.scan(KillFx.SHORT + KillFx.SCAN)).toBeCloseTo(1)
		expect(KillFx.scan(5)).toBeCloseTo(1)
	end)

	it("is done once the ring has faded", function()
		expect(KillFx.done(KillFx.SHORT + KillFx.SCAN)).toBe(false)
		expect(KillFx.done(KillFx.SHORT + KillFx.SCAN + KillFx.RING_FADE)).toBe(true)
	end)
end)

describe("KillFx flicker", function()
	it("steps through the short and stops when the scan starts", function()
		expect(KillFx.flickerStep(0)).toBe(0)
		expect(KillFx.flickerStep(KillFx.FLICKER * 2.5)).toBe(2)
		expect(KillFx.flickerStep(KillFx.SHORT)).toBe(nil)
		expect(KillFx.flickerStep(-0.1)).toBe(nil)
	end)

	it("shows the whole body on the first step", function()
		for index = 1, 20 do
			expect(KillFx.blinkedOut(0, index)).toBe(false)
		end
	end)

	it("blinks out some parts, not all, on later steps", function()
		local out = 0
		for step = 1, 5 do
			for index = 1, 20 do
				if KillFx.blinkedOut(step, index) then
					out += 1
				end
			end
		end
		expect(out > 5).toBe(true)
		expect(out < 70).toBe(true)
	end)

	it("gives the same answer every time", function()
		expect(KillFx.blinkedOut(3, 7)).toBe(KillFx.blinkedOut(3, 7))
	end)
end)

describe("KillFx.glow", function()
	it("flashes white and nearly solid", function()
		local transparency, cool = KillFx.glow(0)
		expect(transparency).toBeCloseTo(0.05)
		expect(cool).toBe(0)
	end)

	it("flickers to cyan on the next step", function()
		local _, cool = KillFx.glow(KillFx.FLICKER * 1.5)
		expect(cool).toBe(1)
	end)

	it("is gone once the scan has passed", function()
		local transparency = KillFx.glow(KillFx.SHORT + KillFx.SCAN)
		expect(transparency).toBeCloseTo(1)
	end)
end)

describe("KillFx.ring", function()
	it("is solid while it runs and gone after its fade", function()
		expect(KillFx.ring(KillFx.SHORT + 0.1)).toBe(0)
		expect(KillFx.ring(KillFx.SHORT + KillFx.SCAN + KillFx.RING_FADE / 2)).toBeCloseTo(0.5)
		expect(KillFx.ring(10)).toBe(1)
	end)
end)

describe("KillFx.shard", function()
	it("starts full size, white and solid", function()
		local size, cool, transparency = KillFx.shard(0)
		expect(size).toBe(1)
		expect(cool).toBe(0)
		expect(transparency).toBe(0)
	end)

	it("has cooled to cyan early and shrinks to nothing", function()
		local _, cool = KillFx.shard(KillFx.SHARD_COOL)
		expect(cool).toBeCloseTo(1)
		local size, _, transparency = KillFx.shard(1)
		expect(size).toBe(0)
		expect(transparency).toBe(1)
	end)
end)

describe("KillFx.punch", function()
	it("rises to its peak fast", function()
		expect(KillFx.punch(0)).toBe(0)
		expect(KillFx.punch(KillFx.PUNCH_ATTACK)).toBeCloseTo(1)
	end)

	it("falls away and ends", function()
		expect(KillFx.punch(0.1) < 0.5).toBe(true)
		expect(KillFx.punch(1)).toBe(0)
		expect(KillFx.punch(-1)).toBe(0)
	end)
end)

describe("KillFx streaks", function()
	it("grows the punch each kill up to a cap", function()
		expect(KillFx.streakScale(1)).toBeCloseTo(1)
		expect(KillFx.streakScale(2)).toBeCloseTo(1 + KillFx.STREAK_STEP)
		expect(KillFx.streakScale(KillFx.STREAK_TOP + 10)).toBeCloseTo(KillFx.streakScale(KillFx.STREAK_TOP))
	end)

	it("raises the kill sound a semitone a kill up to a cap", function()
		expect(KillFx.killPitch(1)).toBeCloseTo(1)
		expect(KillFx.killPitch(2)).toBeCloseTo(2 ^ (1 / 12))
		expect(KillFx.killPitch(50)).toBeCloseTo(2 ^ (KillFx.PITCH_TOP / 12))
	end)
end)

describe("KillFx.shardCounts", function()
	it("shares the budget by volume", function()
		local counts = KillFx.shardCounts({ 3, 1 }, 40)
		expect(counts[1]).toBe(30)
		expect(counts[2]).toBe(10)
	end)

	it("gives every part at least one", function()
		local counts = KillFx.shardCounts({ 100, 0.001 }, 10)
		expect(counts[2]).toBe(1)
	end)
end)
