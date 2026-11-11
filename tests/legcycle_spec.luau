local harness = require("./harness")
local describe, it, expect = harness.describe, harness.it, harness.expect

local LegCycle = require("../src/shared/Movement/LegCycle")

-- Where the ankle ends up for these angles, worked forward from the hip.
local function ankle(pitch: number, bend: number): (number, number)
	local ahead = LegCycle.thigh * math.sin(pitch) + LegCycle.shin * math.sin(pitch - bend)
	local down = LegCycle.thigh * math.cos(pitch) + LegCycle.shin * math.cos(pitch - bend)
	return ahead, down
end

describe("LegCycle.shape", function()
	it("takes longer strides with less time on the ground as speed rises", function()
		local slow, fast = LegCycle.shape(6), LegCycle.shape(18.5)
		expect(fast.length > slow.length).toBe(true)
		expect(fast.stance < slow.stance).toBe(true)
		expect(fast.lift > slow.lift).toBe(true)
	end)

	it("covers exactly the ground the planted foot travels", function()
		for _, speed in { 3, 6, 15, 18.5, 21.3 } do
			local shape = LegCycle.shape(speed)
			expect(shape.length * shape.stance).toBeCloseTo(2 * shape.half)
		end
	end)
end)

describe("LegCycle.foot", function()
	local shape = LegCycle.shape(18.5)

	it("keeps a planted foot on the ground, moving back as fast as the body moves on", function()
		local first, firstLift = LegCycle.foot(0, shape)
		local later, laterLift = LegCycle.foot(shape.stance * 0.5, shape)
		expect(firstLift).toBe(0)
		expect(laterLift).toBe(0)
		expect(first).toBeCloseTo(shape.half)
		-- Half the stance is this much of the stride's ground.
		expect(first - later).toBeCloseTo(shape.length * shape.stance * 0.5)
	end)

	it("lifts the foot and brings it forward while it swings", function()
		local middle = shape.stance + (1 - shape.stance) * 0.5
		local _, lift = LegCycle.foot(middle, shape)
		expect(lift > shape.lift * 0.8).toBe(true)
		local ahead = LegCycle.foot(0.999, shape)
		expect(ahead).toBeCloseTo(shape.half, 0.05)
	end)

	it("wraps round", function()
		local a, b = LegCycle.foot(0.2, shape), LegCycle.foot(1.2, shape)
		expect(a).toBeCloseTo(b)
	end)
end)

describe("LegCycle.solve", function()
	it("puts the ankle where it was asked", function()
		for _, target in { { 0, 3 }, { 1.2, 2.8 }, { -1.3, 2.9 }, { 0.4, 1.9 } } do
			local pitch, bend = LegCycle.solve(target[1], 0, target[2])
			local ahead, down = ankle(pitch, bend)
			expect(ahead).toBeCloseTo(target[1], 0.001)
			expect(down).toBeCloseTo(target[2], 0.001)
			expect(bend >= 0).toBe(true)
		end
	end)

	it("reaches as far as it can toward a spot that's too far", function()
		local pitch, bend = LegCycle.solve(3, 0, 3)
		local ahead, down = ankle(pitch, bend)
		expect(ahead / down).toBeCloseTo(1, 0.01)
		expect(bend >= 0).toBe(true)
	end)

	it("swings the leg out to the side for a sideways step", function()
		local _, _, roll = LegCycle.solve(0, 1, 3)
		expect(roll > 0).toBe(true)
		local _, _, other = LegCycle.solve(0, -1, 3)
		expect(other).toBeCloseTo(-roll)
	end)
end)

describe("LegCycle.leg", function()
	it("steps backward when the body is going backward", function()
		local shape = LegCycle.shape(15)
		local ahead = LegCycle.leg(0, shape, 1, 0, 2.9, 1)
		local behind = LegCycle.leg(0, shape, -1, 0, 2.9, 1)
		local aheadAt = ankle(ahead.pitch, ahead.bend)
		local behindAt = ankle(behind.pitch, behind.bend)
		expect(aheadAt > 0).toBe(true)
		expect(behindAt).toBeCloseTo(-aheadAt, 0.01)
	end)

	it("keeps each leg on its own side, even stepping sideways", function()
		local shape = LegCycle.shape(15)
		for phase = 0, 0.95, 0.05 do
			-- Going right: the right leg never rolls in past its hip by much, nor the left.
			expect(LegCycle.leg(phase, shape, 0, 1, 2.9, 1).roll > -0.06).toBe(true)
			expect(LegCycle.leg(phase, shape, 0, 1, 2.9, -1).roll < 0.06).toBe(true)
			-- Running straight, both legs sit a little outside their hips.
			expect(LegCycle.leg(phase, shape, 1, 0, 2.9, 1).roll > 0).toBe(true)
			expect(LegCycle.leg(phase, shape, 1, 0, 2.9, -1).roll < 0).toBe(true)
		end
	end)

	it("keeps the hips' bob lowest over a planted foot", function()
		local shape = LegCycle.shape(18.5)
		expect(LegCycle.bob(shape.stance / 2, shape)).toBeCloseTo(-shape.bob)
		expect(LegCycle.bob(0.5 + shape.stance / 2, shape)).toBeCloseTo(-shape.bob)
	end)
end)
