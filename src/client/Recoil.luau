-- Spray recoil. Every spray follows the gun's fixed pattern, so it can be learned.
-- Bullets land on the pattern. The camera only rises part of the way with each shot and
-- falls straight back after firing stops, so sideways swing shows in the bullets alone.
-- The camera keeps whatever it is given, so only the change each frame is applied to it.
local SETTLE_DELAY = 0.12
local KICK_EASE = 30
local FALL_EASE = 5

local Recoil = {
	VIEW_SHARE = 0.5,
}

local active: any = nil -- the gun the current spray belongs to
local spray = 0 -- shots into the pattern; falls back after firing stops
local viewTarget = 0
local viewPitch = 0
local sinceKick = math.huge

-- Where the pattern is after this many shots, in degrees up and sideways.
function Recoil.sample(pattern: { { number } }, shots: number): (number, number)
	local fromShot, fromUp, fromSide = 0, 0, 0
	for _, point in pattern do
		if shots <= point[1] then
			local blend = (shots - fromShot) / (point[1] - fromShot)
			return fromUp + (point[2] - fromUp) * blend, fromSide + (point[3] - fromSide) * blend
		end
		fromShot, fromUp, fromSide = point[1], point[2], point[3]
	end
	return fromUp, fromSide
end

-- How far from the camera's aim the next bullet goes, in radians. Call before kick.
function Recoil.aimOffset(gun: any): (number, number)
	if gun ~= active then
		active = gun
		spray = 0
	end
	local up, side = Recoil.sample(active.pattern, spray)
	return math.rad(up) - viewPitch, math.rad(side)
end

function Recoil.kick()
	local before = Recoil.sample(active.pattern, spray)
	spray += 1
	local after = Recoil.sample(active.pattern, spray)
	viewTarget += math.rad(after - before) * Recoil.VIEW_SHARE
	sinceKick = 0
end

-- Returns how far to tilt the camera up this frame, in radians.
function Recoil.advance(dt: number): number
	sinceKick += dt
	if sinceKick > SETTLE_DELAY and active then
		spray = math.max(spray - dt * active.recovery, 0)
		viewTarget *= math.exp(-dt * FALL_EASE)
	end
	local step = (viewTarget - viewPitch) * (1 - math.exp(-dt * KICK_EASE))
	viewPitch += step
	return step
end

function Recoil.reset()
	active = nil
	spray = 0
	viewTarget = 0
	viewPitch = 0
	sinceKick = math.huge
end

return Recoil
