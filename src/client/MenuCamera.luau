-- Moves the centre of the view left while a panel is open, so the character stays in view beside it.
-- Roblox has no off-centre lens, but a camera CFrame can be sheared, and that does the same job:
-- the picture slides across the screen with no change in perspective, so nothing looks stretched.
-- The shear goes in the bottom row because Roblox turns the CFrame into a view by flipping its
-- rotation over. In the top row it tilts the picture with depth instead, which reads as a skew.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local PanelMotion = require(ReplicatedStorage:WaitForChild("Guns"):WaitForChild("Hud"):WaitForChild("PanelMotion"))

local EASE = 6 -- higher is quicker

local open = false
local amount = 0 -- 0 is the normal view, 1 is fully moved
local real: CFrame? = nil -- the camera before shearing

local MenuCamera = {}

function MenuCamera.setOpen(isOpen: boolean)
	open = isOpen
end

-- Everything that reads the camera, Roblox's controls and camera included, needs the true one,
-- so it goes back at the very start of each frame.
RunService:BindToRenderStep("OutpostMenuCameraRestore", Enum.RenderPriority.First.Value, function()
	if real then
		Workspace.CurrentCamera.CFrame = real
		real = nil
	end
end)

RunService:BindToRenderStep("OutpostMenuCamera", Enum.RenderPriority.Camera.Value + 1, function(dt)
	amount += ((if open then 1 else 0) - amount) * (1 - math.exp(-dt * EASE))
	if amount < 0.001 then
		return
	end
	local camera = Workspace.CurrentCamera
	local view = camera.ViewportSize
	local shift = PanelMotion.viewShift(camera.FieldOfView, view.X / view.Y) * amount
	real = camera.CFrame
	camera.CFrame = camera.CFrame * CFrame.new(0, 0, 0, 1, 0, 0, 0, 1, 0, shift, 0, 1)
end)

return MenuCamera
