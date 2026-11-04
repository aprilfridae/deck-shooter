local harness = require("./harness")
local SpeedLimit = require("../src/shared/Movement/SpeedLimit")

local describe, it, expect = harness.describe, harness.it, harness.expect

-- Moves along x at a steady speed, sampling every 0.1s, and returns the
-- number of the first failing sample, or nil if every sample passes.
local function run(track: any, speed: number, seconds: number): number?
	local samples = math.floor(seconds * 10 + 0.5)
	for i = 1, samples do
		local t = i / 10
		if not SpeedLimit.sample(track, speed * t, 0, 0, t) then
			return i
		end
	end
	return nil
end

describe("SpeedLimit", function()
	it("passes a slide-speed run", function()
		expect(run(SpeedLimit.new(0, 0, 0, 0), 34, 3)).toBeNil()
	end)

	it("fails a speed hack and keeps the last valid position", function()
		local track = SpeedLimit.new(0, 0, 0, 0)
		SpeedLimit.sample(track, 3, 0, 0, 0.1)
		SpeedLimit.sample(track, 6, 0, 0, 0.2)
		local failedAt
		for i = 1, 5 do
			if not SpeedLimit.sample(track, 6 + 10 * i, 0, 0, 0.2 + i / 10) then
				failedAt = i
				break
			end
		end
		expect(failedAt).toBeTruthy()
		expect(failedAt <= 5).toBe(true)
		expect(track.lastValid.x).toBe(6 + 10 * (failedAt - 1))
	end)

	it("does not update lastValid on a failed sample", function()
		local track = SpeedLimit.new(1, 2, 3, 0)
		expect(SpeedLimit.sample(track, 500, 2, 3, 0.1)).toBe(false)
		expect(track.lastValid).toEqual({ x = 1, y = 2, z = 3 })
	end)

	it("restarts from the last valid position after a failure", function()
		local track = SpeedLimit.new(0, 0, 0, 0)
		SpeedLimit.sample(track, 500, 0, 0, 0.1)
		expect(SpeedLimit.sample(track, 2, 0, 0, 0.2)).toBe(true)
	end)

	it("fails a 200-stud teleport", function()
		local track = SpeedLimit.new(0, 0, 0, 0)
		expect(SpeedLimit.sample(track, 0, 0, 200, 0.1)).toBe(false)
	end)

	it("fails rising faster than 60 studs/sec", function()
		local track = SpeedLimit.new(0, 0, 0, 0)
		local passed = true
		for i = 1, 5 do
			passed = SpeedLimit.sample(track, 0, 80 * i / 10, 0, i / 10)
			if not passed then
				break
			end
		end
		expect(passed).toBe(false)
	end)

	it("passes a normal jump at 50 studs/sec", function()
		local track = SpeedLimit.new(0, 0, 0, 0)
		for i = 1, 5 do
			expect(SpeedLimit.sample(track, 0, 50 * i / 10, 0, i / 10)).toBe(true)
		end
	end)

	it("adds strikes and reports the fifth", function()
		local track = SpeedLimit.new(0, 0, 0, 0)
		for _ = 1, 4 do
			expect(SpeedLimit.addStrike(track)).toBe(false)
		end
		expect(SpeedLimit.addStrike(track)).toBe(true)
	end)

	-- Review Focus 1
	it("reset moves the track without a failure", function()
		local track = SpeedLimit.new(0, 0, 0, 0)
		SpeedLimit.reset(track, 1000, 0, 0, 1)
		expect(SpeedLimit.sample(track, 1001, 0, 0, 1.1)).toBe(true)
		expect(track.lastValid.x).toBe(1001)
		expect(track.strikes).toBe(0)
	end)

	-- Review Focus 2
	it("passes legal travel after a long gap", function()
		local track = SpeedLimit.new(0, 0, 0, 0)
		expect(SpeedLimit.sample(track, 48, 0, 0, 2)).toBe(true)
	end)

	-- The guard keeps sampling through a stall, so the frozen position repeats.
	it("passes legal travel after a stall the guard sampled through", function()
		local track = SpeedLimit.new(0, 0, 0, 0)
		for i = 1, 10 do
			expect(SpeedLimit.sample(track, 3.4 * i, 0, 0, i / 10)).toBe(true)
		end
		for i = 11, 20 do
			expect(SpeedLimit.sample(track, 34, 0, 0, i / 10)).toBe(true)
		end
		expect(SpeedLimit.sample(track, 68, 0, 0, 2)).toBe(true)
	end)

	it("caps the credit from standing still", function()
		local track = SpeedLimit.new(0, 0, 0, 0)
		for i = 1, 100 do
			SpeedLimit.sample(track, 0, 0, 0, i / 10)
		end
		expect(SpeedLimit.sample(track, 100, 0, 0, 10.1)).toBe(false)
	end)

	-- Review Focus 3
	it("never fails on falling", function()
		local track = SpeedLimit.new(0, 0, 0, 0)
		expect(SpeedLimit.sample(track, 0, -500, 0, 0.5)).toBe(true)
	end)

	it("treats an unreadable position as a failure", function()
		local track = SpeedLimit.new(0, 0, 0, 0)
		expect(SpeedLimit.sample(track, 0 / 0, 0, 0, 0.1)).toBe(false)
	end)
end)
