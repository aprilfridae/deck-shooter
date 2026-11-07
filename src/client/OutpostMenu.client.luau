-- The Outpost's menu: four buttons in the corner, each opening a page in the side panel.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local Workspace = game:GetService("Workspace")

local Guns = ReplicatedStorage:WaitForChild("Guns")
local GunSounds = require(Guns:WaitForChild("GunSounds"))
local MenuState = require(Guns:WaitForChild("MenuState"))
local Palette = require(Guns:WaitForChild("Palette"))
local Zones = require(Guns:WaitForChild("Zones"))
local CardInspect = require(script.Parent.CardInspect)
local IncomeLine = require(script.Parent.IncomeLine)
local MenuCamera = require(script.Parent.MenuCamera)
local LoadoutPanel = require(script.Parent.LoadoutPanel)
local MenuPanel = require(script.Parent.MenuPanel)
local NavButton = require(script.Parent.NavButton)
local PlayerClick = require(script.Parent.PlayerClick)
local PlayPanel = require(script.Parent.PlayPanel)
local ProfilePanel = require(script.Parent.ProfilePanel)
local SettingsPanel = require(script.Parent.SettingsPanel)
local SoundGroups = require(script.Parent.SoundGroups)

-- Shares of the unit.
local NAV_LEFT = 0.03
local NAV_BOTTOM = 0.03
local NAV_WIDTH = 0.124
local NAV_ROW = 0.032
local NAV_LEFT_PADDING = 0.006
local NAV_PADDING = 0.0105
local NAV_TEXT = 0.014
local NAV_TRACKING = 0.0022
local NAV_OUTLINE = 2 -- pixels
local HOVER_PITCH = 1.6
local HOVER_VOLUME = 0.25

local BUTTONS = { "PLAY", "LOADOUT", "PROFILE", "SETTINGS" }

local player = Players.LocalPlayer

local gui = Instance.new("ScreenGui")
gui.Name = "OutpostMenu"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.DisplayOrder = 5 -- under the title screen
gui.Enabled = false
gui.Parent = player:WaitForChild("PlayerGui")

local panel = MenuPanel.new(gui)
MenuCamera.follow(panel)

local clickSound = Instance.new("Sound")
clickSound.Name = "OutpostMenuClick"
clickSound.SoundId = GunSounds.menuSelect
clickSound.SoundGroup = SoundGroups.menu
clickSound.Parent = SoundService

local hoverSound = clickSound:Clone()
hoverSound.Name = "OutpostMenuHover"
hoverSound.PlaybackSpeed = HOVER_PITCH
hoverSound.Volume = HOVER_VOLUME
hoverSound.Parent = SoundService

local nav: Frame? = nil
local income: Frame? = nil
local rows: { [string]: any } = {}
local openPage: string? = nil
local profileUser = player.UserId

local function paint()
	for name, row in rows do
		row:setActive(name == openPage)
	end
end

local function fillPage(name: string)
	panel:clear()
	-- Each page gets its own frame, so a reply that arrives after a swap can tell it's out of date.
	local page = Instance.new("Frame")
	page.BackgroundTransparency = 1
	page.Size = UDim2.fromScale(1, 1)
	page.Parent = panel.content
	if name == "SETTINGS" then
		SettingsPanel.fill(page)
	elseif name == "PLAY" then
		PlayPanel.fill(page)
	elseif name == "LOADOUT" then
		LoadoutPanel.fill(page)
	else
		ProfilePanel.fill(page, profileUser)
	end
end

local function show(name: string)
	openPage = name
	fillPage(name)
	panel:open()
	paint()
end

local function choose(name: string)
	clickSound:Play()
	SettingsPanel.stop()
	-- The PROFILE button leads back to the player's own page from someone else's.
	if name == "PROFILE" and openPage == name and profileUser ~= player.UserId then
		profileUser = player.UserId
		show(name)
	elseif openPage == name then
		openPage = nil
		panel:close()
		paint()
	else
		profileUser = player.UserId
		show(name)
	end
end

local function buildNav()
	if nav then
		for _, row in rows do
			row:destroy()
		end
		nav:Destroy()
	end
	rows = {}
	local unit = MenuPanel.unit()
	local block = Instance.new("Frame")
	block.BorderSizePixel = 0
	block.BackgroundColor3 = Palette.Bone
	block.AnchorPoint = Vector2.new(0, 1)
	block.Position = UDim2.new(0, NAV_LEFT * unit, 1, -NAV_BOTTOM * unit)
	block.Size = UDim2.fromOffset(NAV_WIDTH * unit, NAV_ROW * unit * #BUTTONS)
	block.Parent = gui
	local outline = Instance.new("UIStroke")
	outline.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	outline.Color = Palette.Bone
	outline.Thickness = NAV_OUTLINE
	outline.Parent = block
	local clip = Instance.new("Frame")
	clip.BackgroundTransparency = 1
	clip.ClipsDescendants = true
	clip.Size = UDim2.fromScale(1, 1)
	clip.Parent = block
	for index, name in BUTTONS do
		rows[name] = NavButton.new({
			parent = clip,
			glowParent = block,
			name = name,
			index = index,
			unit = unit,
			width = NAV_WIDTH * unit,
			height = NAV_ROW * unit,
			left = NAV_LEFT_PADDING * unit,
			padding = NAV_PADDING * unit,
			textSize = NAV_TEXT * unit,
			tracking = NAV_TRACKING * unit,
			onClick = function()
				choose(name)
			end,
			onHover = function()
				hoverSound:Play()
			end,
		})
	end
	nav = block
	if income then
		income:Destroy()
	end
	income = IncomeLine.new(gui)
	paint()
end

buildNav()
Workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
	buildNav()
	if openPage then
		fillPage(openPage)
	end
end)

-- The menu belongs to the Outpost, and stays away while the title screen is up.
RunService.RenderStepped:Connect(function()
	local visible = Zones.of(player) == Zones.Outpost and not MenuState.isOpen(MenuState.shared)
	if nav and income then
		nav.Visible = not CardInspect.isOpen() -- it would sit on top of the card
		income.Visible = nav.Visible
	end
	if visible == gui.Enabled then
		return
	end
	gui.Enabled = visible
	if visible then
		for _, row in rows do
			row:enter()
		end
	else
		SettingsPanel.stop()
		CardInspect.close()
		openPage = nil
		panel:close()
		paint()
	end
end)

PlayerClick.listen(function()
	return gui.Enabled
end, function(clicked: Player)
	clickSound:Play()
	SettingsPanel.stop()
	profileUser = clicked.UserId
	show("PROFILE")
end)
