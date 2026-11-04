-- The movement state machine. Pure: the caller supplies input and the time.
local MoveConfig = require("./MoveConfig")

export type Mode = "Walk" | "Sprint" | "Crouch" | "Slide" | "Air"
export type Input = {
	moving: boolean,
	sprint: boolean,
	crouch: boolean,
	jump: boolean,
	grounded: boolean,
}
export type State = {
	mode: Mode,
	crouchHeld: boolean,
	slideStart: number,
	nextSlide: number,
	carrySpeed: number,
	carryFrom: number,
}

local BASE_SPEED = {
	Walk = MoveConfig.WalkSpeed,
	Sprint = MoveConfig.SprintSpeed,
	Crouch = MoveConfig.CrouchSpeed,
}

local MoveState = {}

local function lerp(from: number, to: number, alpha: number): number
	return from + (to - from) * alpha
end

function MoveState.new(): State
	return {
		mode = "Walk",
		crouchHeld = false,
		slideStart = -math.huge,
		nextSlide = -math.huge,
		carrySpeed = 0,
		carryFrom = -math.huge,
	}
end

function MoveState.speed(state: State, now: number): number
	if state.mode == "Slide" then
		local alpha = math.min((now - state.slideStart) / MoveConfig.SlideDuration, 1)
		return lerp(MoveConfig.SlideStartSpeed, MoveConfig.SprintSpeed, alpha)
	elseif state.mode == "Air" then
		return state.carrySpeed
	end
	local base = BASE_SPEED[state.mode]
	local alpha = (now - state.carryFrom) / MoveConfig.CarryFade
	if alpha < 1 then
		return lerp(state.carrySpeed, base, alpha)
	end
	return base
end

function MoveState.step(state: State, input: Input, now: number)
	local previous = state.mode
	local current = MoveState.speed(state, now)
	local pressed = input.crouch and not state.crouchHeld
	state.crouchHeld = input.crouch

	if previous == "Slide" then
		local slideEnd = state.slideStart + MoveConfig.SlideDuration
		if now >= slideEnd then
			state.nextSlide = slideEnd + MoveConfig.SlideCooldown
		elseif pressed or input.jump or not input.grounded then
			state.nextSlide = now + MoveConfig.SlideCooldown
		else
			return
		end
	end

	if not input.grounded or (previous == "Slide" and input.jump) then
		if previous ~= "Air" then
			state.carrySpeed = current
			state.mode = "Air"
		end
		return
	end

	if pressed and previous == "Sprint" and input.sprint and input.moving and now >= state.nextSlide then
		state.mode = "Slide"
		state.slideStart = now
		return
	end

	if previous == "Slide" or previous == "Air" then
		state.carrySpeed = current
		state.carryFrom = now
	end
	if input.crouch then
		state.mode = "Crouch"
	elseif input.sprint and input.moving then
		state.mode = "Sprint"
	else
		state.mode = "Walk"
	end
end

return MoveState
