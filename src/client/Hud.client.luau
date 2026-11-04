-- A basic HUD: crosshair, health, ammo, class, cooldowns and hit marker. Art comes later.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local GunConfig = require(ReplicatedStorage:WaitForChild("Guns"):WaitForChild("GunConfig"))
local GunSounds = require(ReplicatedStorage:WaitForChild("Guns"):WaitForChild("GunSounds"))
local GunAudio = require(script.Parent.GunAudio)
local CardCore = ReplicatedStorage:WaitForChild("CardCore")
local Cards = require(CardCore:WaitForChild("Cards"))
local Config = require(CardCore:WaitForChild("Config"))

local remotes = ReplicatedStorage:WaitForChild("GunRemotes")
local hitRemote = remotes:WaitForChild("HitConfirm") :: RemoteEvent

local WHITE = Color3.fromRGB(255, 255, 255)
local DARK = Color3.fromRGB(25, 25, 30)
local HEADSHOT = Color3.fromRGB(255, 80, 70)
local MARKER_SECONDS = 0.15
local MAX_HEALTH = 100
local SLOTS = 3
local FIRST_KEY = 3
local BAR_WIDTH = 260
local BAR_GAP = 2
local BAR_HEIGHT = 6
local BAR_SPACING = 34
local BARS_ABOVE = -84

local player = Players.LocalPlayer
local lastHealth = 0

local gui = Instance.new("ScreenGui")
gui.Name = "DeckHud"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.Parent = player:WaitForChild("PlayerGui")

local function label(position: UDim2, anchor: Vector2, size: number): TextLabel
	local text = Instance.new("TextLabel")
	text.BackgroundTransparency = 1
	text.Position = position
	text.AnchorPoint = anchor
	text.Size = UDim2.fromOffset(320, size + 8)
	text.TextSize = size
	text.Font = Enum.Font.GothamBold
	text.TextColor3 = WHITE
	text.TextXAlignment = if anchor.X > 0.9 then Enum.TextXAlignment.Right else Enum.TextXAlignment.Left
	text.Parent = gui
	return text
end

local crosshair = Instance.new("Frame")
crosshair.AnchorPoint = Vector2.new(0.5, 0.5)
crosshair.Position = UDim2.fromScale(0.5, 0.5)
crosshair.Size = UDim2.fromOffset(4, 4)
crosshair.BackgroundColor3 = WHITE
crosshair.BorderSizePixel = 0
crosshair.Parent = gui

local marker = label(UDim2.fromScale(0.5, 0.5), Vector2.new(0.5, 0.5), 30)
marker.TextXAlignment = Enum.TextXAlignment.Center
marker.Text = "+"
marker.Visible = false

local healthBack = Instance.new("Frame")
healthBack.AnchorPoint = Vector2.new(0, 1)
healthBack.Position = UDim2.new(0, 24, 1, -24)
healthBack.Size = UDim2.fromOffset(260, 16)
healthBack.BackgroundColor3 = DARK
healthBack.BorderSizePixel = 0
healthBack.Parent = gui

local healthFill = Instance.new("Frame")
healthFill.Size = UDim2.fromScale(1, 1)
healthFill.BackgroundColor3 = WHITE
healthFill.BorderSizePixel = 0
healthFill.Parent = healthBack

local ammoText = label(UDim2.new(1, -24, 1, -24), Vector2.new(1, 1), 30)
local gunText = label(UDim2.new(1, -24, 1, -62), Vector2.new(1, 1), 16)
local classText = label(UDim2.new(0, 24, 1, -48), Vector2.new(0, 1), 16)
local statusText = label(UDim2.new(0.5, 0, 1, -24), Vector2.new(0.5, 1), 16)
statusText.TextXAlignment = Enum.TextXAlignment.Center

local markerHideAt = 0

local function cooldownBar(index: number)
	local offset = BARS_ABOVE - (SLOTS - index) * BAR_SPACING
	local name = label(UDim2.new(0, 24, 1, offset - BAR_HEIGHT - 2), Vector2.new(0, 1), 14)
	local segments = {}
	local count = Config.CooldownSegments
	local width = (BAR_WIDTH - BAR_GAP * (count - 1)) / count
	for i = 1, count do
		local segment = Instance.new("Frame")
		segment.AnchorPoint = Vector2.new(0, 1)
		segment.Position = UDim2.new(0, 24 + (i - 1) * (width + BAR_GAP), 1, offset)
		segment.Size = UDim2.fromOffset(width, BAR_HEIGHT)
		segment.BorderSizePixel = 0
		segment.Parent = gui
		segments[i] = segment
	end
	return { name = name, segments = segments }
end

local bars = {}
for index = 1, SLOTS do
	bars[index] = cooldownBar(index)
end

local function showBar(index: number, now: number)
	local bar = bars[index]
	local card = Cards.byId[player:GetAttribute(`Ability{index}Id`) or ""]
	bar.name.Visible = card ~= nil
	local filled = 0
	if card then
		local tier = player:GetAttribute(`Ability{index}Tier`)
		bar.name.Text = `{index + FIRST_KEY - 1}  {card.name} ({tier})`
		local left = player:GetAttribute(`Ability{index}ReadyAt`) - now
		local share = 1 - math.clamp(left / player:GetAttribute(`Ability{index}Cooldown`), 0, 1)
		filled = math.floor(share * #bar.segments)
	end
	for i, segment in bar.segments do
		segment.Visible = card ~= nil
		segment.BackgroundColor3 = if i <= filled then WHITE else DARK
	end
end

hitRemote.OnClientEvent:Connect(function(info)
	marker.TextColor3 = if info.headshot then HEADSHOT else WHITE
	marker.Text = if info.killed then "X" else "+"
	marker.Visible = true
	markerHideAt = os.clock() + MARKER_SECONDS
	GunAudio.playHit(info.headshot, info.killed)
end)

RunService.RenderStepped:Connect(function()
	local character = player.Character
	local health = character and character:GetAttribute("Health") or 0
	if GunSounds.hurtPlays(lastHealth, health) then
		GunAudio.playHurt()
	end
	lastHealth = health
	healthFill.Size = UDim2.fromScale(math.clamp(health / MAX_HEALTH, 0, 1), 1)
	classText.Text = player:GetAttribute("Class") or ""
	local gun = GunConfig.guns[player:GetAttribute("GunId")]
	if gun then
		local ammo = player:GetAttribute("Ammo")
		ammoText.Text = if player:GetAttribute("Reloading") then `Reloading {ammo}` else `{ammo} / {gun.mag}`
		gunText.Text = gun.name
	end
	local now = workspace:GetServerTimeNow()
	local shield = character and character:GetAttribute("ShieldHp")
	statusText.Text = if shield then `Shield {math.ceil(shield)}` else ""
	for index = 1, SLOTS do
		showBar(index, now)
	end
	if marker.Visible and os.clock() >= markerHideAt then
		marker.Visible = false
	end
end)
