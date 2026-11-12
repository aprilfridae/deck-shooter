local harness = require("./harness")
local Radio = require("../src/shared/Guns/Radio")

local describe, it, expect = harness.describe, harness.it, harness.expect

-- Dice that are the same every run.
local function dice(seed: number): (number) -> number
	local state = seed
	return function(n: number): number
		state = (state * 48271) % 2147483647
		return state % n + 1
	end
end

describe("Radio", function()
	it("has nothing to play with no tracks", function()
		local s = Radio.new(0)
		expect(Radio.next(s, dice(1))).toBeNil()
		expect(Radio.current(s)).toBeNil()
	end)

	it("plays every track once before any repeats", function()
		for seed = 1, 20 do
			local s = Radio.new(6)
			local roll = dice(seed)
			local heard = {}
			for _ = 1, 6 do
				local track = Radio.next(s, roll) :: number
				expect(heard[track]).toBeNil()
				heard[track] = true
			end
		end
	end)

	it("never plays the same track twice running across a reshuffle", function()
		for seed = 1, 40 do
			local s = Radio.new(4)
			local roll = dice(seed)
			local last
			for _ = 1, 40 do
				local track = Radio.next(s, roll)
				expect(track ~= last).toBe(true)
				last = track
			end
		end
	end)

	it("keeps playing its only track", function()
		local s = Radio.new(1)
		local roll = dice(3)
		expect(Radio.next(s, roll)).toBe(1)
		expect(Radio.next(s, roll)).toBe(1)
	end)

	it("goes back a track early in a song", function()
		local s = Radio.new(5)
		local roll = dice(7)
		local first = Radio.next(s, roll)
		Radio.next(s, roll)
		expect(Radio.previous(s, 1)).toBe(first)
		expect(Radio.current(s)).toBe(first)
	end)

	it("restarts the song when it's well under way", function()
		local s = Radio.new(5)
		local roll = dice(7)
		Radio.next(s, roll)
		local second = Radio.next(s, roll)
		expect(Radio.previous(s, Radio.RESTART_AFTER + 1)).toBe(second)
	end)

	it("restarts the first song when there's nothing before it", function()
		local s = Radio.new(5)
		local roll = dice(9)
		local first = Radio.next(s, roll)
		expect(Radio.previous(s, 0.5)).toBe(first)
		expect(Radio.previous(Radio.new(5), 0)).toBeNil()
	end)

	it("carries on forwards through the same songs after going back", function()
		local s = Radio.new(5)
		local roll = dice(11)
		Radio.next(s, roll)
		local second = Radio.next(s, roll)
		Radio.previous(s, 0)
		expect(Radio.next(s, roll)).toBe(second)
	end)
end)
