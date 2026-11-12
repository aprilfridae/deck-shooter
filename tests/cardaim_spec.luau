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
end)
