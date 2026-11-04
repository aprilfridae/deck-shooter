-- Camera kick from firing. Each shot lifts the aim, and it eases back after firing stops.
-- The camera keeps whatever it is given, so only the change each frame is applied to it.
local MAX_PITCH = math.rad(12)
local SIDE_DRIFT = 0.3 -- share of the kick that can go left or right
local SETTLE_DELAY = 0.12
local KICK_EASE = 30
local RETURN_EASE = 6

local targetPitch, targetYaw = 0, 0
local currentPitch, currentYaw = 0, 0
local sinceKick = math.huge

local Recoil = {}

function Recoil.kick(degrees: number)
	targetPitch = math.min(targetPitch + math.rad(degrees), MAX_PITCH)
	targetYaw += math.rad(degrees) * SIDE_DRIFT * (2 * math.random() - 1)
	sinceKick = 0
end

-- Returns how far to turn the camera this frame, in radians.
function Recoil.advance(dt: number): (number, number)
	sinceKick += dt
	if sinceKick > SETTLE_DELAY then
		local settle = math.exp(-dt * RETURN_EASE)
		targetPitch *= settle
		targetYaw *= settle
	end
	local blend = 1 - math.exp(-dt * KICK_EASE)
	local pitchStep = (targetPitch - currentPitch) * blend
	local yawStep = (targetYaw - currentYaw) * blend
	currentPitch += pitchStep
	currentYaw += yawStep
	return pitchStep, yawStep
end

function Recoil.reset()
	targetPitch, targetYaw = 0, 0
	currentPitch, currentYaw = 0, 0
end

return Recoil
