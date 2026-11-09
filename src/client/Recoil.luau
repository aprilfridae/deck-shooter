-- Recoil that barely moves you, like Call of Duty's. Bullets always go where the crosshair is.
-- Each shot nudges the view up by the gun's kick, plus a hair either side, and it settles straight back.
-- The camera keeps whatever it is given, so only the change each frame is applied to it.
local KICK_EASE = 40 -- how fast the view reaches the kick
local SETTLE_EASE = 9 -- how fast it comes back down
local SIDE_SHARE = 0.3 -- the most a shot drifts sideways, as a share of its kick

local Recoil = {}

local active: any = nil
local targetPitch, targetYaw = 0, 0
local viewPitch, viewYaw = 0, 0

-- How far from the crosshair the next bullet goes, in radians. Always none.
function Recoil.aimOffset(gun: any): (number, number)
	active = gun
	return 0, 0
end

function Recoil.kick(side: number?)
	local kick = math.rad(if active and active.kick then active.kick else 0)
	local drift = if side then side else math.random() * 2 - 1
	targetPitch += kick
	targetYaw += kick * SIDE_SHARE * drift
end

-- Returns how far to turn the camera this frame, in radians.
function Recoil.advance(dt: number): (number, number)
	local settle = math.exp(-dt * SETTLE_EASE)
	targetPitch *= settle
	targetYaw *= settle
	local blend = 1 - math.exp(-dt * KICK_EASE)
	local pitchStep = (targetPitch - viewPitch) * blend
	local yawStep = (targetYaw - viewYaw) * blend
	viewPitch += pitchStep
	viewYaw += yawStep
	return pitchStep, yawStep
end

function Recoil.reset()
	active = nil
	targetPitch, targetYaw = 0, 0
	viewPitch, viewYaw = 0, 0
end

return Recoil
