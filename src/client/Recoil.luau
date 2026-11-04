-- Camera kick from firing. Each shot lifts the aim, and it eases back after firing stops.
local MAX_PITCH = math.rad(12)
local SIDE_DRIFT = 0.3 -- share of the kick that can go left or right
local SETTLE_DELAY = 0.12
local KICK_EASE = 30
local RETURN_EASE = 6

local target = Vector2.zero -- x is yaw, y is pitch, in radians
local current = Vector2.zero
local sinceKick = math.huge

local Recoil = {}

function Recoil.kick(degrees: number)
	local pitch = math.min(target.Y + math.rad(degrees), MAX_PITCH)
	local yaw = target.X + math.rad(degrees) * SIDE_DRIFT * (2 * math.random() - 1)
	target = Vector2.new(yaw, pitch)
	sinceKick = 0
end

function Recoil.update(dt: number, camera: Camera)
	sinceKick += dt
	if sinceKick > SETTLE_DELAY then
		target *= math.exp(-dt * RETURN_EASE)
	end
	current = current:Lerp(target, 1 - math.exp(-dt * KICK_EASE))
	camera.CFrame *= CFrame.Angles(current.Y, current.X, 0)
end

function Recoil.reset()
	target = Vector2.zero
	current = Vector2.zero
end

return Recoil
