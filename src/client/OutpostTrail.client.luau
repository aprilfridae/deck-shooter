-- A glowing trail behind your own character. Outpost only.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Guns = ReplicatedStorage:WaitForChild("Guns")
local Palette = require(Guns:WaitForChild("Palette"))
local Zones = require(Guns:WaitForChild("Zones"))

local TOP = Vector3.new(0, 1.2, 0) -- studs from the character's root
local BOTTOM = Vector3.new(0, -2.2, 0)
local LIFETIME = 0.7 -- seconds
local BRIGHTNESS = 3
local START_FADE = 0.3 -- how see-through the trail is at the character
local TAIL_WIDTH = 0.2 -- of the character's height

local player = Players.LocalPlayer
local trail: Trail? = nil

local function point(root: BasePart, name: string, offset: Vector3): Attachment
	local attachment = Instance.new("Attachment")
	attachment.Name = name
	attachment.Position = offset
	attachment.Parent = root
	return attachment
end

local function onCharacter(character: Model)
	trail = nil
	local root = character:WaitForChild("HumanoidRootPart", 5) :: BasePart?
	if not root then
		return
	end
	local glow = Instance.new("Trail")
	glow.Name = "OutpostTrail"
	glow.Attachment0 = point(root, "OutpostTrailTop", TOP)
	glow.Attachment1 = point(root, "OutpostTrailBottom", BOTTOM)
	glow.Brightness = BRIGHTNESS
	glow.Color = ColorSequence.new(Palette.SignalAcid, Palette.DataCyan)
	glow.Enabled = false
	glow.FaceCamera = true
	glow.Lifetime = LIFETIME
	glow.LightEmission = 1
	glow.LightInfluence = 0
	glow.Transparency = NumberSequence.new(START_FADE, 1)
	glow.WidthScale = NumberSequence.new(1, TAIL_WIDTH)
	glow.Parent = root
	trail = glow
end

player.CharacterAdded:Connect(onCharacter)
if player.Character then
	task.spawn(onCharacter, player.Character)
end

RunService.RenderStepped:Connect(function()
	if trail then
		trail.Enabled = Zones.of(player) == Zones.Outpost
	end
end)
