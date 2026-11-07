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
local MenuPanel = require(script.Parent.MenuPanel)
local SettingsPanel = require(script.Parent.SettingsPanel)
local SoundGroups = require(script.Parent.SoundGroups)
local TypeLabel = require(script.Parent.TypeLabel)

-- Shares of the unit.
local NAV_LEFT = 0.03
local NAV_BOTTOM = 0.03
local NAV_WIDTH = 0.13
local NAV_ROW = 0.03
local NAV_PADDING = 0.012
local NAV_TEXT = 0.0125
local NAV_TRACKING = 0.0025
local PAGE_MARGIN = 0.025
local PAGE_TITLE = 0.085
local PAGE_LINE = 0.095
local PAGE_NOTE = 0.13

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

local clickSound = Instance.new("Sound")
clickSound.Name = "OutpostMenuClick"
clickSound.SoundId = GunSounds.menuSelect
clickSound.SoundGroup = SoundGroups.menu
clickSound.Parent = SoundService

local nav: Frame? = nil
local rows: { [string]: { button: TextButton, text: any } } = {}
local openPage: string? = nil

local function paint()
	for name, row in rows do
		local active = name == openPage
		row.button.BackgroundColor3 = if active then Palette.SignalAcid else Palette.DeepNavy
		row.text:setColor(if active then Palette.DeepNavy else Palette.Bone)
	end
end

local function soonPage(name: string)
	local unit = MenuPanel.unit()
	local title = TypeLabel.new(panel.content, {
		style = "Title",
		size = PAGE_TITLE * unit,
		tracking = 0,
		color = Palette.DeepNavy,
		shadow = false,
		position = UDim2.fromOffset(PAGE_MARGIN * unit, PAGE_LINE * unit),
	})
	title:set(name)
	local note = TypeLabel.new(panel.content, {
		style = "LabelBold",
		size = NAV_TEXT * unit,
		tracking = NAV_TRACKING * unit,
		color = Palette.DeepNavy,
		shadow = false,
		position = UDim2.fromOffset(PAGE_MARGIN * unit, PAGE_NOTE * unit),
	})
	note:set("SOON")
end

local function fillPage(name: string)
	panel:clear()
	if name == "SETTINGS" then
		SettingsPanel.fill(panel.content)
	else
		soonPage(name)
	end
end

local function choose(name: string)
	clickSound:Play()
	SettingsPanel.stop()
	if openPage == name then
		openPage = nil
		panel:close()
	else
		openPage = name
		fillPage(name)
		panel:open()
	end
	paint()
end

local function buildNav()
	if nav then
		nav:Destroy()
	end
	rows = {}
	local unit = MenuPanel.unit()
	local block = Instance.new("Frame")
	block.BorderSizePixel = 0
	block.BackgroundColor3 = Palette.DeepNavy
	block.AnchorPoint = Vector2.new(0, 1)
	block.Position = UDim2.new(0, NAV_LEFT * unit, 1, -NAV_BOTTOM * unit)
	block.Size = UDim2.fromOffset(NAV_WIDTH * unit, NAV_ROW * unit * #BUTTONS)
	block.Parent = gui
	for index, name in BUTTONS do
		local button = Instance.new("TextButton")
		button.Text = ""
		button.AutoButtonColor = false
		button.BorderSizePixel = 0
		button.Position = UDim2.fromOffset(0, (index - 1) * NAV_ROW * unit)
		button.Size = UDim2.fromOffset(NAV_WIDTH * unit, NAV_ROW * unit)
		button.Parent = block
		local text = TypeLabel.new(button, {
			style = "LabelBold",
			size = NAV_TEXT * unit,
			tracking = NAV_TRACKING * unit,
			color = Palette.Bone,
			shadow = false,
			position = UDim2.fromOffset(NAV_PADDING * unit, (NAV_ROW + NAV_TEXT) / 2 * unit),
		})
		text:set(name)
		rows[name] = { button = button, text = text }
		button.Activated:Connect(function()
			choose(name)
		end)
	end
	nav = block
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
	local show = Zones.of(player) == Zones.Outpost and not MenuState.isOpen(MenuState.shared)
	if show == gui.Enabled then
		return
	end
	gui.Enabled = show
	if not show then
		SettingsPanel.stop()
		openPage = nil
		panel:close()
		paint()
	end
end)
