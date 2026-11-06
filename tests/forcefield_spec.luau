local harness = require("./harness")
local Forcefield = require("../src/shared/Guns/Forcefield")

local describe, it, expect = harness.describe, harness.it, harness.expect

local DT = 1 / 60

local function walk(state: any, from: number, to: number, seconds: number)
	local steps = math.floor(seconds / DT)
	for index = 1, steps do
		Forcefield.step(state, from + (to - from) * index / steps, DT)
	end
end

describe("Forcefield.step", function()
	it("rests flat with nobody near", function()
		local state = Forcefield.new()
		Forcefield.step(state, nil, DT)
		expect(state.depth).toBe(0)
	end)

	it("bends away from a body pressing into it", function()
		local state = Forcefield.new()
		walk(state, 8, 0.4, 0.5)
		expect(state.depth < 0).toBe(true)
		expect(state.broken).toBe(false)
	end)

	it("bends the other way from the other side", function()
		local state = Forcefield.new()
		walk(state, -8, -0.4, 0.5)
		expect(state.depth > 0).toBe(true)
	end)

	it("stays stretched over a body that is already past the plane", function()
		local state = Forcefield.new()
		walk(state, 8, -4, 0.6)
		expect(state.broken).toBe(false)
		expect(state.depth < -4).toBe(true)
	end)

	it("lets go once the body has pushed far enough", function()
		local state = Forcefield.new()
		walk(state, 8, -5.5, 0.6)
		expect(state.broken).toBe(true)
		expect(state.glitch > 0).toBe(true)
	end)

	it("holds its stretched shape as it starts letting go", function()
		local state = Forcefield.new()
		walk(state, 8, -5.5, 0.6)
		local _, _, z = Forcefield.piece(state, 0, 0, 0, 0, 0)
		expect(z < -5).toBe(true)
	end)

	it("finishes flat in the end", function()
		local state = Forcefield.new()
		walk(state, 8, -8, 0.6)
		for _ = 1, 600 do
			Forcefield.step(state, nil, DT)
		end
		expect(state.depth).toBe(0)
		expect(state.released).toBe(nil)
		expect(state.glitch < 0.01).toBe(true)
	end)

	it("gives up its return if a body presses in again", function()
		local state = Forcefield.new()
		walk(state, 8, -8, 0.6)
		walk(state, -8, -0.5, 0.3)
		expect(state.released).toBe(nil)
		expect(state.depth > 0).toBe(true)
	end)

	it("follows a body back out without letting go", function()
		local state = Forcefield.new()
		walk(state, 8, 0.4, 0.3)
		walk(state, 0.4, 8, 0.3)
		expect(state.broken).toBe(false)
	end)

	it("can be pushed through again from the far side", function()
		local state = Forcefield.new()
		walk(state, 8, -8, 0.6)
		walk(state, -8, 5.5, 0.6)
		expect(state.broken).toBe(true)
	end)
end)

describe("Forcefield.piece", function()
	local function released(seconds: number)
		local state = Forcefield.new()
		walk(state, 8, -5.5, 0.6)
		for _ = 1, math.floor(seconds / DT) do
			Forcefield.step(state, -5.5, DT)
		end
		return state
	end

	it("follows the bend before letting go", function()
		local state = Forcefield.new()
		walk(state, 8, 0, 0.5)
		local x, y, z = Forcefield.piece(state, 0, 0, 0, 0, 0)
		expect(x).toBe(0)
		expect(y).toBe(0)
		expect(z).toBe(Forcefield.offset(state.depth, 0, 0, 0, 0))
	end)

	it("moves out of the body's way, slowly and to each side", function()
		local soon = released(0.1)
		local later = released(0.5)
		local soonLeft = Forcefield.piece(soon, -0.5, 0, 0, 0, 1)
		local laterLeft = Forcefield.piece(later, -0.5, 0, 0, 0, 1)
		local laterRight = Forcefield.piece(later, 0.5, 0, 0, 0, 1)
		expect(soonLeft < 0).toBe(true)
		expect(laterLeft < soonLeft).toBe(true)
		expect(laterRight > 0).toBe(true)
	end)

	it("sends pieces home one at a time", function()
		local state = released(1.4)
		local _, _, early = Forcefield.piece(state, 0, 0, 0, 0, 0)
		local _, _, late = Forcefield.piece(state, 0, 0, 0, 0, 1)
		expect(math.abs(early) < 0.01).toBe(true)
		expect(math.abs(late) > 3).toBe(true)
	end)

	it("speeds up on the way home, like it is being sucked in", function()
		local start = released(0.9)
		local middle = released(1.0)
		local finish = released(1.1)
		local _, _, a = Forcefield.piece(start, 0, 0, 0, 0, 0)
		local _, _, b = Forcefield.piece(middle, 0, 0, 0, 0, 0)
		local _, _, c = Forcefield.piece(finish, 0, 0, 0, 0, 0)
		expect(math.abs(c - b) > math.abs(b - a)).toBe(true)
	end)
end)

describe("Forcefield.offset", function()
	it("is full depth down the body's whole height", function()
		expect(Forcefield.offset(-2, 0, 0, 0, 0)).toBe(-2)
		expect(Forcefield.offset(-2, 0.5, 2, 0, 0)).toBe(-2)
		expect(Forcefield.offset(-2, 0.5, -2.5, 0, 0)).toBe(-2)
	end)

	it("fades out past the body's sides, head and feet", function()
		expect(math.abs(Forcefield.offset(-2, 4, 0, 0, 0)) < 0.05).toBe(true)
		expect(math.abs(Forcefield.offset(-2, 0, 6.5, 0, 0)) < 0.05).toBe(true)
		expect(math.abs(Forcefield.offset(-2, 0, -7, 0, 0)) < 0.05).toBe(true)
	end)
end)
