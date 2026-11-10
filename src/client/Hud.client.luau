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
local CardData = require(script.Parent.CardData)
local CardFace = require(script.Parent.CardFace)
local CardInHand = require(script.Parent.CardInHand)
local TypeLabel = require(script.Parent.TypeLabel)
local KillPopups = require(script.Parent.KillPopups)
local CardCore = ReplicatedStorage:WaitForChild("CardCore")
local Cards = require(CardCore:WaitForChild("Cards"))
local CardIndex = require(CardCore:WaitForChild("CardIndex"))
local HudText = require(ReplicatedStorage:WaitForChild("Guns"):WaitForChild("Hud"):WaitForChild("HudText"))

local remotes = ReplicatedStorage:WaitForChild("GunRemotes")
local hitRemote = remotes:WaitForChild("HitConfirm") :: RemoteEvent
local rewardRemote = remotes:WaitForChild("KillReward") :: RemoteEvent

local BONE = Palette.Bone
-- The hit marker: four dashes in an X around the crosshair.
local MARKER_COLOR = Palette.Bone
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
local LABEL_TRACKING = 3
-- The spread of equipped cards above the health.
local CARD_HEIGHT = 96
local CARD_WIDTH = CARD_HEIGHT * 0.625
local CARD_CORNER = 10 / 150 -- the art's rounded corner, as a share of the card's width
local CARD_LINE = LABEL_LINE - 26 -- the bottom of the middle card
local CARD_STEP = 34 -- from one card's middle to the next
local CARD_TILT = 14 -- degrees the outer cards lean
local CARD_DROP = 6 -- how much lower the outer cards sit
local CARD_LIFT = 10 -- how far the card in hand rises
local CARD_LIFT_TIME = 0.07 -- seconds it takes to get most of the way
local CARD_GLITCH_TIME = 0.42 -- seconds a picked card glitches out and back in on top
local CARD_GLITCH_SHIFT = 8 -- how far it jumps sideways while it does
local CARD_GLITCH_SPLIT = 9 -- how far its red and cyan ghosts pull apart
local CARD_GLITCH_GHOST = 0.35 -- how see-through they are
local CARD_GLITCH_BARS = 3 -- lines of static across it
local CARD_GREY = Color3.fromRGB(86, 90, 98) -- what lies over a card on cooldown
local CARD_GREYED = 0.2 -- how see-through that grey is when the cooldown starts

local player = Players.LocalPlayer
local lastHealth = 0

local gui = Instance.new("ScreenGui")
gui.Name = "DeckHud"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling -- so each card's face and grey stay with their own card
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
KillPopups.start(hud, rewardRemote)

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
local shieldText = number("NumberThin", BONE, false, UDim2.new(0, MARGIN, 1, BASELINE))
local ammoText = number("Number", BONE, true, UDim2.new(1, -MARGIN, 1, BASELINE))
local healthLabel = small("Label", false, UDim2.new(0, MARGIN + LABEL_INSET, 1, LABEL_LINE))
local classText = small("Label", false, UDim2.new(0, CLASS_X, 1, LABEL_LINE))
local gunText = small("Label", true, UDim2.new(1, -MARGIN - LABEL_INSET, 1, LABEL_LINE))
local reloadText = small("LabelBold", true, UDim2.new(1, -MARGIN - LABEL_INSET, 1, LABEL_LINE))
reloadText:setColor(BONE)
healthLabel:set("HEALTH")

local markerAt = 0
local markerSize = 1

-- The equipped cards, fanned out above the health: slot 1 on the left and on top, slot 2 upright under it, slot 3 under that.
local function spreadCard(index: number)
	local side = index - (SLOTS + 1) / 2 -- -1, 0, 1
	local image = Instance.new("Frame") -- holds the card's face
	image.AnchorPoint = Vector2.new(0.5, 0.5)
	image.Size = UDim2.fromOffset(CARD_WIDTH, CARD_HEIGHT)
	image.Rotation = side * CARD_TILT
	image.BackgroundTransparency = 1
	image.ZIndex = SLOTS + 1 - index
	image.Visible = false
	image.Parent = hud
	-- The grey that lies over a card on cooldown.
	local grey = Instance.new("Frame")
	grey.Size = UDim2.fromScale(1, 1)
	grey.BackgroundColor3 = CARD_GREY
	grey.BackgroundTransparency = 1
	grey.BorderSizePixel = 0
	grey.ZIndex = 10 -- over the face
	local flash = grey:Clone() -- lights the card while it glitches
	flash.BackgroundColor3 = Palette.DataCyan
	flash.ZIndex = 11
	flash.Parent = image
	grey.Parent = image
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(CARD_CORNER, 0)
	corner.Parent = grey
	corner:Clone().Parent = flash
	local scale = Instance.new("UIScale")
	scale.Parent = image
	-- The card's shape in cyan and in red, behind it, which pull apart to either side while it glitches.
	local ghosts = {}
	for which, color in { Palette.DataCyan, Palette.HazardRed } do
		local ghost = flash:Clone()
		ghost.AnchorPoint = Vector2.new(0.5, 0.5)
		ghost.BackgroundColor3 = color
		ghost.BackgroundTransparency = CARD_GLITCH_GHOST
		ghost.ZIndex = 0
		ghost.Visible = false
		ghost.Parent = image
		ghosts[which] = ghost
	end
	local bars = {}
	for which = 1, CARD_GLITCH_BARS do
		local bar = Instance.new("Frame")
		bar.AnchorPoint = Vector2.new(0.5, 0.5)
		bar.BackgroundColor3 = if which == 1 then Palette.DataCyan else BONE
		bar.BorderSizePixel = 0
		bar.ZIndex = 12
		bar.Visible = false
		bar.Parent = image
		bars[which] = bar
	end
	return {
		image = image,
		grey = grey,
		flash = flash,
		scale = scale,
		ghosts = ghosts,
		bars = bars,
		x = MARGIN + CARD_WIDTH / 2 + CARD_STEP + side * CARD_STEP,
		y = CARD_LINE - CARD_HEIGHT / 2 + math.abs(side) * CARD_DROP,
		shows = "",
		face = nil :: GuiObject?,
		lift = 0, -- how far it has risen, from 0 to 1
		over = SLOTS + 1 - index, -- how high it lies in the spread
		pulledAt = -1, -- when it was last picked
		pulled = false, -- whether it's on top yet since
	}
end

local spread = {}
for index = 1, SLOTS do
	spread[index] = spreadCard(index)
end
CardData.changed:Connect(function()
	for _, card in spread do
		card.shows = "" -- its look may have changed
	end
end)

local heldShown: number? = nil -- the card in hand the spread has caught up with

-- The picked card glitches out of the spread and back in on top of the rest.
local function pick(index: number)
	local card = spread[index]
	local top = 0
	for _, other in spread do
		top = math.max(top, other.over)
	end
	if card.over < top then
		card.over = top + 1
		card.pulledAt = os.clock()
		card.pulled = false
	end
end

local function showCard(index: number, now: number, step: number)
	local card = spread[index]
	local id = player:GetAttribute(`Ability{index}Id`) or ""
	if not Cards.byId[id] then
		card.image.Visible = false
		return
	end
	local tier = tostring(player:GetAttribute(`Ability{index}Tier`))
	if card.shows ~= id .. tier then
		card.shows = id .. tier
		local snapshot = CardData.get()
		local variant = if snapshot then CardIndex.variant(snapshot.stacks, id, tier) else ""
		if card.face then
			card.face:Destroy()
		end
		-- The same face as in the menus, with its name and rarity printed on it.
		card.face = CardFace.new(card.image, { cardId = id, tier = tier, variant = variant, width = CARD_WIDTH })
	end
	local left = (player:GetAttribute(`Ability{index}ReadyAt`) or 0) - now
	local colour = HudText.colour(left, player:GetAttribute(`Ability{index}Cooldown`) or 0)
	card.grey.BackgroundTransparency = CARD_GREYED + (1 - CARD_GREYED) * colour
	-- The card in hand slides up, and back down when it's put away.
	local held = if CardInHand.slot == index then 1 else 0
	card.lift += (held - card.lift) * (1 - math.exp(-step / CARD_LIFT_TIME))
	local glitch = HudText.glitch((os.clock() - card.pulledAt) / CARD_GLITCH_TIME)
	if glitch.over and not card.pulled then
		card.pulled = true
		card.image.ZIndex = card.over -- it's gone here, and comes back over the others
	end
	-- It breaks up lit cyan, and lands with a white flash and a little too big.
	card.scale.Scale = glitch.scale
	card.flash.BackgroundColor3 = if glitch.over then Color3.new(1, 1, 1) else Palette.DataCyan
	card.flash.BackgroundTransparency = if glitch.there then 1 - glitch.flash else 1
	card.grey.Visible = glitch.there
	if card.face then
		card.face.Visible = glitch.there
	end
	for which, ghost in card.ghosts do
		-- While the card is gone its ghosts take turns, so something of it is always there.
		ghost.Visible = glitch.split > 0 and (glitch.there or glitch.step % 2 == which - 1)
		ghost.Position = UDim2.new(0.5, (which * 2 - 3) * glitch.split * CARD_GLITCH_SPLIT, 0.5, 0)
	end
	for which, bar in card.bars do
		bar.Visible = glitch.step >= 0
		if bar.Visible then
			local at = glitch.step * CARD_GLITCH_BARS + which
			bar.Position = UDim2.fromScale(0.5 + HudText.noise(at + 0.5) * 0.15, 0.5 + HudText.noise(at) * 0.48)
			bar.Size = UDim2.new(0.9 + HudText.noise(at + 0.25) * 0.4, 0, 0, if which == 1 then 3 else 1)
		end
	end
	card.image.Position = UDim2.new(0, card.x + glitch.shift * CARD_GLITCH_SHIFT, 1, card.y - card.lift * CARD_LIFT)
	card.image.Visible = true
end

hitRemote.OnClientEvent:Connect(function(info)
	markerAt = os.clock()
	markerSize = if info.killed then MARKER_KILL else 1
	marker.Visible = true
	GunAudio.playHit(info.headshot, info.killed)
	if info.collateral then
		GunAudio.playCollateral()
	end
	if info.killed and GunView.snap() then
		GunAudio.playSnap()
	end
end)

RunService.RenderStepped:Connect(function(step)
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
	crosshair.Visible = player:GetAttribute("ScopeShown") ~= true -- the scope has its own reticle
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
	if CardInHand.slot ~= heldShown then
		heldShown = CardInHand.slot
		if heldShown and spread[heldShown] then
			pick(heldShown)
		end
	end
	for index = 1, SLOTS do
		showCard(index, now, step)
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
