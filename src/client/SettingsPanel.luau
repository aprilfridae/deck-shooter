-- The Settings page: sliders for sound and controls, and a list for rebinding keys.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Guns = ReplicatedStorage:WaitForChild("Guns")
local Settings = require(ReplicatedStorage:WaitForChild("CardCore"):WaitForChild("Settings"))
local MenuPanel = require(script.Parent.MenuPanel)
local PanelKit = require(script.Parent.PanelKit)
local PlayerSettings = require(script.Parent.PlayerSettings)

-- Shares of the unit.
local MARGIN = PanelKit.MARGIN
local RIGHT = PanelKit.RIGHT
local LABEL_SIZE = PanelKit.LABEL_SIZE
local SLIDER_LEFT = 0.2
local SLIDER_RIGHT = 0.41
local SLIDER_STEP = 0.032
local KEY_LIST_TOP = 0.15
local KEY_STEP = 0.031
local KEYBINDS_TOP = 0.395
local KEYBINDS_HEIGHT = 0.04

local TRACK_FADE = 0.75
local MESSAGE_TIME = 1.5 -- seconds


local listening: RBXScriptConnection? = nil

local SettingsPanel = {}

function SettingsPanel.stop()
	if listening then
		listening:Disconnect()
		listening = nil
	end
end

local label = PanelKit.label
local line = PanelKit.line
local title = PanelKit.title
local hitBox = PanelKit.hitBox

local function heading(parent: Instance, text: string, y: number)
	PanelKit.heading(parent, text, y)
end

local function round(value: number, step: number): number
	return math.round(value / step) * step
end

local function slider(parent: Instance, name: string, field: string, y: number, step: number, show: (number) -> string)
	local unit = MenuPanel.unit()
	local low, high = Settings.range(field)
	line(parent, name, MARGIN, y)
	local value = line(parent, "", RIGHT, y, true)

	local hit = hitBox(parent, SLIDER_LEFT, y - SLIDER_STEP * 0.7, SLIDER_RIGHT - SLIDER_LEFT, SLIDER_STEP)
	local track = Instance.new("Frame")
	track.BorderSizePixel = 0
	track.BackgroundColor3 = PanelKit.INK
	track.BackgroundTransparency = TRACK_FADE
	track.AnchorPoint = Vector2.new(0, 0.5)
	track.Position = UDim2.fromScale(0, 0.5)
	track.Size = UDim2.new(1, 0, 0, 2)
	track.Parent = hit
	local fill = track:Clone()
	fill.BackgroundTransparency = 0
	fill.Parent = hit
	local handle = Instance.new("Frame")
	handle.BorderSizePixel = 0
	handle.BackgroundColor3 = PanelKit.INK
	handle.AnchorPoint = Vector2.new(0.5, 0.5)
	handle.Size = UDim2.fromOffset(math.max(3, 0.003 * unit), 0.013 * unit)
	handle.Parent = hit

	local function display(current: number)
		local share = (current - low) / (high - low)
		fill.Size = UDim2.new(share, 0, 0, 2)
		handle.Position = UDim2.fromScale(share, 0.5)
		value:set(show(current))
	end
	display(PlayerSettings.get()[field])

	local function moveTo(x: number)
		local share = math.clamp((x - hit.AbsolutePosition.X) / hit.AbsoluteSize.X, 0, 1)
		local current = math.clamp(round(low + share * (high - low), step), low, high)
		PlayerSettings.set({ [field] = current })
		display(current)
	end

	hit.InputBegan:Connect(function(input)
		if input.UserInputType ~= Enum.UserInputType.MouseButton1 then
			return
		end
		moveTo(input.Position.X)
		local moved, ended
		moved = UserInputService.InputChanged:Connect(function(change)
			if change.UserInputType == Enum.UserInputType.MouseMovement then
				moveTo(change.Position.X)
			end
		end)
		ended = UserInputService.InputEnded:Connect(function(release)
			if release.UserInputType == Enum.UserInputType.MouseButton1 then
				moved:Disconnect()
				ended:Disconnect()
				PlayerSettings.send()
			end
		end)
	end)
end

local function percent(value: number): string
	return tostring(math.round(value * 100))
end

local function whole(value: number): string
	return tostring(math.round(value))
end

local function oneDecimal(value: number): string
	return string.format("%.1f", value)
end

local showMain: (Frame) -> ()

local function bindKey(action: string, keyName: string): boolean
	local keys = Settings.rebind(PlayerSettings.get().keys, action, keyName)
	if not keys then
		return false
	end
	PlayerSettings.set({ keys = keys })
	PlayerSettings.send()
	return true
end

local function keyRow(content: Frame, action: { id: string, label: string }, y: number)
	line(content, action.label, MARGIN, y)
	local value = line(content, Settings.keyLabel(PlayerSettings.get().keys[action.id]), RIGHT, y, true)
	local row = hitBox(content, MARGIN, y - KEY_STEP * 0.7, RIGHT - MARGIN, KEY_STEP)

	local over = false
	row.MouseEnter:Connect(function()
		over = true
	end)
	row.MouseLeave:Connect(function()
		over = false
	end)

	local function refresh()
		value:set(Settings.keyLabel(PlayerSettings.get().keys[action.id]))
	end

	-- Activated fires on release, so the click that starts listening doesn't count.
	row.Activated:Connect(function()
		SettingsPanel.stop()
		value:set("PRESS A KEY")
		listening = UserInputService.InputBegan:Connect(function(input)
			local keyName
			if input.UserInputType == Enum.UserInputType.Keyboard then
				keyName = input.KeyCode.Name
			elseif input.UserInputType == Enum.UserInputType.MouseButton2 then
				keyName = "MouseButton2"
			elseif input.UserInputType == Enum.UserInputType.MouseButton1 then
				if not over then -- a click elsewhere cancels
					SettingsPanel.stop()
					refresh()
					return
				end
				keyName = "MouseButton1"
			else
				return
			end
			SettingsPanel.stop()
			if bindKey(action.id, keyName) then
				SettingsPanel.showKeys(content)
			else
				value:set("CANT USE THAT KEY")
				task.delay(MESSAGE_TIME, function()
					if row.Parent and not listening then
						refresh()
					end
				end)
			end
		end)
	end)
end

function SettingsPanel.showKeys(content: Frame)
	SettingsPanel.stop()
	content:ClearAllChildren()
	title(content, "KEYBINDS")
	line(content, "RESET", RIGHT, 0.13, true)
	line(content, "BACK", MARGIN, 0.13)
	hitBox(content, RIGHT - 0.06, 0.112, 0.06, 0.026).Activated:Connect(function()
		PlayerSettings.set({ keys = Settings.new().keys })
		PlayerSettings.send()
		SettingsPanel.showKeys(content)
	end)
	hitBox(content, MARGIN, 0.112, 0.06, 0.026).Activated:Connect(function()
		showMain(content)
	end)
	for index, action in Settings.actions do
		keyRow(content, action, KEY_LIST_TOP + index * KEY_STEP)
	end
end

showMain = function(content: Frame)
	SettingsPanel.stop()
	content:ClearAllChildren()
	title(content, "SETTINGS")
	heading(content, "SOUND", 0.132)
	slider(content, "MUSIC", "music", 0.164, 0.01, percent)
	slider(content, "GAME", "game", 0.196, 0.01, percent)
	slider(content, "MENU", "menu", 0.228, 0.01, percent)
	heading(content, "CONTROLS", 0.272)
	slider(content, "SENSITIVITY", "sensitivity", 0.304, 0.1, oneDecimal)
	slider(content, "LONGSCOPE", "scopeSensitivity", 0.336, 0.1, oneDecimal)
	slider(content, "FIELD OF VIEW", "fieldOfView", 0.368, 1, whole)

	local unit = MenuPanel.unit()
	local bar = hitBox(content, MARGIN, KEYBINDS_TOP, RIGHT - MARGIN, KEYBINDS_HEIGHT)
	bar.BackgroundTransparency = 0
	bar.BackgroundColor3 = PanelKit.INK
	bar.BorderSizePixel = 0
	bar.Activated:Connect(function()
		SettingsPanel.showKeys(content)
	end)
	local baseline = (KEYBINDS_HEIGHT + LABEL_SIZE) / 2 * unit
	local name = label(bar, "LabelBold", LABEL_SIZE, 0, 0)
	name:setPosition(UDim2.fromOffset(MARGIN * unit, baseline))
	name:setColor(PanelKit.PAPER)
	name:set("KEYBINDS")
	local arrow = label(bar, "LabelBold", LABEL_SIZE, 0, 0, true)
	arrow:setPosition(UDim2.new(1, -MARGIN * unit, 0, baseline))
	arrow:setColor(PanelKit.PAPER)
	arrow:set(">")
end

function SettingsPanel.fill(content: Frame)
	showMain(content)
end

return SettingsPanel
