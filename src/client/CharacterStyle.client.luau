-- Gives every player's body the same look as the first-person arms.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Guns = ReplicatedStorage:WaitForChild("Guns")
local BodyStyle = require(Guns:WaitForChild("BodyStyle"))
local Zones = require(Guns:WaitForChild("Zones"))

local localPlayer = Players.LocalPlayer

local function paint(part: Instance)
	if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
		part.Color = BodyStyle.skin
		part.Material = BodyStyle.material
	end
end

local function onCharacter(player: Player, character: Model)
	for _, child in character:GetChildren() do
		paint(child)
	end
	character.ChildAdded:Connect(paint)

	local outline = Instance.new("Highlight")
	outline.Name = "BodyOutline"
	outline.OutlineColor = BodyStyle.glow
	outline.FillColor = BodyStyle.glow
	outline.FillTransparency = BodyStyle.glowFill
	outline.OutlineTransparency = BodyStyle.glowEdge
	outline.DepthMode = BodyStyle.depthMode
	outline.Parent = character

	-- Your own body is hidden in first person, so its outline must be too.
	if player == localPlayer then
		local function update()
			outline.Enabled = Zones.autoRotates(Zones.of(player))
		end
		player:GetAttributeChangedSignal("Zone"):Connect(update)
		update()
	end
end

local function onPlayer(player: Player)
	player.CharacterAdded:Connect(function(character)
		onCharacter(player, character)
	end)
	if player.Character then
		task.spawn(onCharacter, player, player.Character)
	end
end

Players.PlayerAdded:Connect(onPlayer)
for _, player in Players:GetPlayers() do
	task.spawn(onPlayer, player)
end
