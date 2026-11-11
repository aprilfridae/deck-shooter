local harness = require("./harness")
local MoveState = require("../src/shared/Movement/MoveState")
local MoveConfig = require("../src/shared/Movement/MoveConfig")

-- A slide's speed this long after it starts, while it is still slowing to sprint speed.
local function slideAt(seconds: number): number
	return MoveConfig.SlideStartSpeed - (MoveConfig.SlideStartSpeed - MoveConfig.SprintSpeed) * seconds / MoveConfig.SlideFadeTime
end

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
		expect(MoveState.speed(s, 0)).toBe(MoveConfig.WalkSpeed)
		MoveState.step(s, on(sprinting), 1)
		expect(s.mode).toBe("Sprint")
		expect(MoveState.speed(s, 1)).toBe(MoveConfig.SprintSpeed)
		MoveState.step(s, on({ moving = true, crouch = true }), 2)
		expect(s.mode).toBe("Crouch")
		expect(MoveState.speed(s, 2)).toBe(MoveConfig.CrouchSpeed)
	end)

	it("does not sprint while standing still", function()
		local s = MoveState.new()
		MoveState.step(s, on({ sprint = true }), 0)
		expect(s.mode).toBe("Walk")
	end)

	it("starts a slide from a sprint at slide speed and slows over 0.9s", function()
		local s = MoveState.new()
		sprintThenSlide(s, 0)
		expect(s.mode).toBe("Slide")
		expect(MoveState.speed(s, 0.1)).toBeCloseTo(MoveConfig.SlideStartSpeed)
		expect(MoveState.speed(s, 0.55)).toBeCloseTo((MoveConfig.SlideStartSpeed + MoveConfig.SprintSpeed) / 2)
	end)

	it("does not start a slide from a walk", function()
		local s = MoveState.new()
		MoveState.step(s, on({ moving = true }), 0)
		MoveState.step(s, on({ moving = true, crouch = true }), 0.1)
		expect(s.mode).toBe("Crouch")
	end)

	it("keeps sliding at sprint speed for as long as crouch is held", function()
		local s = MoveState.new()
		sprintThenSlide(s, 0)
		MoveState.step(s, on(sliding), 1.01)
		MoveState.step(s, on(sliding), 5)
		expect(s.mode).toBe("Slide")
		expect(MoveState.speed(s, 5)).toBe(MoveConfig.SprintSpeed)
	end)

	it("ends a slide when crouch is released and fades to normal speed over 0.25s", function()
		local s = MoveState.new()
		sprintThenSlide(s, 0)
		MoveState.step(s, on(sprinting), 0.3)
		expect(s.mode).toBe("Sprint")
		expect(MoveState.speed(s, 0.3)).toBeCloseTo(slideAt(0.2))
		expect(MoveState.speed(s, 0.55)).toBe(MoveConfig.SprintSpeed)
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

	it("cancels with a jump, adds a boost and holds it in the air", function()
		local s = MoveState.new()
		sprintThenSlide(s, 0)
		MoveState.step(s, on({ moving = true, jump = true, grounded = false }), 0.2)
		expect(s.mode).toBe("Air")
		expect(MoveState.speed(s, 0.2)).toBeCloseTo(slideAt(0.1) + MoveConfig.SlideJumpBoost)
		expect(MoveState.speed(s, 0.9)).toBeCloseTo(slideAt(0.1) + MoveConfig.SlideJumpBoost)
	end)

	it("slides on landing when crouch is held in the air", function()
		local s = MoveState.new()
		sprintThenSlide(s, 0)
		MoveState.step(s, on({ moving = true, sprint = true, crouch = true, jump = true, grounded = false }), 0.2)
		MoveState.step(s, on(sliding), 1)
		expect(s.mode).toBe("Slide")
		expect(MoveState.speed(s, 1)).toBeCloseTo(MoveConfig.SlideStartSpeed)
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
		expect(MoveState.speed(s, 1)).toBeCloseTo(slideAt(0.1) + MoveConfig.SlideJumpBoost)
		expect(MoveState.speed(s, 1.3)).toBeCloseTo((slideAt(0.1) + MoveConfig.SlideJumpBoost + MoveConfig.SprintSpeed) / 2)
		expect(MoveState.speed(s, 1.6)).toBe(MoveConfig.SprintSpeed)
	end)

	it("stays in the air until a jump has had time to lift off", function()
		local s = MoveState.new()
		sprintThenSlide(s, 0)
		MoveState.step(s, on({ moving = true, jump = true }), 0.2)
		MoveState.step(s, on(sprinting), 0.21)
		expect(s.mode).toBe("Air")
		expect(MoveState.speed(s, 0.21)).toBeCloseTo(slideAt(0.1) + MoveConfig.SlideJumpBoost)
		MoveState.step(s, on(sprinting), 0.31)
		expect(s.mode).toBe("Sprint")
	end)

	it("keeps a plain jump at the takeoff speed", function()
		local s = MoveState.new()
		MoveState.step(s, on(sprinting), 0)
		MoveState.step(s, on({ moving = true, sprint = true, jump = true, grounded = false }), 0.1)
		expect(s.mode).toBe("Air")
		expect(MoveState.speed(s, 0.5)).toBe(MoveConfig.SprintSpeed)
	end)

	describe("wall jump", function()
		it("keeps the speed it had, adds a little, and stays in the air", function()
			local s = MoveState.new()
			MoveState.step(s, on({ moving = true, sprint = true, grounded = false, jump = true }), 0)
			local before = math.max(MoveState.speed(s, 0.3), MoveConfig.SprintSpeed) -- it has at least sprint speed
			MoveState.wallJump(s, 0.3)
			expect(s.mode).toBe("Air")
			expect(MoveState.speed(s, 0.35)).toBe(before + MoveConfig.WallJumpBoost)
			MoveState.wallJump(s, 0.6)
			expect(MoveState.speed(s, 0.65)).toBe(before + 2 * MoveConfig.WallJumpBoost)
		end)

		it("never goes past the fastest parry", function()
			local s = MoveState.new()
			MoveState.launch(s, MoveConfig.ParryMaxSpeed - 1, 0)
			MoveState.wallJump(s, 0.3)
			expect(MoveState.speed(s, 0.35)).toBe(MoveConfig.ParryMaxSpeed)
		end)
	end)

	describe("edge parry", function()
		it("keeps slide speed and adds a bump", function()
			local s = MoveState.new()
			sprintThenSlide(s, 0)
			MoveState.parry(s, 0.55)
			expect(s.mode).toBe("Air")
			expect(MoveState.speed(s, 0.55)).toBeCloseTo((MoveConfig.SlideStartSpeed + MoveConfig.SprintSpeed) / 2 + MoveConfig.ParryBoost)
			expect(MoveState.speed(s, 1.2)).toBeCloseTo((MoveConfig.SlideStartSpeed + MoveConfig.SprintSpeed) / 2 + MoveConfig.ParryBoost)
		end)

		it("reaches at least a boosted sprint from a walk", function()
			local s = MoveState.new()
			MoveState.step(s, on({ moving = true }), 0)
			MoveState.parry(s, 0.1)
			expect(MoveState.speed(s, 0.1)).toBe(MoveConfig.SprintSpeed + MoveConfig.ParryBoost)
		end)

		it("is capped at the fastest chain jump", function()
			local s = MoveState.new()
			s.mode = "Air"
			s.carrySpeed = 57
			MoveState.parry(s, 1)
			expect(MoveState.speed(s, 1)).toBe(MoveConfig.ParryMaxSpeed)
		end)

		it("stays in the air until it has lifted off", function()
			local s = MoveState.new()
			MoveState.step(s, on(sprinting), 0)
			MoveState.parry(s, 0.1)
			MoveState.step(s, on(sprinting), 0.11)
			expect(s.mode).toBe("Air")
		end)
	end)

	describe("dash", function()
		it("holds the rules still until the dash finishes", function()
			local s = MoveState.new()
			MoveState.step(s, on(sprinting), 0)
			MoveState.startDash(s)
			MoveState.step(s, on({ moving = true, grounded = false }), 0.1)
			expect(s.mode).toBe("Dash")
			expect(MoveState.speed(s, 0.1)).toBe(0)
		end)

		it("leaves the player in the air at least at sprint speed", function()
			local s = MoveState.new()
			MoveState.startDash(s)
			MoveState.finishDash(s, 0, 30, 1)
			expect(s.mode).toBe("Air")
			expect(MoveState.speed(s, 2)).toBe(MoveConfig.SprintSpeed)
		end)
	end)

	describe("chain jump", function()
		local airJump = { moving = true, jump = true, grounded = false }

		-- Slide jump, hold crouch in the air, land into a slide at t = 1.
		local function chained()
			local s = MoveState.new()
			sprintThenSlide(s, 0)
			MoveState.step(s, on({ moving = true, sprint = true, crouch = true, jump = true, grounded = false }), 0.2)
			MoveState.step(s, on(sliding), 1)
			return s
		end

		it("launches faster from a slide that followed a fast fall", function()
			local s = chained()
			MoveState.step(s, on(airJump), 1.1)
			expect(MoveState.speed(s, 1.1)).toBeCloseTo(slideAt(0.1) + MoveConfig.ChainJumpBoost)
		end)

		it("jumps higher through the slide and the jump", function()
			local s = chained()
			expect(MoveState.jumpHeight(s)).toBe(8)
			MoveState.step(s, on(airJump), 1.1)
			expect(MoveState.jumpHeight(s)).toBe(8)
		end)

		it("keeps a plain slide jump at normal height", function()
			local s = MoveState.new()
			sprintThenSlide(s, 0)
			expect(MoveState.jumpHeight(s)).toBe(MoveConfig.JumpHeight)
			MoveState.step(s, on(airJump), 0.2)
			expect(MoveState.jumpHeight(s)).toBe(6)
			expect(MoveState.speed(s, 0.2)).toBeCloseTo(slideAt(0.1) + MoveConfig.SlideJumpBoost)
		end)

		it("can chain again from another fast fall", function()
			local s = chained()
			MoveState.step(s, on({ moving = true, sprint = true, crouch = true, jump = true, grounded = false }), 1.1)
			MoveState.step(s, on(sliding), 2)
			expect(MoveState.jumpHeight(s)).toBe(8)
		end)

		it("ends when the player lands without sliding", function()
			local s = chained()
			MoveState.step(s, on(airJump), 1.1)
			MoveState.step(s, on(sprinting), 2)
			expect(MoveState.jumpHeight(s)).toBe(MoveConfig.JumpHeight)
		end)

		it("ends when crouch is released during the slide", function()
			local s = chained()
			MoveState.step(s, on(sprinting), 2)
			expect(MoveState.jumpHeight(s)).toBe(MoveConfig.JumpHeight)
		end)

		it("ends when the player slides off a ledge without jumping", function()
			local s = chained()
			MoveState.step(s, on({ moving = true, sprint = true, grounded = false }), 1.1)
			expect(MoveState.jumpHeight(s)).toBe(MoveConfig.JumpHeight)
		end)
	end)

	describe("fast fall", function()
		local function airborne(crouch: boolean)
			local s = MoveState.new()
			MoveState.step(s, on({ moving = true, crouch = crouch, grounded = false }), 0)
			return s
		end

		it("speeds up a fall while crouch is held", function()
			expect(MoveState.fallVelocity(airborne(true), -10, 0.1)).toBeCloseTo(-45)
		end)

		it("leaves the rise of a jump alone", function()
			expect(MoveState.fallVelocity(airborne(true), 30, 0.1)).toBe(30)
		end)

		it("does nothing without crouch", function()
			expect(MoveState.fallVelocity(airborne(false), -10, 0.1)).toBe(-10)
		end)

		it("does nothing on the ground", function()
			local s = MoveState.new()
			MoveState.step(s, on({ moving = true, crouch = true }), 0)
			expect(MoveState.fallVelocity(s, -10, 0.1)).toBe(-10)
		end)

		it("stops adding speed at the limit", function()
			expect(MoveState.fallVelocity(airborne(true), -105, 0.1)).toBe(-110)
		end)

		it("does not slow a faster fall", function()
			expect(MoveState.fallVelocity(airborne(true), -200, 0.1)).toBe(-200)
		end)
	end)

	-- Review Focus 4
	it("ends the slide when the player leaves the ground", function()
		local s = MoveState.new()
		sprintThenSlide(s, 0)
		MoveState.step(s, on({ moving = true, sprint = true, grounded = false }), 0.3)
		expect(s.mode).toBe("Air")
		expect(MoveState.speed(s, 0.3)).toBeCloseTo(slideAt(0.2))
		MoveState.step(s, on(sprinting), 0.6)
		expect(s.mode).toBe("Sprint")
		MoveState.step(s, on(sliding), 0.7)
		expect(s.mode).toBe("Slide")
	end)

	it("launches at a given speed and holds it in the air", function()
		local s = MoveState.new()
		MoveState.step(s, on(sprinting), 0)
		MoveState.launch(s, 60, 1)
		expect(s.mode).toBe("Air")
		expect(MoveState.speed(s, 1.3)).toBe(60)
	end)

	it("ramps down smoothly from the dash speed to a sprint", function()
		local s = MoveState.new()
		MoveState.finishDash(s, 16, 120, 1)
		expect(s.mode).toBe("Air")
		expect(MoveState.speed(s, 1)).toBe(120)
		expect(MoveState.speed(s, 1.2)).toBeCloseTo((120 + MoveConfig.SprintSpeed) / 2)
		expect(MoveState.speed(s, 1.45)).toBe(MoveConfig.SprintSpeed)
		expect(MoveState.speed(s, 2)).toBe(MoveConfig.SprintSpeed)
	end)

	it("ramps down to a faster speed if the dash started with one", function()
		local s = MoveState.new()
		MoveState.finishDash(s, 56, 120, 1)
		expect(MoveState.speed(s, 1.45)).toBe(56)
	end)

	it("carries on from the ramp when landing partway through", function()
		local s = MoveState.new()
		MoveState.finishDash(s, 16, 120, 1)
		MoveState.step(s, on(sprinting), 1.2)
		expect(s.mode).toBe("Sprint")
		expect(MoveState.speed(s, 1.2)).toBeCloseTo((120 + MoveConfig.SprintSpeed) / 2)
		expect(MoveState.speed(s, 1.8)).toBe(MoveConfig.SprintSpeed)
	end)

	it("does not bring the ramp back on the next jump", function()
		local s = MoveState.new()
		MoveState.finishDash(s, 16, 120, 1)
		MoveState.step(s, on(sprinting), 1.15)
		MoveState.step(s, on({ moving = true, sprint = true, jump = true, grounded = false }), 1.2)
		expect(s.mode).toBe("Air")
		expect(MoveState.speed(s, 1.25)).toBeCloseTo(MoveState.speed(s, 1.2))
	end)

	-- Review Focus 5
	it("does not slide from crouch held before sprinting", function()
		local s = MoveState.new()
		MoveState.step(s, on({ moving = true, crouch = true }), 0)
		MoveState.step(s, on(sliding), 1)
		expect(s.mode).toBe("Crouch")
	end)
end)

describe("MoveState.hardLanding", function()
	it("is soft for an ordinary or chain jump and hard for a fast fall", function()
		expect(MoveState.hardLanding(42)).toBe(false)
		expect(MoveState.hardLanding(49)).toBe(false)
		expect(MoveState.hardLanding(60)).toBe(true)
		expect(MoveState.hardLanding(110)).toBe(true)
	end)
end)

describe("MoveState.stepTravel", function()
	it("steps each time the feet cover a stride", function()
		local travel, stepped = MoveState.stepTravel(0, 8, "Sprint")
		expect(stepped).toBe(false)
		travel, stepped = MoveState.stepTravel(travel, 2, "Sprint")
		expect(stepped).toBe(true)
		expect(travel).toBeCloseTo(1, 0.001)
	end)

	it("stays silent off the feet and while crouched", function()
		for _, mode in { "Air", "Slide", "Crouch", "Dash" } do
			local travel, stepped = MoveState.stepTravel(8.5, 5, mode)
			expect(stepped).toBe(false)
			expect(travel).toBe(8.5)
		end
	end)
end)
