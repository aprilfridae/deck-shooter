local harness = require("./harness")
local Flicker = require("../src/shared/Guns/Flicker")

local describe, it, expect = harness.describe, harness.it, harness.expect

describe("Flicker", function()
	it("stays near full brightness and never goes far down", function()
		local lowest, total, count = 1, 0, 0
		for seed = 1, 20 do
			for step = 0, 3000 do
				local b = Flicker.at(seed, step / 60)
				expect(b <= 1).toBe(true)
				lowest = math.min(lowest, b)
				total += b
				count += 1
			end
		end
		expect(lowest >= 1 - Flicker.SHIMMER - Flicker.DIP).toBe(true)
		expect(total / count > 0.95).toBe(true)
	end)

	it("dips now and then", function()
		local dipped = false
		for seed = 1, 20 do
			for step = 0, 3000 do
				if Flicker.at(seed, step / 60) < 1 - Flicker.SHIMMER - 0.05 then
					dipped = true
				end
			end
		end
		expect(dipped).toBe(true)
	end)

	it("doesn't pulse every light together", function()
		expect(Flicker.at(1, 2.5) ~= Flicker.at(2, 2.5)).toBe(true)
	end)
end)
