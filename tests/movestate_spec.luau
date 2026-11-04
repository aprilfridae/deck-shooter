local harness = require("./harness")
local MoveState = require("../src/shared/Movement/MoveState")

local describe, it, expect = harness.describe, harness.it, harness.expect

local function on(fields: { [string]: boolean }?)
	local input = { moving = false, sprint = false, crouch = false, jump = false, grounded = true }
	for key, value in fields or {} do
		input[key] = value
	end
	return input
end

local sprinting = { moving = true, sprint = true }
local sliding = { moving = true, sprint = true, crouch = true }

-- Sprints at t, then presses crouch at t + 0.1, so the slide starts at t + 0.1.
local function sprintThenSlide(s: any, t: number)
	MoveState.step(s, on(sprinting), t)
	MoveState.step(s, on(sliding), t + 0.1)
end

describe("MoveState", function()
	it("walks, sprints and crouches at spec speeds", function()
		local s = MoveState.new()
		MoveState.step(s, on({ moving = true }), 0)
		expect(s.mode).toBe("Walk")
		expect(MoveState.speed(s, 0)).toBe(16)
		MoveState.step(s, on(sprinting), 1)
		expect(s.mode).toBe("Sprint")
		expect(MoveState.speed(s, 1)).toBe(24)
		MoveState.step(s, on({ moving = true, crouch = true }), 2)
		expect(s.mode).toBe("Crouch")
		expect(MoveState.speed(s, 2)).toBe(8)
	end)

	it("does not sprint while standing still", function()
		local s = MoveState.new()
		MoveState.step(s, on({ sprint = true }), 0)
		expect(s.mode).toBe("Walk")
	end)

	it("starts a slide from a sprint at 42 and slows over 0.9s", function()
		local s = MoveState.new()
		sprintThenSlide(s, 0)
		expect(s.mode).toBe("Slide")
		expect(MoveState.speed(s, 0.1)).toBeCloseTo(42)
		expect(MoveState.speed(s, 0.55)).toBeCloseTo(33)
	end)

	it("does not start a slide from a walk", function()
		local s = MoveState.new()
		MoveState.step(s, on({ moving = true }), 0)
		MoveState.step(s, on({ moving = true, crouch = true }), 0.1)
		expect(s.mode).toBe("Crouch")
	end)

	it("ends a slide after 0.9s, into a crouch while crouch is held", function()
		local s = MoveState.new()
		sprintThenSlide(s, 0)
		MoveState.step(s, on(sliding), 1.01)
		expect(s.mode).toBe("Crouch")
	end)

	it("ends a slide after 0.9s, into a sprint when crouch is released", function()
		local s = MoveState.new()
		sprintThenSlide(s, 0)
		MoveState.step(s, on(sprinting), 1.01)
		expect(s.mode).toBe("Sprint")
	end)

	it("can slide again as soon as a slide ends", function()
		local s = MoveState.new()
		sprintThenSlide(s, 0)
		MoveState.step(s, on(sprinting), 1.01)
		MoveState.step(s, on(sliding), 1.02)
		expect(s.mode).toBe("Slide")
	end)

	it("needs only movement to slide, so no direction blocks it", function()
		local s = MoveState.new()
		MoveState.step(s, on(sprinting), 0)
		MoveState.step(s, on({ moving = false, sprint = true, crouch = true }), 0.1)
		expect(s.mode).toBe("Crouch")
	end)

	it("cancels with a jump and holds speed in the air", function()
		local s = MoveState.new()
		sprintThenSlide(s, 0)
		MoveState.step(s, on({ moving = true, jump = true, grounded = false }), 0.2)
		expect(s.mode).toBe("Air")
		expect(MoveState.speed(s, 0.2)).toBeCloseTo(40)
		expect(MoveState.speed(s, 0.9)).toBeCloseTo(40)
	end)

	it("cancels with a second crouch press and fades to normal speed over 0.25s", function()
		local s = MoveState.new()
		sprintThenSlide(s, 0)
		MoveState.step(s, on(sprinting), 0.2)
		expect(s.mode).toBe("Slide")
		MoveState.step(s, on(sliding), 0.3)
		expect(s.mode).toBe("Crouch")
		expect(MoveState.speed(s, 0.3)).toBeCloseTo(38)
		expect(MoveState.speed(s, 0.55)).toBe(8)
	end)

	it("can slide again right after cancelling one", function()
		local s = MoveState.new()
		sprintThenSlide(s, 0)
		MoveState.step(s, on(sprinting), 0.2)
		MoveState.step(s, on(sliding), 0.3)
		MoveState.step(s, on(sprinting), 0.31)
		MoveState.step(s, on(sliding), 0.32)
		expect(s.mode).toBe("Slide")
	end)

	it("slides on landing when crouch is held in the air", function()
		local s = MoveState.new()
		sprintThenSlide(s, 0)
		MoveState.step(s, on({ moving = true, sprint = true, crouch = true, jump = true, grounded = false }), 0.2)
		MoveState.step(s, on(sliding), 1)
		expect(s.mode).toBe("Slide")
		expect(MoveState.speed(s, 1)).toBeCloseTo(42)
	end)

	it("does not slide on landing without a sprint", function()
		local s = MoveState.new()
		MoveState.step(s, on({ moving = true, jump = true, grounded = false }), 0)
		MoveState.step(s, on({ moving = true, crouch = true }), 1)
		expect(s.mode).toBe("Crouch")
	end)

	it("fades carried speed after landing", function()
		local s = MoveState.new()
		sprintThenSlide(s, 0)
		MoveState.step(s, on({ moving = true, jump = true, grounded = false }), 0.2)
		MoveState.step(s, on(sprinting), 1)
		expect(s.mode).toBe("Sprint")
		expect(MoveState.speed(s, 1)).toBeCloseTo(40)
		expect(MoveState.speed(s, 1.3)).toBeCloseTo(32)
		expect(MoveState.speed(s, 1.6)).toBe(24)
	end)

	it("keeps a plain jump at the takeoff speed", function()
		local s = MoveState.new()
		MoveState.step(s, on(sprinting), 0)
		MoveState.step(s, on({ moving = true, sprint = true, jump = true, grounded = false }), 0.1)
		expect(s.mode).toBe("Air")
		expect(MoveState.speed(s, 0.5)).toBe(24)
	end)

	-- Review Focus 4
	it("ends the slide when the player leaves the ground", function()
		local s = MoveState.new()
		sprintThenSlide(s, 0)
		MoveState.step(s, on({ moving = true, sprint = true, grounded = false }), 0.3)
		expect(s.mode).toBe("Air")
		MoveState.step(s, on(sprinting), 0.6)
		expect(s.mode).toBe("Sprint")
		MoveState.step(s, on(sliding), 0.7)
		expect(s.mode).toBe("Slide")
	end)

	-- Review Focus 5
	it("does not slide from crouch held before sprinting", function()
		local s = MoveState.new()
		MoveState.step(s, on({ moving = true, crouch = true }), 0)
		MoveState.step(s, on(sliding), 1)
		expect(s.mode).toBe("Crouch")
	end)

	it("does not restart a slide from a held key", function()
		local s = MoveState.new()
		sprintThenSlide(s, 0)
		MoveState.step(s, on(sliding), 1.01)
		MoveState.step(s, on(sliding), 2.5)
		expect(s.mode).toBe("Crouch")
	end)
end)
