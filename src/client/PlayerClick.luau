-- Left clicking a player in the Outpost opens their profile, within 40 studs.
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local MenuCamera = require(script.Parent.MenuCamera)

local REACH = 40 -- studs from the player to who they click
local RAY_LENGTH = 500 -- studs

local PlayerClick = {}

local function rootOf(player: Player): BasePart?
	local character = player.Character
	return if character then character:FindFirstChild("HumanoidRootPart") :: BasePart? else nil
end

local function playerAt(x: number, y: number): Player?
	local ray = MenuCamera.ray(x, y)
	local hit = Workspace:Raycast(ray.Origin, ray.Direction * RAY_LENGTH)
	local part: Instance? = hit and hit.Instance
	while part and part ~= Workspace do
		local player = Players:GetPlayerFromCharacter(part)
		if player then
			return player
		end
		part = part.Parent
	end
	return nil
end

-- allowed says whether clicks count right now.
function PlayerClick.listen(allowed: () -> boolean, onPlayer: (Player) -> ())
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed or input.UserInputType ~= Enum.UserInputType.MouseButton1 or not allowed() then
			return
		end
		local location = UserInputService:GetMouseLocation()
		if UserInputService.MouseBehavior == Enum.MouseBehavior.LockCenter then
			location = Workspace.CurrentCamera.ViewportSize / 2
		end
		local player = playerAt(location.X, location.Y)
		local mine = rootOf(Players.LocalPlayer)
		local theirs = player and rootOf(player)
		if player and mine and theirs and (mine.Position - theirs.Position).Magnitude <= REACH then
			onPlayer(player)
		end
	end)
end

return PlayerClick
