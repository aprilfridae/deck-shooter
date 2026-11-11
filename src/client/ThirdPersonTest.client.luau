-- A test view: P in the test room pulls the camera back behind you so you can watch your own body move.
-- River asked for it to check the third-person animations (2026-11-11), since the areas that use the soldier
-- body are first person. It is only a view: the game still runs as first person underneath (mouse look, guns,
-- movement), so shots still come from your head and the crosshair no longer marks where they land.
-- Sets the player's ThirdPersonTest attribute, which Guns.client.luau (hides the first-person gun and arms)
-- and RemotePoses.client.luau (shows the gun in the body's hands) read.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Zones = require(ReplicatedStorage:WaitForChild("Guns"):WaitForChild("Zones"))

local KEY = Enum.KeyCode.P
local BACK = CFrame.new(1.5, 1, 13) -- right, up and back from the first-person camera
local ATTRIBUTE = "ThirdPersonTest"

local player = Players.LocalPlayer

local function set(on: boolean)
	player:SetAttribute(ATTRIBUTE, if on then true else nil)
end

UserInputService.InputBegan:Connect(function(input: InputObject, typing: boolean)
	if typing or input.KeyCode ~= KEY then
		return
	end
	set(Zones.of(player) == Zones.TestRoom and not player:GetAttribute(ATTRIBUTE))
end)

player:GetAttributeChangedSignal("Zone"):Connect(function()
	if Zones.of(player) ~= Zones.TestRoom then
		set(false)
	end
end)

-- After everything else has placed and used the camera this frame.
RunService:BindToRenderStep("ThirdPersonTest", Enum.RenderPriority.Last.Value + 10, function()
	if not player:GetAttribute(ATTRIBUTE) then
		return
	end
	local camera = workspace.CurrentCamera
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not camera or not character or not humanoid or humanoid.Health <= 0 or camera.CameraType ~= Enum.CameraType.Custom then
		return
	end
	camera.CFrame *= BACK
	-- First person hides your own body; show it again.
	for _, part in character:GetDescendants() do
		if part:IsA("BasePart") or part:IsA("Decal") then
			part.LocalTransparencyModifier = 0
		end
	end
end)
