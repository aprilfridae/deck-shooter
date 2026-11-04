-- Shows other players sliding and crouching, by moving their R15 root joint.
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local EASE = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local LOWER = CFrame.new(0, -1.5, 0)
local TILT = CFrame.Angles(math.rad(35), 0, 0)
local OFFSETS = {
	Normal = CFrame.identity,
	Crouch = LOWER,
	Slide = LOWER * TILT,
}

-- R15 rigs use either a Motor6D or an AnimationConstraint for this joint.
local function poseTarget(joint: Instance): (any, string?)
	if joint:IsA("Motor6D") then
		return joint, "C0"
	elseif joint:IsA("AnimationConstraint") and joint.Attachment0 then
		return joint.Attachment0, "CFrame"
	end
	return nil, nil
end

local function onCharacter(character: Model)
	local lowerTorso = character:WaitForChild("LowerTorso", 5)
	local joint = lowerTorso and lowerTorso:WaitForChild("Root", 5)
	local target, property = nil, nil
	if joint then
		target, property = poseTarget(joint)
	end
	if not target or not property then
		return
	end

	local standing = target[property]
	local function apply()
		local offset = OFFSETS[character:GetAttribute("MovePose")] or CFrame.identity
		TweenService:Create(target, EASE, { [property] = standing * offset }):Play()
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
