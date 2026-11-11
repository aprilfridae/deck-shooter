local harness = require("./harness")
local describe, it, expect = harness.describe, harness.it, harness.expect

local ShotKick = require("../src/shared/Movement/ShotKick")

local function run(kick, seconds: number, dt: number): number
	local top = 0
	for _ = 1, math.floor(seconds / dt) do
		top = math.max(top, ShotKick.step(kick, dt))
	end
	return top
end

describe("ShotKick", function()
	it("rests at nothing", function()
		local kick = ShotKick.new()
		expect(ShotKick.step(kick, 1 / 60)).toBe(0)
	end)

	it("peaks near the shot's strength and settles back", function()
		local kick = ShotKick.new()
		ShotKick.hit(kick, 1)
		local top = run(kick, 0.6, 1 / 60)
		expect(top > 0.6 and top < 1.3).toBe(true)
		expect(math.abs(kick.at) < 0.02).toBe(true)
	end)

	it("is the same at any frame rate", function()
		local fast, slow = ShotKick.new(), ShotKick.new()
		ShotKick.hit(fast, 1)
		ShotKick.hit(slow, 1)
		expect(run(fast, 0.5, 1 / 240)).toBeCloseTo(run(slow, 0.5, 1 / 30), 0.08)
	end)

	it("doesn't stack without limit under fast fire", function()
		local kick = ShotKick.new()
		local top = 0
		for _ = 1, 60 do
			ShotKick.hit(kick, 2.6)
			top = math.max(top, run(kick, 0.05, 1 / 60))
		end
		expect(top <= 2.6).toBe(true)
	end)

	it("twists the other way each shot", function()
		local kick = ShotKick.new()
		local first = kick.side
		ShotKick.hit(kick, 1)
		expect(kick.side).toBe(-first)
	end)

	it("kicks harder for a gun with more view kick", function()
		expect(ShotKick.strength(1.2) > ShotKick.strength(0.12)).toBe(true)
		expect(ShotKick.strength(nil) >= 0.8).toBe(true)
	end)
end)
