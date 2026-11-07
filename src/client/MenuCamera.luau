-- Moves the centre of the view left while a panel is open, so the character stays in view beside it.
-- Roblox has no off-centre lens, but a camera CFrame can be sheared, and that does the same job:
-- the picture slides across the screen with no change in perspective, so nothing looks stretched.
-- The shear goes in the bottom row because Roblox turns the CFrame into a view by flipping its
-- rotation over. In the top row it tilts the picture with depth instead, which reads as a skew.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local PanelMotion = require(ReplicatedStorage:WaitForChild("Guns"):WaitForChild("Hud"):WaitForChild("PanelMotion"))

local MOST_BLOOM = 1.2

local real: CFrame? = nil -- the camera before shearing

-- Lives on the camera because the Outpost's lighting clears blur out of Lighting.
local blur = Instance.new("BlurEffect")
blur.Name = "OutpostMenuBlur"
blur.Enabled = false

local bloom = Instance.new("BloomEffect")
bloom.Name = "OutpostMenuBloom"
bloom.Size = 32
bloom.Threshold = 0.75
bloom.Enabled = false
local panel: any = nil -- the view moves exactly as far as this has

local MenuCamera = {}

function MenuCamera.follow(menuPanel: any)
	panel = menuPanel
end

-- Everything that reads the camera, Roblox's controls and camera included, needs the true one,
-- so it goes back at the very start of each frame.
RunService:BindToRenderStep("OutpostMenuCameraRestore", Enum.RenderPriority.First.Value, function()
	if real then
		Workspace.CurrentCamera.CFrame = real
		real = nil
	end
end)

-- Runs after the panel steps, so the two land on every frame together, and after the guns' recoil,
-- so nothing else writes to the camera once it's sheared.
RunService:BindToRenderStep("OutpostMenuCamera", Enum.RenderPriority.Camera.Value + 2, function()
	local amount = if panel then panel.share else 0
	local travel = if panel then panel.travel else 0
	local shake = if panel then panel.shake else { x = 0, y = 0, lean = 0 }
	blur.Parent = Workspace.CurrentCamera
	blur.Size = PanelMotion.viewBlur(travel)
	blur.Enabled = travel ~= 0
	bloom.Parent = Workspace.CurrentCamera
	bloom.Intensity = PanelMotion.glow(travel) * MOST_BLOOM
	bloom.Enabled = travel ~= 0
	if amount < 0.001 and shake.x == 0 then
		return
	end
	local camera = Workspace.CurrentCamera
	local view = camera.ViewportSize
	local shift = PanelMotion.viewShift(camera.FieldOfView, view.X / view.Y) * amount
	real = camera.CFrame
	-- The lean comes first, so the picture tips around the character rather than the screen's centre.
	local lean = CFrame.Angles(0, 0, shake.lean - PanelMotion.viewLean(travel))
	camera.CFrame = camera.CFrame * lean * CFrame.new(0, 0, 0, 1, 0, 0, 0, 1, 0, shift + shake.x, shake.y, 1)
end)

return MenuCamera
