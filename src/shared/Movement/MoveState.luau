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
	carryFade: number,
	airSince: number,
	chained: boolean,
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
		carryFade = MoveConfig.CarryFade,
		airSince = -math.huge,
		chained = false,
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
	local alpha = (now - state.carryFrom) / state.carryFade
	if alpha < 1 then
		return lerp(state.carrySpeed, base, alpha)
	end
	return base
end

function MoveState.jumpHeight(state: State): number
	return if state.chained then MoveConfig.ChainJumpHeight else MoveConfig.JumpHeight
end

-- Holding crouch while falling pulls the player down. A jump's rise is left
-- alone, so a slide jump with crouch still held reaches full height first.
function MoveState.fallVelocity(state: State, velocityY: number, dt: number): number
	if state.mode ~= "Air" or not state.crouchHeld or velocityY >= 0 then
		return velocityY
	end
	if velocityY <= -MoveConfig.FastFallMaxSpeed then
		return velocityY
	end
	return math.max(velocityY - MoveConfig.FastFallAcceleration * dt, -MoveConfig.FastFallMaxSpeed)
end

function MoveState.step(state: State, input: Input, now: number)
	local previous = state.mode
	local current = MoveState.speed(state, now)
	local pressed = input.crouch and not state.crouchHeld
	state.crouchHeld = input.crouch

	if previous == "Air" and now - state.airSince < MoveConfig.MinAirTime then
		return
	end

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
			local slideJump = previous == "Slide" and input.jump
			local jumpBoost = if state.chained then MoveConfig.ChainJumpBoost else MoveConfig.SlideJumpBoost
			local boost = if slideJump then jumpBoost else 0
			state.chained = slideJump and state.chained
			state.carrySpeed = current + boost
			state.airSince = now
			state.mode = "Air"
		end
		return
	end

	local wantsSlide = (pressed and previous == "Sprint") or (input.crouch and previous == "Air")
	if wantsSlide and input.sprint and input.moving and now >= state.nextSlide then
		state.mode = "Slide"
		state.slideStart = now
		state.chained = previous == "Air"
		return
	end

	if previous == "Slide" or previous == "Air" then
		state.carrySpeed = current
		state.carryFrom = now
		state.carryFade = if previous == "Air" then MoveConfig.LandFade else MoveConfig.CarryFade
	end
	state.chained = false
	if input.crouch then
		state.mode = "Crouch"
	elseif input.sprint and input.moving then
		state.mode = "Sprint"
	else
		state.mode = "Walk"
	end
end

return MoveState
