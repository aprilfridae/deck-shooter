local harness = require("./harness")
local AirStrafe = require("../src/shared/Movement/AirStrafe")
local MoveConfig = require("../src/shared/Movement/MoveConfig")

local describe, it, expect = harness.describe, harness.it, harness.expect

local DT = 1 / 60

local function speed(x: number, z: number): number
	return math.sqrt(x * x + z * z)
end

describe("AirStrafe", function()
	it("keeps your velocity with no keys held", function()
		local x, z = AirStrafe.accelerate(12, -5, 0, 0, DT)
		expect(x).toBe(12)
		expect(z).toBe(-5)
	end)

	it("adds nothing when you hold forward at speed", function()
		local x, z = AirStrafe.accelerate(MoveConfig.SprintSpeed, 0, 1, 0, DT)
		expect(x).toBe(MoveConfig.SprintSpeed)
		expect(z).toBe(0)
	end)

	it("gives a standing jump only the small cap of speed", function()
		local x, z = 0, 0
		for _ = 1, 120 do
			x, z = AirStrafe.accelerate(x, z, 1, 0, DT)
		end
		expect(speed(x, z)).toBeCloseTo(AirStrafe.cap)
	end)

	it("turns you and speeds you up when you strafe across your path", function()
		local x, z = MoveConfig.SprintSpeed, 0
		local nx, nz = AirStrafe.accelerate(x, z, 0, 1, DT)
		expect(nz > 0).toBe(true)
		expect(speed(nx, nz) > speed(x, z)).toBe(true)
	end)

	it("gains speed over a held strafe that follows the turn", function()
		local x, z = MoveConfig.SprintSpeed, 0
		for _ = 1, 60 do
			-- Ask for the direction a quarter turn round from where you're going, as a strafe with the view does.
			local s = speed(x, z)
			x, z = AirStrafe.accelerate(x, z, -z / s, x / s, DT)
		end
		expect(speed(x, z) > MoveConfig.SprintSpeed + 1).toBe(true)
	end)

	it("slows you when you ask for the way you came from", function()
		local x = AirStrafe.accelerate(MoveConfig.SprintSpeed, 0, -1, 0, DT)
		expect(x < MoveConfig.SprintSpeed).toBe(true)
	end)

	it("stops gaining at the top air speed but keeps speed you already had", function()
		local x, z = MoveConfig.AirStrafeMaxSpeed, 0
		for _ = 1, 240 do
			local s = speed(x, z)
			x, z = AirStrafe.accelerate(x, z, -z / s, x / s, DT)
		end
		expect(speed(x, z)).toBeCloseTo(MoveConfig.AirStrafeMaxSpeed, 1e-3)
		local fast = MoveConfig.AirStrafeMaxSpeed + 10
		local fx, fz = AirStrafe.accelerate(fast, 0, 0, 1, DT)
		expect(speed(fx, fz)).toBeCloseTo(fast, 1e-3)
	end)

	it("stays under the cheat check's speed limit", function()
		expect(MoveConfig.AirStrafeMaxSpeed + 5 <= MoveConfig.SpeedLimit).toBe(true)
	end)
end)
