-- Smooths the first-person camera's position between physics steps.
-- Roblox moves your character in fixed physics steps, 240 a second, and draws it wherever the last step left
-- it. At a frame rate that 240 doesn't divide by (144, 160, 165...) some frames get one step and some two, so
-- the body, and the camera on it, moves in uneven jumps: big, small, big, small. Measured in River's game on
-- 2026-11-10 at about 160 frames a second: steps of 0.25 and 0.125 studs by turns, where 0.2 was even. It reads
-- as lag or stutter even with a high frame rate.
-- This keeps its own idea of where the camera's body is, moved every frame by the body's velocity times the
-- frame's real length, and pulled gently back to the true position so it can't drift. The camera is shifted by
-- the difference. The shift is a fraction of a stud; shots still come from close enough to the true spot.
local Players = game:GetService("Players")

local PULL = 10 -- how fast the smoothed position is drawn back to the true one, as an ease rate per second
local SNAP = 2 -- studs apart at which it gives up and jumps (a respawn, a teleport, a dash)

local CameraSmooth = {}

local player = Players.LocalPlayer
local smooth: Vector3? = nil
local lastRoot: BasePart? = nil

-- Call once a frame, after Roblox's camera has been placed and before anything is drawn from the camera.
function CameraSmooth.apply(dt: number, camera: Camera)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid or humanoid.Health <= 0 or camera.CameraType ~= Enum.CameraType.Custom or camera.CameraSubject ~= humanoid then
		smooth, lastRoot = nil, nil
		return
	end
	local actual = root.Position
	if not smooth or lastRoot ~= root or (smooth - actual).Magnitude > SNAP then
		smooth, lastRoot = actual, root
		return
	end
	local moved = smooth + root.AssemblyLinearVelocity * dt
	moved = moved:Lerp(actual, 1 - math.exp(-dt * PULL))
	smooth = moved
	camera.CFrame += moved - actual
end

return CameraSmooth
