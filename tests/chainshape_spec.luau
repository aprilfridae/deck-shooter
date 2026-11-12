local harness = require("./harness")
local ChainShape = require("../src/shared/CardCore/ChainShape")

local describe, it, expect = harness.describe, harness.it, harness.expect

local LENGTH = 52
local FLIGHT = ChainShape.flight(LENGTH)

describe("ChainShape", function()
	it("takes longer to fly further", function()
		expect(ChainShape.flight(260)).toBe(1)
		expect(ChainShape.flight(80) > ChainShape.flight(40)).toBe(true)
	end)

	it("flies out to its target", function()
		expect(ChainShape.reached(0, LENGTH, true)).toBe(0)
		expect(ChainShape.reached(FLIGHT / 2, LENGTH, true)).toBeCloseTo(LENGTH / 2)
		expect(ChainShape.reached(FLIGHT, LENGTH, true)).toBeCloseTo(LENGTH)
	end)

	it("stays on a target it hit", function()
		expect(ChainShape.reached(FLIGHT + 5, LENGTH, true)).toBe(LENGTH)
	end)

	it("winds back in after a miss", function()
		expect(ChainShape.reached(FLIGHT + ChainShape.HOLD, LENGTH, false)).toBe(LENGTH)
		local halfway = ChainShape.reached(FLIGHT + ChainShape.HOLD + ChainShape.RELEASE / 2, LENGTH, false)
		expect(halfway).toBeCloseTo(LENGTH / 2)
		expect(ChainShape.reached(FLIGHT + 5, LENGTH, false)).toBe(0)
	end)

	it("lets links out as the head goes, up to a most", function()
		expect(ChainShape.links(0)).toBe(0)
		expect(ChainShape.links(ChainShape.LINK * 10 + 0.01)).toBe(10)
		expect(ChainShape.links(100000)).toBe(ChainShape.MOST_LINKS)
	end)

	it("pins both ends to the line", function()
		for _, along in { 0, 1 } do
			local side, down = ChainShape.offset(along, FLIGHT / 2, LENGTH)
			expect(math.abs(side) < 1e-6).toBe(true)
			expect(math.abs(down) < 1e-6).toBe(true)
		end
	end)

	it("hangs and swings in flight, then pulls straight", function()
		local _, down = ChainShape.offset(0.5, FLIGHT / 2, LENGTH)
		expect(down < -1).toBe(true)
		local side, taut = ChainShape.offset(0.5, FLIGHT + ChainShape.HOLD, LENGTH)
		expect(side).toBe(0)
		expect(taut).toBe(0)
	end)

	it("fades only after a hit has held", function()
		expect(ChainShape.fade(FLIGHT, LENGTH, true)).toBe(0)
		expect(ChainShape.fade(ChainShape.life(LENGTH), LENGTH, true)).toBeCloseTo(1)
		expect(ChainShape.fade(ChainShape.life(LENGTH), LENGTH, false)).toBe(0)
	end)
end)
