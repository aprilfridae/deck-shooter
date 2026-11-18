local harness = require("./harness")
local CardAim = require("../src/shared/CardCore/CardAim")

local describe, it, expect = harness.describe, harness.it, harness.expect

local function point(x: number, y: number, z: number)
	return { x = x, y = y, z = z }
end

local ORIGIN = point(0, 0, 0)
local AHEAD = point(0, 0, -1)

describe("CardAim", function()
	it("makes a unit direction from what a client sent", function()
		local made = CardAim.direction(0, 0, -5) :: any
		expect(made.z).toBe(-1)
		expect(CardAim.direction(0, 0, 0)).toBe(nil)
		expect(CardAim.direction(0 / 0, 0, 1)).toBe(nil)
		expect(CardAim.direction(math.huge, 0, 1)).toBe(nil)
		expect(CardAim.direction("1", 0, 1)).toBe(nil)
		expect(CardAim.direction(nil, 0, 1)).toBe(nil)
	end)

	it("hits a target on the line", function()
		expect(CardAim.pick(ORIGIN, AHEAD, 40, 3, { point(0, 0, -20) })).toBe(1)
	end)

	it("forgives a near miss and no more", function()
		expect(CardAim.pick(ORIGIN, AHEAD, 40, 3, { point(2.5, 0, -20) })).toBe(1)
		expect(CardAim.pick(ORIGIN, AHEAD, 40, 3, { point(3.5, 0, -20) })).toBe(nil)
	end)

	it("misses a target out of reach or behind", function()
		expect(CardAim.pick(ORIGIN, AHEAD, 40, 3, { point(0, 0, -41) })).toBe(nil)
		expect(CardAim.pick(ORIGIN, AHEAD, 40, 3, { point(0, 0, 10) })).toBe(nil)
	end)

	it("takes the nearest of two on the line", function()
		expect(CardAim.pick(ORIGIN, AHEAD, 40, 3, { point(0, 0, -30), point(1, 0, -10) })).toBe(2)
	end)

	it("finds nobody in an empty room", function()
		expect(CardAim.pick(ORIGIN, AHEAD, 40, 3, {})).toBe(nil)
	end)

	it("takes longer to throw a card further", function()
		expect(CardAim.flight(CardAim.THROW_SPEED)).toBe(1)
		expect(CardAim.flight(500) > CardAim.flight(250)).toBe(true)
	end)

	it("keeps a close throw in the air long enough to see", function()
		expect(CardAim.flight(0)).toBe(CardAim.THROW_LEAST)
		expect(CardAim.flight(10)).toBe(CardAim.THROW_LEAST)
	end)

	it("launches fast enough to reach the height", function()
		local speed = CardAim.launchSpeed(24, 196.2)
		expect(math.round(speed * speed / (2 * 196.2))).toBe(24)
	end)

	it("throws straight up from a blast underfoot", function()
		local way = CardAim.blastDirection(point(0, 0, 0), point(0, 3, 0))
		expect(way.y).toBe(1)
		expect(CardAim.blastDirection(point(1, 1, 1), point(1, 1, 1)).y).toBe(1)
	end)

	it("throws away from a blast to one side", function()
		local way = CardAim.blastDirection(point(-3, 0, 0), point(0, 3, 0))
		expect(way.x > 0).toBe(true)
		expect(way.y > 0).toBe(true)
	end)

	it("never throws downward", function()
		local way = CardAim.blastDirection(point(0, 5, 0), point(3, 0, 0))
		expect(way.y).toBe(0)
		expect(way.x).toBe(1)
	end)

	it("flicks Flashpoint slower than a throw, and never too fast to see", function()
		expect(CardAim.flashFlight(55, 110, 0.15)).toBe(0.5)
		expect(CardAim.flashFlight(3, 110, 0.15)).toBe(0.15)
	end)

	it("blinds fully near the burst and less toward the edge", function()
		expect(CardAim.flashReach(0, 34, 0.5, 0.35)).toBe(1)
		expect(CardAim.flashReach(17, 34, 0.5, 0.35)).toBe(1)
		expect(math.abs(CardAim.flashReach(34, 34, 0.5, 0.35) - 0.35) < 1e-9).toBe(true)
		expect(CardAim.flashReach(34.1, 34, 0.5, 0.35)).toBe(0)
		local last = 1
		for distance = 17, 34 do
			local reach = CardAim.flashReach(distance, 34, 0.5, 0.35)
			expect(reach <= last).toBe(true)
			last = reach
		end
	end)

	it("blinds whoever looks at the burst most and spares a turned back a little", function()
		expect(math.abs(CardAim.flashFacing(1) - 1) < 1e-9).toBe(true)
		expect(math.abs(CardAim.flashFacing(0.5) - 1) < 1e-9).toBe(true)
		expect(math.abs(CardAim.flashFacing(-1) - 0.33) < 1e-9).toBe(true)
		expect(CardAim.flashFacing(0) > CardAim.flashFacing(-0.5)).toBe(true)
	end)

	it("rewinds to the oldest point within the window", function()
		local path = {}
		for step = 0, 50 do
			table.insert(path, { at = step * 0.1 })
		end
		expect(CardAim.rewindPoint(path, 5, 3, 0.5)).toBe(21) -- at 2.0, three seconds before 5
		expect(CardAim.rewindPoint(path, 1, 3, 0.5)).toBe(1) -- not three seconds of path: as far back as there is
		expect(CardAim.rewindPoint({ { at = 4.8 } }, 5, 3, 0.5)).toBeNil() -- too little to go back along
		expect(CardAim.rewindPoint({}, 5, 3, 0.5)).toBeNil()
	end)
end)
