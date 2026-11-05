local harness = require("./harness")
local HitMarker = require("../src/shared/Guns/HitMarker")

local describe, it, expect = harness.describe, harness.it, harness.expect

describe("HitMarker.look", function()
	it("pops up big and solid", function()
		local scale, transparency = HitMarker.look(0, 0.3, 1.6)
		expect(scale).toBeCloseTo(1.6)
		expect(transparency).toBeCloseTo(0)
	end)

	it("has shrunk to its normal size partway through, still solid", function()
		local scale, transparency = HitMarker.look(0.12, 0.3, 1.6)
		expect(scale).toBeCloseTo(1)
		expect(transparency).toBeCloseTo(0)
	end)

	it("fades out over the second half", function()
		local _, transparency = HitMarker.look(0.225, 0.3, 1.6)
		expect(transparency).toBeCloseTo(0.5)
	end)

	it("is gone at the end of its life", function()
		expect(HitMarker.look(0.3, 0.3, 1.6)).toBe(nil)
	end)
end)
