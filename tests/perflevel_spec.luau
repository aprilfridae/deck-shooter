local harness = require("./harness")
local PerfLevel = require("../src/shared/Guns/PerfLevel")

local describe, it, expect = harness.describe, harness.it, harness.expect

-- Runs frames at fps for some seconds from time `from`. Returns the time it ended.
local function run(state: any, fps: number, seconds: number, from: number): number
	local now = from
	for _ = 1, math.floor(seconds * fps) do
		now += 1 / fps
		PerfLevel.step(state, 1 / fps, now)
	end
	return now
end

describe("PerfLevel", function()
	it("starts at everything, or lower if the player has turned Roblox's graphics down", function()
		expect(PerfLevel.new().level).toBe(3)
		expect(PerfLevel.new(0).level).toBe(3)
		expect(PerfLevel.new(10).level).toBe(3)
		expect(PerfLevel.new(5).level).toBe(2)
		expect(PerfLevel.new(2).level).toBe(1)
	end)

	it("stays put while the game runs well", function()
		local state = PerfLevel.new()
		run(state, 60, 30, 0)
		expect(state.level).toBe(3)
	end)

	it("steps down when the game is drawn slowly for a while, a level at a time", function()
		local state = PerfLevel.new()
		local now = run(state, 30, 1, 0)
		expect(state.level).toBe(3) -- not yet
		now = run(state, 30, 2, now)
		expect(state.level).toBe(2)
		run(state, 30, 3, now)
		expect(state.level).toBe(1)
		run(state, 20, 20, now)
		expect(state.level).toBe(1) -- no lower
	end)

	it("steps back up once there has been room to spare for a good while", function()
		local state = PerfLevel.new(2)
		local now = run(state, 60, 5, 0)
		expect(state.level).toBe(1)
		now = run(state, 60, 5, now)
		expect(state.level).toBe(2)
		run(state, 60, 10, now)
		expect(state.level).toBe(3)
	end)

	it("doesn't count a hitch", function()
		local state = PerfLevel.new()
		local now = 0
		for _ = 1, 20 do
			now += 0.5
			PerfLevel.step(state, 0.5, now)
		end
		expect(state.level).toBe(3)
	end)

	it("stops trying a level that was too much", function()
		local state = PerfLevel.new(5)
		local now = run(state, 60, 9, 0)
		expect(state.level).toBe(3) -- raised
		now = run(state, 30, 2.5, now)
		expect(state.level).toBe(2) -- and straight back down
		now = run(state, 60, 60, now)
		expect(state.level).toBe(2) -- it stays under it
		run(state, 60, 180, now)
		expect(state.level).toBe(3) -- until much later
	end)

	it("picks by level", function()
		expect(PerfLevel.pick(3, "a", "b", "c")).toBe("a")
		expect(PerfLevel.pick(2, "a", "b", "c")).toBe("b")
		expect(PerfLevel.pick(1, "a", "b", "c")).toBe("c")
	end)
end)
