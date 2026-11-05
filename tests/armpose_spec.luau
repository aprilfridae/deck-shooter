local harness = require("./harness")
local ArmPose = require("../src/shared/Guns/ArmPose")

local describe, it, expect = harness.describe, harness.it, harness.expect

describe("ArmPose.step", function()
	it("holds a pose until the next step", function()
		expect(ArmPose.step(1.01, 12)).toBe(12)
		expect(ArmPose.step(1.08, 12)).toBe(12)
		expect(ArmPose.step(1.09, 12)).toBe(13)
	end)
end)

describe("ArmPose.shake", function()
	it("stays within one each way", function()
		for step = 0, 500 do
			for _, amount in { ArmPose.shake(step, 3) } do
				expect(math.abs(amount) <= 1).toBe(true)
			end
		end
	end)

	it("holds still within a step", function()
		local first = ArmPose.shake(40, 1)
		local again = ArmPose.shake(40, 1)
		expect(first).toBe(again)
	end)

	it("changes every step", function()
		for step = 0, 500 do
			expect(ArmPose.shake(step, 1) ~= ArmPose.shake(step + 1, 1)).toBe(true)
		end
	end)

	it("shakes each seed differently", function()
		expect(ArmPose.shake(40, 1) ~= ArmPose.shake(40, 2)).toBe(true)
	end)

	it("spreads to both sides", function()
		local low, high = 0, 0
		for step = 0, 500 do
			local amount = ArmPose.shake(step, 1)
			low, high = math.min(low, amount), math.max(high, amount)
		end
		expect(low < -0.7).toBe(true)
		expect(high > 0.7).toBe(true)
	end)
end)

describe("ArmPose.elbow", function()
	it("sits between shoulder and hand on a bent arm", function()
		local along, out = ArmPose.elbow(3, 4, 5)
		expect(along).toBeCloseTo(1.8)
		expect(out).toBeCloseTo(2.4)
	end)

	it("straightens when the hand is out of reach", function()
		local along, out = ArmPose.elbow(1, 1, 5)
		expect(along).toBeCloseTo(1)
		expect(out).toBeCloseTo(0)
	end)

	it("keeps the elbow valid when the hand is at the shoulder", function()
		local along, out = ArmPose.elbow(1, 1, 0)
		expect(along == along).toBe(true)
		expect(out == out).toBe(true)
	end)
end)
