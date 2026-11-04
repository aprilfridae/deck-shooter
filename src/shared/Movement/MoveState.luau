-- The movement state machine. Pure: the caller supplies input and the time.
local MoveConfig = require("./MoveConfig")

export type Mode = "Walk" | "Sprint" | "Crouch" | "Slide" | "Air" | "Climb"
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
	dashFadeFrom: number,
	dashFadeAt: number,
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
		dashFadeFrom = 0,
		dashFadeAt = -math.huge,
	}
end

function MoveState.speed(state: State, now: number): number
	if state.mode == "Slide" then
		local alpha = math.min((now - state.slideStart) / MoveConfig.SlideFadeTime, 1)
		return lerp(MoveConfig.SlideStartSpeed, MoveConfig.SprintSpeed, alpha)
	elseif state.mode == "Air" then
		local alpha = (now - state.dashFadeAt) / MoveConfig.DashFadeTime
		return if alpha < 1 then lerp(state.dashFadeFrom, state.carrySpeed, alpha) else state.carrySpeed
	elseif state.mode == "Climb" then
		return 0
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

-- Launches off an edge without losing speed.
function MoveState.parry(state: State, now: number)
	local current = math.max(MoveState.speed(state, now), MoveConfig.SprintSpeed)
	state.carrySpeed = math.min(current + MoveConfig.ParryBoost, MoveConfig.ParryMaxSpeed)
	state.mode = "Air"
	state.airSince = now
	state.chained = false
	state.dashFadeAt = -math.huge
end

-- Thrown into the air at this speed, for shoves from abilities.
function MoveState.launch(state: State, speed: number, now: number)
	state.carrySpeed = speed
	state.mode = "Air"
	state.airSince = now
	state.chained = false
	state.dashFadeAt = -math.huge
end

-- A dash leaves at its own speed, then ramps down. It never ends slower than it started.
function MoveState.finishDash(state: State, entrySpeed: number, dashSpeed: number, now: number)
	local settled = math.max(entrySpeed, MoveConfig.SprintSpeed)
	MoveState.launch(state, settled, now)
	state.dashFadeFrom = math.max(dashSpeed, settled)
	state.dashFadeAt = now
end

function MoveState.startClimb(state: State)
	state.mode = "Climb"
	state.chained = false
end

function MoveState.finishClimb(state: State, now: number)
	state.mode = "Air"
	state.carrySpeed = MoveConfig.SprintSpeed
	state.airSince = now
	state.dashFadeAt = -math.huge
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

	if previous == "Climb" or (previous == "Air" and now - state.airSince < MoveConfig.MinAirTime) then
		return
	end

	if previous == "Slide" then
		if input.crouch and input.grounded and not input.jump then
			return
		end
		state.nextSlide = now + MoveConfig.SlideCooldown
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
			state.dashFadeAt = -math.huge
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
