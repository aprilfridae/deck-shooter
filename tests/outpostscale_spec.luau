local harness = require("./harness")
local OutpostScale = require("../src/server/Outpost/OutpostScale")

local describe, it, expect = harness.describe, harness.it, harness.expect

local PLAYER_HEIGHT = 5.6

describe("OutpostScale", function()
	it("shrinks the Outpost", function()
		expect(OutpostScale.factor < 1).toBe(true)
	end)

	it("leaves the lowest doorway taller than the player", function()
		expect(OutpostScale.liftDoor * OutpostScale.factor > PLAYER_HEIGHT).toBe(true)
	end)
end)
