-- The movement state machine. Pure: the caller supplies input and the time.
local MoveConfig = require("./MoveConfig")

export type Mode = "Walk" | "Sprint" | "Crouch" | "Slide" | "Air" | "Dash"
export type Input = {
	moving: boolean,
	sprint: boolean,
	crouch: boolean,
	jump: boolean,
	grounded: boolean,
	cards: boolean?, -- the cards are in hand
}
export type State = {
	mode: Mode,
	cards: boolean,
	crouchHeld: boolean,
	slideStart: number,
	nextSlide: number,
	slideLeftAt: number,
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
		cards = false,
		crouchHeld = false,
		slideStart = -math.huge,
		nextSlide = -math.huge,
		slideLeftAt = -math.huge,
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
	-- Holding the cards makes you faster on the ground (River, 2026-11-11). The air keeps whatever speed you left
	-- the ground with, so it carries the bonus without getting it twice.
	local cards = if state.cards then MoveConfig.CardSpeed else 1
	if state.mode == "Slide" then
		-- The boost builds over SlideRampTime instead of arriving at once (River: "come on a little slower", like
		-- Call of Duty), then fades as before. The speed is whichever of the two lines is lower.
		local since = now - state.slideStart
		local alpha = math.min(since / MoveConfig.SlideFadeTime, 1)
		local fade = lerp(MoveConfig.SlideStartSpeed, MoveConfig.SprintSpeed, alpha)
		local ramp = lerp(MoveConfig.SprintSpeed, MoveConfig.SlideStartSpeed, math.clamp(since / MoveConfig.SlideRampTime, 0, 1))
		return math.min(fade, ramp) * cards
	elseif state.mode == "Air" then
		-- Let go fast at first and then slowly, so the launch reads as a launch and its tail hangs on.
		local alpha = (now - state.dashFadeAt) / MoveConfig.DashFadeTime
		return if alpha < 1 then lerp(state.dashFadeFrom, state.carrySpeed, 1 - (1 - alpha) ^ 3) else state.carrySpeed
	elseif state.mode == "Dash" then
		return 0
	end
	local base = BASE_SPEED[state.mode] * cards
	local alpha = (now - state.carryFrom) / state.carryFade
	if alpha < 1 then
		return lerp(state.carrySpeed, base, alpha)
	end
	return base
end

function MoveState.jumpHeight(_state: State): number
	-- Every jump is the same height. A chain jump used to go higher (8 against 6); River had that taken out.
	return MoveConfig.JumpHeight
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

-- Kicks off a wall in the air, keeping speed and adding a little.
function MoveState.wallJump(state: State, now: number)
	local current = math.max(MoveState.speed(state, now), MoveConfig.SprintSpeed)
	state.carrySpeed = math.max(current, math.min(current + MoveConfig.WallJumpBoost, MoveConfig.ParryMaxSpeed))
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

-- A dash carries the player along a set path. The rules stand still until finishDash.
function MoveState.startDash(state: State)
	state.mode = "Dash"
	state.chained = false
end

-- A landing is hard after a fast fall or a long drop, and soft after an ordinary jump.
function MoveState.hardLanding(fallSpeed: number): boolean
	return fallSpeed >= MoveConfig.HardLandSpeed
end

-- Adds the ground just covered and says whether a footstep lands.
function MoveState.stepTravel(travel: number, distance: number, mode: Mode): (number, boolean)
	if mode ~= "Walk" and mode ~= "Sprint" then
		return travel, false
	end
	travel += distance
	if travel >= MoveConfig.StrideStuds then
		return travel - MoveConfig.StrideStuds, true
	end
	return travel, false
end

function MoveState.step(state: State, input: Input, now: number)
	local previous = state.mode
	local current = MoveState.speed(state, now)
	state.cards = input.cards == true
	local pressed = input.crouch and not state.crouchHeld
	state.crouchHeld = input.crouch

	if previous == "Dash" or (previous == "Air" and now - state.airSince < MoveConfig.MinAirTime) then
		return
	end

	if previous == "Slide" then
		if input.crouch and input.grounded and not input.jump then
			return
		end
		state.nextSlide = now + MoveConfig.SlideCooldown
		state.slideLeftAt = now
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
		-- A slide that only lost the ground for a moment (a bump, a lip) carries on slowing from where it was.
		-- Starting it again from full speed made the speed lurch each time, which felt like a stutter.
		local blip = previous == "Air" and now - state.slideLeftAt < MoveConfig.SlideBlip
		if not blip then
			state.slideStart = now
			state.chained = previous == "Air"
		end
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
