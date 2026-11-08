local roblox = require("@lune/roblox")
local harness = require("./harness")
local Flyby = require("../src/shared/Guns/Flyby")

local describe, it, expect = harness.describe, harness.it, harness.expect
local Vector3 = roblox.Vector3

describe("Flyby.pass", function()
	local head = Vector3.new(0, 0, 0)

	it("finds where a bullet passes close by and how close", function()
		local along, distance = Flyby.pass(Vector3.new(-50, 2, 0), Vector3.new(50, 2, 0), head)
		expect(along).toBeCloseTo(50)
		expect(distance).toBeCloseTo(2)
	end)

	it("ignores bullets that pass too far away", function()
		local along = Flyby.pass(Vector3.new(-50, Flyby.RADIUS + 1, 0), Vector3.new(50, Flyby.RADIUS + 1, 0), head)
		expect(along).toBe(nil)
	end)

	it("ignores bullets that stop before reaching you", function()
		local along = Flyby.pass(Vector3.new(-50, 1, 0), Vector3.new(-3, 1, 0), head)
		expect(along).toBe(nil)
	end)

	it("ignores bullets fired from behind you going away", function()
		local along = Flyby.pass(Vector3.new(1, 1, 0), Vector3.new(50, 1, 0), head)
		expect(along).toBe(nil)
	end)
end)
