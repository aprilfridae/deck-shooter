-- Spray recoil. Every spray follows the gun's fixed pattern, so it can be learned.
-- Bullets land on the pattern; the camera only moves part of the way there, so the
-- aim has to be pulled down further than the camera appears to rise.
-- The camera keeps whatever it is given, so only the change each frame is applied to it.
local SETTLE_DELAY = 0.12
local KICK_EASE = 30

local Recoil = {
	VIEW_SHARE = 0.5,
}

local active: any = nil -- the gun the current spray belongs to
local spray = 0 -- shots into the pattern; falls back after firing stops
local viewPitch, viewYaw = 0, 0
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

local function patternNow(): (number, number)
	if not active then
		return 0, 0
	end
	local up, side = Recoil.sample(active.pattern, spray)
	return math.rad(up), math.rad(side)
end

-- How far from the camera's aim the next bullet goes, in radians. Call before kick.
function Recoil.aimOffset(gun: any): (number, number)
	if gun ~= active then
		active = gun
		spray = 0
	end
	local pitch, yaw = patternNow()
	return pitch - viewPitch, yaw - viewYaw
end

function Recoil.kick()
	spray += 1
	sinceKick = 0
end

-- Returns how far to turn the camera this frame, in radians.
function Recoil.advance(dt: number): (number, number)
	sinceKick += dt
	if sinceKick > SETTLE_DELAY and active then
		spray = math.max(spray - dt * active.recovery, 0)
	end
	local pitch, yaw = patternNow()
	local blend = 1 - math.exp(-dt * KICK_EASE)
	local pitchStep = (pitch * Recoil.VIEW_SHARE - viewPitch) * blend
	local yawStep = (yaw * Recoil.VIEW_SHARE - viewYaw) * blend
	viewPitch += pitchStep
	viewYaw += yawStep
	return pitchStep, yawStep
end

function Recoil.reset()
	active = nil
	spray = 0
	viewPitch, viewYaw = 0, 0
	sinceKick = math.huge
end

return Recoil
