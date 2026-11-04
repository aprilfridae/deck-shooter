local harness = require("./harness")
local Climb = require("../src/shared/Movement/Climb")
local MoveConfig = require("../src/shared/Movement/MoveConfig")

local describe, it, expect = harness.describe, harness.it, harness.expect

describe("Climb", function()
	it("ignores low steps", function()
		expect(Climb.classify(0.5)).toBeNil()
	end)

	it("parries an edge at chest height or lower", function()
		expect(Climb.classify(1)).toBe("Parry")
		expect(Climb.classify(4.5)).toBe("Parry")
	end)

	it("climbs taller edges up to 12 studs", function()
		expect(Climb.classify(4.6)).toBe("Climb")
		expect(Climb.classify(12)).toBe("Climb")
	end)

	it("treats anything taller as a wall", function()
		expect(Climb.classify(12.1)).toBeNil()
	end)

	it("needs a flat top, so a ramp is not an edge", function()
		expect(Climb.isFlat(1)).toBe(true)
		expect(Climb.isFlat(math.cos(math.rad(15)))).toBe(false)
		expect(Climb.isFlat(math.cos(math.rad(30)))).toBe(false)
	end)

	it("launches a parry high enough to clear the edge", function()
		local rise = Climb.riseSpeed(4.5, 150)
		-- height reached is rise^2 / 2g
		expect(rise * rise / 300).toBeCloseTo(6)
	end)

	it("stays inside the cheat limits on the highest parry", function()
		local rise = Climb.riseSpeed(MoveConfig.ParryMaxHeight, 150)
		expect(rise <= MoveConfig.MaxRiseSpeed).toBe(true)
	end)

	it("stays inside the cheat limits on the tallest climb", function()
		local risingTime = MoveConfig.ClimbDuration * MoveConfig.ClimbRiseShare
		expect(MoveConfig.ClimbMaxHeight / risingTime <= MoveConfig.MaxRiseSpeed).toBe(true)
	end)

	it("keeps a parry under the speed limit", function()
		expect(MoveConfig.ParryMaxSpeed + 5 <= MoveConfig.SpeedLimit).toBe(true)
	end)
end)
