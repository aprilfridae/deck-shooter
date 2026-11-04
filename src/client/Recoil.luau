-- Spray recoil. Every spray follows the gun's fixed pattern, so it can be learned.
-- Bullets land on the pattern. The camera follows part of the way with each shot, then
-- drifts straight back to the start after firing stops instead of retracing the pattern.
-- The camera keeps whatever it is given, so only the change each frame is applied to it.
local SETTLE_DELAY = 0.12
local KICK_EASE = 30
local FALL_EASE = 5

local Recoil = {
	VIEW_SHARE = 0.45, -- the same share as Counter-Strike
}

local active: any = nil -- the gun the current spray belongs to
local spray = 0 -- shots into the pattern; falls back after firing stops
local targetPitch, targetYaw = 0, 0
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

-- How far from the camera's aim the next bullet goes, in radians. Call before kick.
function Recoil.aimOffset(gun: any): (number, number)
	if gun ~= active then
		active = gun
		spray = 0
	end
	local up, side = Recoil.sample(active.pattern, spray)
	return math.rad(up) - viewPitch, math.rad(side) - viewYaw
end

function Recoil.kick()
	local upBefore, sideBefore = Recoil.sample(active.pattern, spray)
	spray += 1
	local upAfter, sideAfter = Recoil.sample(active.pattern, spray)
	targetPitch += math.rad(upAfter - upBefore) * Recoil.VIEW_SHARE
	targetYaw += math.rad(sideAfter - sideBefore) * Recoil.VIEW_SHARE
	sinceKick = 0
end

-- Returns how far to turn the camera this frame, in radians.
function Recoil.advance(dt: number): (number, number)
	sinceKick += dt
	if sinceKick > SETTLE_DELAY and active then
		spray = math.max(spray - dt * active.recovery, 0)
		local fall = math.exp(-dt * FALL_EASE)
		targetPitch *= fall
		targetYaw *= fall
	end
	local blend = 1 - math.exp(-dt * KICK_EASE)
	local pitchStep = (targetPitch - viewPitch) * blend
	local yawStep = (targetYaw - viewYaw) * blend
	viewPitch += pitchStep
	viewYaw += yawStep
	return pitchStep, yawStep
end

function Recoil.reset()
	active = nil
	spray = 0
	targetPitch, targetYaw = 0, 0
	viewPitch, viewYaw = 0, 0
	sinceKick = math.huge
end

return Recoil
