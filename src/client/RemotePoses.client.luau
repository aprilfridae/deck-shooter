-- Shows other players sliding and crouching, by moving their R15 root joint.
local Players = game:GetService("Players")

local LOWER = CFrame.new(0, -1.5, 0)
local TILT = CFrame.Angles(math.rad(35), 0, 0)
local OFFSETS = {
	Normal = CFrame.identity,
	Crouch = LOWER,
	Slide = LOWER * TILT,
}

local function onCharacter(character: Model)
	local lowerTorso = character:WaitForChild("LowerTorso", 5)
	local joint = lowerTorso and lowerTorso:WaitForChild("Root", 5)
	if not joint or not joint:IsA("Motor6D") then
		return
	end

	local standing = joint.C0
	local function apply()
		local offset = OFFSETS[character:GetAttribute("MovePose")] or CFrame.identity
		joint.C0 = standing * offset
	end
	character:GetAttributeChangedSignal("MovePose"):Connect(apply)
	apply()
end

local function onPlayer(player: Player)
	if player == Players.LocalPlayer then
		return
	end
	player.CharacterAdded:Connect(onCharacter)
	if player.Character then
		task.spawn(onCharacter, player.Character)
	end
end

Players.PlayerAdded:Connect(onPlayer)
for _, player in Players:GetPlayers() do
	task.spawn(onPlayer, player)
end
