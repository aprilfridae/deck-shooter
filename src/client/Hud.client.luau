-- The HUD: crosshair, health, shield, ammo, class, cooldowns and hit marker.
local Palette = require(game:GetService("ReplicatedStorage"):WaitForChild("Guns"):WaitForChild("Palette"))
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local GunConfig = require(ReplicatedStorage:WaitForChild("Guns"):WaitForChild("GunConfig"))
local GunSounds = require(ReplicatedStorage:WaitForChild("Guns"):WaitForChild("GunSounds"))
local HitMarker = require(ReplicatedStorage:WaitForChild("Guns"):WaitForChild("HitMarker"))
local MenuState = require(ReplicatedStorage:WaitForChild("Guns"):WaitForChild("MenuState"))
local Zones = require(ReplicatedStorage:WaitForChild("Guns"):WaitForChild("Zones"))
local GunAudio = require(script.Parent.GunAudio)
local GunView = require(script.Parent.GunView)
local PlayerSettings = require(script.Parent.PlayerSettings)
local TypeLabel = require(script.Parent.TypeLabel)
local CardCore = ReplicatedStorage:WaitForChild("CardCore")
local Cards = require(CardCore:WaitForChild("Cards"))
local Config = require(CardCore:WaitForChild("Config"))
local Settings = require(CardCore:WaitForChild("Settings"))
local HudText = require(ReplicatedStorage:WaitForChild("Guns"):WaitForChild("Hud"):WaitForChild("HudText"))

local remotes = ReplicatedStorage:WaitForChild("GunRemotes")
local hitRemote = remotes:WaitForChild("HitConfirm") :: RemoteEvent

local BONE = Palette.Bone
local ACID = Palette.SignalAcid
local EMPTY = Palette.DeepNavy
-- The hit marker: four dashes in an X around the crosshair.
local MARKER_COLOR = Palette.SignalAcid
local MARKER_SECONDS = 0.3
local MARKER_GAP = 5 -- from the middle of the screen to the inner end of each dash
local MARKER_LENGTH = 6
local MARKER_WIDTH = 1
local MARKER_POP = 1.6 -- how much bigger it starts
local MARKER_KILL = 1.5 -- how much bigger a kill's marker is
local SLOTS = 3
-- HUD layout, in pixels on a 720-tall screen. The whole HUD scales from there.
local MARGIN = 32
local BASELINE = -32 -- the big numbers, from the bottom
local LABEL_LINE = BASELINE - 44
local LABEL_INSET = 2 -- lines the thin labels up with the numbers' edge
local CLASS_X = 108
local SHIELD_GAP = 8
local NUMBER_SIZE = 46
local LABEL_SIZE = 12
local TIER_SIZE = 10
local LABEL_TRACKING = 3
local ROW_TRACKING = 2
local ROW_TOP = BASELINE - 130
local ROW_SPACING = 25
local ROW_WIDTH = 220
local ROW_NAME_X = 18
local BAR_DROP = 5
local BAR_HEIGHT = 2
local BAR_GAP = 2

local player = Players.LocalPlayer
local lastHealth = 0

local gui = Instance.new("ScreenGui")
gui.Name = "DeckHud"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.Parent = player:WaitForChild("PlayerGui")

local crosshair = Instance.new("Frame")
crosshair.AnchorPoint = Vector2.new(0.5, 0.5)
crosshair.Position = UDim2.fromScale(0.5, 0.5)
crosshair.Size = UDim2.fromOffset(4, 4)
crosshair.BackgroundColor3 = BONE
crosshair.BorderSizePixel = 0
crosshair.Parent = gui

local marker = Instance.new("Frame")
marker.AnchorPoint = Vector2.new(0.5, 0.5)
marker.Position = UDim2.fromScale(0.5, 0.5)
marker.BackgroundTransparency = 1
marker.Visible = false
marker.Parent = gui

local markerScale = Instance.new("UIScale")
markerScale.Parent = marker

local markerDashes = {}
for _, corner in { Vector2.new(-1, -1), Vector2.new(1, -1), Vector2.new(-1, 1), Vector2.new(1, 1) } do
	local reach = (MARKER_GAP + MARKER_LENGTH / 2) * math.sqrt(0.5)
	local dash = Instance.new("Frame")
	dash.AnchorPoint = Vector2.new(0.5, 0.5)
	dash.Position = UDim2.fromOffset(corner.X * reach, corner.Y * reach)
	dash.Size = UDim2.fromOffset(MARKER_LENGTH, MARKER_WIDTH)
	dash.Rotation = if corner.X == corner.Y then 45 else -45
	dash.BackgroundColor3 = MARKER_COLOR
	dash.BorderSizePixel = 0
	dash.Parent = marker
	table.insert(markerDashes, dash)
end

local hud = Instance.new("Frame")
hud.BackgroundTransparency = 1
hud.Parent = gui

local hudScale = Instance.new("UIScale")
hudScale.Parent = hud

local function fitToScreen()
	local scale = HudText.scale(gui.AbsoluteSize.Y)
	hudScale.Scale = scale
	hud.Size = UDim2.fromScale(1 / scale, 1 / scale)
end

gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(fitToScreen)
fitToScreen()

local function number(style: string, color: Color3, right: boolean?, position: UDim2): any
	return TypeLabel.new(
		hud,
		{ style = style, size = NUMBER_SIZE, tracking = 0, color = color, right = right, position = position }
	)
end

local function small(style: string, right: boolean?, position: UDim2): any
	return TypeLabel.new(
		hud,
		{ style = style, size = LABEL_SIZE, tracking = LABEL_TRACKING, color = BONE, right = right, position = position }
	)
end

local healthText = number("Number", BONE, false, UDim2.new(0, MARGIN, 1, BASELINE))
local shieldText = number("NumberThin", ACID, false, UDim2.new(0, MARGIN, 1, BASELINE))
local ammoText = number("Number", BONE, true, UDim2.new(1, -MARGIN, 1, BASELINE))
local healthLabel = small("Label", false, UDim2.new(0, MARGIN + LABEL_INSET, 1, LABEL_LINE))
local classText = small("Label", false, UDim2.new(0, CLASS_X, 1, LABEL_LINE))
local gunText = small("Label", true, UDim2.new(1, -MARGIN - LABEL_INSET, 1, LABEL_LINE))
local reloadText = small("LabelBold", true, UDim2.new(1, -MARGIN - LABEL_INSET, 1, LABEL_LINE))
reloadText:setColor(ACID)
healthLabel:set("HEALTH")

local markerAt = 0
local markerSize = 1

local function abilityRow(index: number)
	local line = ROW_TOP + (index - 1) * ROW_SPACING
	local left = MARGIN + LABEL_INSET
	local function rowText(style: string, size: number, right: boolean?, x: number): any
		return TypeLabel.new(hud, {
			style = style,
			size = size,
			tracking = ROW_TRACKING,
			color = BONE,
			right = right,
			position = UDim2.new(0, x, 1, line),
		})
	end
	local key = rowText("LabelBold", LABEL_SIZE, false, left)
	local name = rowText("Label", LABEL_SIZE, false, left + ROW_NAME_X)
	local tier = rowText("Label", TIER_SIZE, true, left + ROW_WIDTH)
	local function showKey()
		key:set(HudText.key(index, Settings.keyLabel(PlayerSettings.get().keys[`slot{index}`])))
	end
	showKey()
	PlayerSettings.changed:Connect(showKey)

	local bar = Instance.new("Frame")
	bar.BackgroundTransparency = 1
	bar.Position = UDim2.new(0, left, 1, line + BAR_DROP)
	bar.Size = UDim2.fromOffset(ROW_WIDTH, BAR_HEIGHT)
	bar.Parent = hud

	local segments = {}
	local count = Config.CooldownSegments
	local gap = BAR_GAP / ROW_WIDTH
	local width = (1 - gap * (count - 1)) / count
	for i = 1, count do
		local segment = Instance.new("Frame")
		segment.Position = UDim2.fromScale((i - 1) * (width + gap), 0)
		segment.Size = UDim2.fromScale(width, 1)
		segment.BorderSizePixel = 0
		segment.Parent = bar
		segments[i] = segment
	end
	return { key = key, name = name, tier = tier, bar = bar, segments = segments }
end

local rows = {}
for index = 1, SLOTS do
	rows[index] = abilityRow(index)
end

local function showRow(index: number, now: number)
	local row = rows[index]
	local card = Cards.byId[player:GetAttribute(`Ability{index}Id`) or ""]
	local shown = card ~= nil
	row.key:setVisible(shown)
	row.name:setVisible(shown)
	row.tier:setVisible(shown)
	row.bar.Visible = shown
	if not card then
		return
	end
	row.name:set(card.name)
	local tier = player:GetAttribute(`Ability{index}Tier`)
	row.tier:set(tostring(tier))
	row.tier:setColor(Palette.Tiers[tier] or BONE)
	local left = player:GetAttribute(`Ability{index}ReadyAt`) - now
	local filled = HudText.filled(left, player:GetAttribute(`Ability{index}Cooldown`), #row.segments)
	row.key:setColor(if filled == #row.segments then ACID else BONE)
	for i, segment in row.segments do
		segment.BackgroundColor3 = if i <= filled then BONE else EMPTY
	end
end

hitRemote.OnClientEvent:Connect(function(info)
	markerAt = os.clock()
	markerSize = if info.killed then MARKER_KILL else 1
	marker.Visible = true
	GunAudio.playHit(info.headshot, info.killed)
	if info.killed then
		GunView.snap()
	end
end)

RunService.RenderStepped:Connect(function()
	-- The combat HUD is hidden in the Outpost, where guns and cards are off.
	gui.Enabled = not MenuState.isOpen(MenuState.shared) and Zones.allowsCombat(Zones.of(player))
	local character = player.Character
	local health = character and character:GetAttribute("Health") or 0
	if GunSounds.hurtPlays(lastHealth, health) then
		GunAudio.playHurt()
	end
	lastHealth = health
	healthText:set(HudText.health(health))
	local shield = HudText.shield(character and character:GetAttribute("ShieldHp"))
	shieldText:set(shield)
	shieldText:setVisible(shield ~= "")
	shieldText:setPosition(UDim2.new(0, MARGIN + healthText:width() + SHIELD_GAP, 1, BASELINE))
	classText:set(player:GetAttribute("Class") or "")
	local gun = GunConfig.guns[player:GetAttribute("GunId")]
	local reloading = gun ~= nil and player:GetAttribute("Reloading") == true
	ammoText:setVisible(gun ~= nil)
	gunText:setVisible(gun ~= nil and not reloading)
	reloadText:setVisible(reloading)
	if gun then
		ammoText:set(HudText.ammo(player:GetAttribute("Ammo")))
		gunText:set(HudText.gunLabel(gun.name, gun.mag, false))
		reloadText:set(HudText.gunLabel(gun.name, gun.mag, true))
	end
	local now = workspace:GetServerTimeNow()
	for index = 1, SLOTS do
		showRow(index, now)
	end
	if marker.Visible then
		local scale, transparency = HitMarker.look(os.clock() - markerAt, MARKER_SECONDS, MARKER_POP)
		if scale then
			markerScale.Scale = scale * markerSize
			for _, dash in markerDashes do
				dash.BackgroundTransparency = transparency
			end
		else
			marker.Visible = false
		end
	end
end)
