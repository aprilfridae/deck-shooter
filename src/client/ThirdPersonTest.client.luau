-- A test view: in the test room, P steps through three views of your own body: first person (off), from
-- behind, and from the front looking back at you.
-- River asked for it to check the third-person animations (2026-11-11), since the areas that use the soldier
-- body are first person. It is only a view: the game still runs as first person underneath (mouse look, guns,
-- movement), so shots still come from your head and the crosshair no longer marks where they land.
-- Sets the player's ThirdPersonTest attribute, which Guns.client.luau (hides the first-person gun and arms)
-- and RemotePoses.client.luau (shows the gun in the body's hands) read, and ThirdPersonView ("Back" or
-- "Front") so the view in use can be seen from outside the script.
--
-- The front view used to be its own key, O, and never worked for River through three fixes; what went wrong was
-- never pinned down (O is also one of Roblox's camera zoom keys). P is known to work, so it does both now.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Zones = require(ReplicatedStorage:WaitForChild("Guns"):WaitForChild("Zones"))

local KEY = Enum.KeyCode.P
local ATTRIBUTE = "ThirdPersonTest"
local VIEW_ATTRIBUTE = "ThirdPersonView"
local DISTANCE = 13
-- Each view: where the camera goes from the first-person camera, and how it is turned once there.
local VIEWS = {
	Back = { offset = Vector3.new(1.5, 1, DISTANCE), turn = CFrame.identity },
	Front = { offset = Vector3.new(-1.5, 1, -DISTANCE), turn = CFrame.Angles(0, math.pi, 0) },
}
local AFTER = { Back = "Front" } -- what P goes to from each view; from first person it goes to Back
local WALL_GAP = 0.6 -- the camera stops this far short of anything in its way

local player = Players.LocalPlayer

local function set(view: string?)
	player:SetAttribute(ATTRIBUTE, if view then true else nil)
	player:SetAttribute(VIEW_ATTRIBUTE, view)
end

-- Read every frame, the way the game's other test keys are.
local wasDown = false
RunService.RenderStepped:Connect(function()
	local down = UserInputService:IsKeyDown(KEY) and UserInputService:GetFocusedTextBox() == nil
	if down and not wasDown then
		local current = player:GetAttribute(VIEW_ATTRIBUTE)
		if Zones.of(player) ~= Zones.TestRoom then
			set(nil)
		elseif current == nil then
			set("Back")
		else
			set(AFTER[current])
		end
	end
	wasDown = down
end)

player:GetAttributeChangedSignal("Zone"):Connect(function()
	if Zones.of(player) ~= Zones.TestRoom then
		set(nil)
	end
end)

-- Roblox's first-person camera starts each frame from the way the camera was left facing. So the test view is
-- undone before the next frame starts: the camera's real place is kept here and put back first thing.
local trueView: CFrame? = nil
RunService:BindToRenderStep("ThirdPersonTestRestore", Enum.RenderPriority.First.Value - 1, function()
	if trueView then
		local camera = workspace.CurrentCamera
		if camera and camera.CameraType == Enum.CameraType.Custom then
			camera.CFrame = trueView
		end
		trueView = nil
	end
end)

local wallParams = RaycastParams.new()
wallParams.FilterType = Enum.RaycastFilterType.Exclude

-- After everything else has placed and used the camera this frame.
RunService:BindToRenderStep("ThirdPersonTest", Enum.RenderPriority.Last.Value + 10, function()
	local view = VIEWS[player:GetAttribute(VIEW_ATTRIBUTE) or ""]
	if not view then
		return
	end
	local camera = workspace.CurrentCamera
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not camera or not character or not humanoid or humanoid.Health <= 0 or camera.CameraType ~= Enum.CameraType.Custom then
		return
	end
	local real = camera.CFrame
	trueView = real
	-- Pulled in if a wall is in the way, so the camera never ends up behind one.
	local reach = real:VectorToWorldSpace(view.offset)
	wallParams.FilterDescendantsInstances = { character }
	local wall = workspace:Raycast(real.Position, reach, wallParams)
	if wall then
		reach = reach.Unit * math.max(wall.Distance - WALL_GAP, 1)
	end
	camera.CFrame = (real + reach) * view.turn
	-- First person hides your own body; show it again.
	for _, part in character:GetDescendants() do
		if part:IsA("BasePart") or part:IsA("Decal") then
			part.LocalTransparencyModifier = 0
		end
	end
end)
