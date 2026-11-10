local harness = require("./harness")
local SpawnPick = require("../src/shared/Guns/SpawnPick")

local describe, it, expect = harness.describe, harness.it, harness.expect

local function p(x: number, y: number, z: number)
	return { X = x, Y = y, Z = z }
end

local function first(_: number): number
	return 1
end

describe("SpawnPick", function()
	local spawns = { p(0, 0, 0), p(100, 0, 0), p(50, 0, 80) }

	it("picks the spawn furthest from the nearest other player", function()
		expect(SpawnPick.farthest(spawns, { p(5, 0, 0) }, first)).toBe(2)
		expect(SpawnPick.farthest(spawns, { p(95, 0, 0), p(0, 0, 5) }, first)).toBe(3)
	end)

	it("rolls among all spawns when nobody else is there", function()
		expect(SpawnPick.farthest(spawns, {}, function(n)
			return n
		end)).toBe(3)
	end)

	it("rolls among spawns that are equally far", function()
		local seen = 0
		local picked = SpawnPick.farthest(spawns, { p(50, 0, 40) }, function(n)
			seen = n
			return 2
		end)
		expect(seen).toBe(2)
		expect(picked).toBe(2)
	end)
end)
