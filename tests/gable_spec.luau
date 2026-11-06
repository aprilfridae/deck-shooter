local harness = require("./harness")
local Gable = require("../src/server/Outpost/Gable")

local describe, it, expect = harness.describe, harness.it, harness.expect

local OUTER, INNER = 23, 20
-- The vault is flat segments, so its inside corners sit a little past the inner radius.
local INNER_CORNER = INNER / math.cos(math.pi / 32)

describe("Gable.lifts", function()
	it("stacks lifts from the springing to above the vault's inside", function()
		local lifts = Gable.lifts(OUTER, INNER)
		expect(lifts[1].bottom).toBe(0)
		for index = 2, #lifts do
			expect(lifts[index].bottom).toBe(lifts[index - 1].top)
		end
		expect(lifts[#lifts].top >= INNER_CORNER).toBe(true)
	end)

	it("keeps every top corner under the roof's outer face", function()
		for _, lift in Gable.lifts(OUTER, INNER) do
			expect(math.sqrt(lift.half ^ 2 + lift.top ^ 2) < OUTER).toBe(true)
		end
	end)

	it("leaves no gap under the vault", function()
		for _, lift in Gable.lifts(OUTER, INNER) do
			expect(math.sqrt(lift.half ^ 2 + lift.bottom ^ 2) > INNER_CORNER).toBe(true)
		end
	end)
end)
