-- A basic HUD: crosshair, health, ammo, class and hit marker. Art comes later.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local GunConfig = require(ReplicatedStorage:WaitForChild("Guns"):WaitForChild("GunConfig"))

local remotes = ReplicatedStorage:WaitForChild("GunRemotes")
local ammoRemote = remotes:WaitForChild("AmmoChanged") :: RemoteEvent
local hitRemote = remotes:WaitForChild("HitConfirm") :: RemoteEvent

local WHITE = Color3.fromRGB(255, 255, 255)
local DARK = Color3.fromRGB(25, 25, 30)
local HEADSHOT = Color3.fromRGB(255, 80, 70)
local MARKER_SECONDS = 0.15
local MAX_HEALTH = 100

local player = Players.LocalPlayer

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

local markerHideAt = 0

ammoRemote.OnClientEvent:Connect(function(info)
	ammoText.Text = if info.reloading then `Reloading {info.ammo}` else `{info.ammo} / {info.mag}`
	gunText.Text = GunConfig.guns[info.gunId].name
end)

hitRemote.OnClientEvent:Connect(function(info)
	marker.TextColor3 = if info.headshot then HEADSHOT else WHITE
	marker.Text = if info.killed then "X" else "+"
	marker.Visible = true
	markerHideAt = os.clock() + MARKER_SECONDS
end)

RunService.RenderStepped:Connect(function()
	local character = player.Character
	local health = character and character:GetAttribute("Health") or 0
	healthFill.Size = UDim2.fromScale(math.clamp(health / MAX_HEALTH, 0, 1), 1)
	classText.Text = player:GetAttribute("Class") or ""
	if marker.Visible and os.clock() >= markerHideAt then
		marker.Visible = false
	end
end)
