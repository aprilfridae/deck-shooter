local harness = require("./harness")
local Parry = require("../src/shared/Movement/Parry")
local MoveConfig = require("../src/shared/Movement/MoveConfig")

local describe, it, expect = harness.describe, harness.it, harness.expect

describe("Parry", function()
	it("ignores low steps", function()
		expect(Parry.allows(0.5)).toBe(false)
	end)

	it("parries an edge at chest height or lower", function()
		expect(Parry.allows(1)).toBe(true)
		expect(Parry.allows(4.5)).toBe(true)
	end)

	it("ignores anything taller, now that there's no climb", function()
		expect(Parry.allows(4.6)).toBe(false)
		expect(Parry.allows(12)).toBe(false)
	end)

	it("only counts flat tops", function()
		expect(Parry.isFlat(1)).toBe(true)
		expect(Parry.isFlat(math.cos(math.rad(15)))).toBe(false)
		expect(Parry.isFlat(math.cos(math.rad(30)))).toBe(false)
	end)

	it("launches a parry high enough to clear the edge", function()
		local rise = Parry.riseSpeed(4.5, 150)
		-- height reached is rise^2 / 2g
		expect(rise * rise / 300).toBeCloseTo(6)
	end)

	it("stays inside the cheat limits on the highest parry", function()
		local rise = Parry.riseSpeed(MoveConfig.ParryMaxHeight, 150)
		expect(rise <= MoveConfig.MaxRiseSpeed).toBe(true)
	end)

	it("keeps a parry under the speed limit", function()
		expect(MoveConfig.ParryMaxSpeed + 5 <= MoveConfig.SpeedLimit).toBe(true)
	end)
end)
