-- Moves the camera right while a panel is open, so the character stays in view beside it.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local PanelMotion = require(ReplicatedStorage:WaitForChild("Guns"):WaitForChild("Hud"):WaitForChild("PanelMotion"))

local EASE = 6 -- higher is quicker
local WALL_GAP = 0.5 -- studs kept between the camera and a wall

local player = Players.LocalPlayer

local open = false
local amount = 0 -- 0 is the normal view, 1 is fully moved

local MenuCamera = {}

function MenuCamera.setOpen(isOpen: boolean)
	open = isOpen
end

RunService:BindToRenderStep("OutpostMenuCamera", Enum.RenderPriority.Camera.Value + 1, function(dt)
	amount += ((if open then 1 else 0) - amount) * (1 - math.exp(-dt * EASE))
	if amount < 0.001 then
		return
	end
	local camera = Workspace.CurrentCamera
	local view = camera.ViewportSize
	local distance = (camera.Focus.Position - camera.CFrame.Position).Magnitude
	local shift = PanelMotion.cameraShift(distance, camera.FieldOfView, view.X / view.Y) * amount

	local ignore = RaycastParams.new()
	ignore.FilterType = Enum.RaycastFilterType.Exclude
	ignore.FilterDescendantsInstances = { player.Character }
	local hit = Workspace:Raycast(camera.CFrame.Position, camera.CFrame.RightVector * (shift + WALL_GAP), ignore)
	if hit then
		shift = math.max(0, hit.Distance - WALL_GAP)
	end
	camera.CFrame *= CFrame.new(shift, 0, 0)
end)

return MenuCamera
