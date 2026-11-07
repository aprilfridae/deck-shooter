-- How a card moves while it's held up for inspecting. Angles are in radians.
local CardSpin = {
	ENTER_TIME = 0.5, -- seconds
	LEAVE_TIME = 0.15,
	CLOSE_DELAY = 0.25, -- seconds after opening before a click off the card counts
	PITCH_LIMIT = 0.6,
}

local TURN_PER_PIXEL = 0.008
local SETTLE_RATE = 10 -- higher comes to rest sooner
local ENTER_SCALE = 0.6
local SWAY_YAW = 0.1
local SWAY_PITCH = 0.05
local SWAY_YAW_SPEED = 0.9 -- radians of sway a second
local SWAY_PITCH_SPEED = 0.6
local SHINE_REACH = 0.7 -- how far the card turns for the shine to cross from middle to edge

function CardSpin.drag(yaw: number, pitch: number, dx: number, dy: number): (number, number)
	local limit = CardSpin.PITCH_LIMIT
	return yaw + dx * TURN_PER_PIXEL, math.clamp(pitch + dy * TURN_PER_PIXEL, -limit, limit)
end

-- The nearest angle where a side faces the viewer.
function CardSpin.rest(yaw: number): number
	return math.round(yaw / math.pi) * math.pi
end

function CardSpin.settle(value: number, target: number, dt: number): number
	return target + (value - target) * math.exp(-SETTLE_RATE * dt)
end

function CardSpin.sway(elapsed: number): (number, number)
	return math.sin(elapsed * SWAY_YAW_SPEED) * SWAY_YAW, math.sin(elapsed * SWAY_PITCH_SPEED) * SWAY_PITCH
end

-- The spin still to come and the card's scale as it arrives.
function CardSpin.enter(elapsed: number): (number, number)
	local left = 1 - math.clamp(elapsed / CardSpin.ENTER_TIME, 0, 1)
	local ease = left * left * left
	return ease * 2 * math.pi, 1 - ease * (1 - ENTER_SCALE)
end

function CardSpin.canClose(elapsed: number): boolean
	return elapsed >= CardSpin.CLOSE_DELAY
end

function CardSpin.leave(elapsed: number): number
	return 1 - math.clamp(elapsed / CardSpin.LEAVE_TIME, 0, 1)
end

-- The shine's gradient offset for a card turned this far from resting.
function CardSpin.shine(turned: number): number
	return math.clamp(turned / SHINE_REACH, -1, 1)
end

return CardSpin
