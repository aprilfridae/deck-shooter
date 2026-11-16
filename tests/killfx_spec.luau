local harness = require("./harness")
local KillFx = require("../src/shared/Guns/KillFx")

local describe, it, expect = harness.describe, harness.it, harness.expect

describe("KillFx.goneAt", function()
	it("takes the top first and the bottom last", function()
		expect(KillFx.goneAt(1, 0)).toBeCloseTo(KillFx.FIRST_GONE)
		expect(KillFx.goneAt(0, 1)).toBeCloseTo(KillFx.DISSOLVE)
	end)

	it("lets chance move a part, but not past the ends", function()
		expect(KillFx.goneAt(0.5, 0) < KillFx.goneAt(0.5, 1)).toBe(true)
		expect(KillFx.goneAt(-3, 9) <= KillFx.DISSOLVE).toBe(true)
		expect(KillFx.goneAt(5, -2) >= KillFx.FIRST_GONE).toBe(true)
	end)

	it("takes a headshot's head before any other part", function()
		expect(KillFx.HEAD_GONE < KillFx.FIRST_GONE).toBe(true)
	end)
end)

describe("KillFx.blinkedOut", function()
	it("shows a part until its warning starts and hides it once it's gone", function()
		for step = 0, 10 do
			expect(KillFx.blinkedOut(step, 3, KillFx.WARN + 0.01)).toBe(false)
			expect(KillFx.blinkedOut(step, 3, 0)).toBe(true)
		end
	end)

	it("doesn't blink while it collapses", function()
		for step = 0, 50 do
			expect(KillFx.blinkedOut(step, 3, KillFx.COLLAPSE / 2)).toBe(false)
		end
	end)

	it("blinks more often as it nears going", function()
		local early, late = 0, 0
		for step = 1, 200 do
			if KillFx.blinkedOut(step, 5, KillFx.WARN * 0.95) then
				early += 1
			end
			if KillFx.blinkedOut(step, 5, KillFx.COLLAPSE + 0.005) then
				late += 1
			end
		end
		expect(late > early).toBe(true)
		expect(late > 60).toBe(true)
		expect(late < 200).toBe(true)
	end)

	it("gives the same answer every time", function()
		expect(KillFx.blinkedOut(3, 7, 0.1)).toBe(KillFx.blinkedOut(3, 7, 0.1))
	end)
end)

describe("KillFx.jitter", function()
	it("leaves a part still outside its warning", function()
		expect(KillFx.jitter(4, 2, KillFx.WARN + 1)).toBe(0)
		expect(KillFx.jitter(4, 2, 0)).toBe(0)
	end)

	it("twitches some parts a little through it", function()
		local moved = 0
		for step = 1, 100 do
			local shift = KillFx.jitter(step, 2, KillFx.WARN / 2)
			expect(math.abs(shift) <= 0.3).toBe(true)
			if shift ~= 0 then
				moved += 1
			end
		end
		expect(moved > 5).toBe(true)
		expect(moved < 60).toBe(true)
	end)
end)

describe("KillFx.tear", function()
	it("never tears through the white flash or after the end", function()
		for step = 0, 50 do
			expect(KillFx.tear(step, KillFx.SHORT / 2)).toBe(nil)
			expect(KillFx.tear(step, KillFx.DISSOLVE)).toBe(nil)
		end
	end)

	it("tears on some steps, within the body and the most shift", function()
		local tears = 0
		for step = 0, 200 do
			local height, shift = KillFx.tear(step, 0.5)
			if height then
				tears += 1
				expect(height >= 0.2 and height <= 0.9).toBe(true)
				expect(math.abs(shift :: number) <= KillFx.TEAR_MOST).toBe(true)
			end
		end
		expect(tears > 30).toBe(true)
		expect(tears < 120).toBe(true)
	end)
end)

describe("KillFx.glow", function()
	it("flashes white and nearly solid", function()
		local transparency, cool = KillFx.glow(0)
		expect(transparency).toBeCloseTo(0.05)
		expect(cool).toBe(0)
	end)

	it("is cyan on most steps after the flash, white on every third", function()
		local whites = 0
		for step = 4, 15 do
			local _, cool = KillFx.glow((step + 0.5) * KillFx.FLICKER)
			if cool == 0 then
				whites += 1
			end
		end
		expect(whites).toBe(4)
	end)

	it("is clear once the body has gone", function()
		expect(KillFx.glow(KillFx.DISSOLVE + 0.01 + KillFx.FLICKER)).toBeCloseTo(1)
		expect(KillFx.done(KillFx.DISSOLVE)).toBe(true)
		expect(KillFx.done(KillFx.DISSOLVE - 0.01)).toBe(false)
	end)
end)

describe("KillFx.released", function()
	it("lets none go before the warning, a trickle through it and the rest when the part goes", function()
		expect(KillFx.released(20, KillFx.WARN + 1)).toBe(0)
		expect(KillFx.released(20, KillFx.WARN / 2)).toBe(math.floor(20 * KillFx.TRICKLE * 0.5))
		expect(KillFx.released(20, 0)).toBe(20)
	end)
end)

describe("KillFx.squash", function()
	it("leaves a part as it is until its last moment", function()
		local wide, high = KillFx.squash(KillFx.COLLAPSE)
		expect(wide).toBeCloseTo(1)
		expect(high).toBeCloseTo(1)
	end)

	it("ends flat and wide", function()
		local wide, high = KillFx.squash(0)
		expect(wide).toBeCloseTo(1.5)
		expect(high).toBeCloseTo(0.08)
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

describe("KillFx.pixelCounts", function()
	it("shares the budget by volume", function()
		local counts = KillFx.pixelCounts({ 3, 1 }, 40)
		expect(counts[1]).toBe(30)
		expect(counts[2]).toBe(10)
	end)

	it("gives every part at least one", function()
		local counts = KillFx.pixelCounts({ 100, 0.001 }, 10)
		expect(counts[2]).toBe(1)
	end)
end)
