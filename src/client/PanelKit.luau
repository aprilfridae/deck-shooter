-- The pieces every Outpost page is built from. Sizes and places are shares of the unit.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Palette = require(ReplicatedStorage:WaitForChild("Guns"):WaitForChild("Palette"))
local MenuPanel = require(script.Parent.MenuPanel)
local TypeLabel = require(script.Parent.TypeLabel)

local TRACKING = 0.002
local TITLE_SIZE = 0.085
local TITLE_LINE = 0.095
local RULE_FADE = 0.5
local PRESSED_SHRINK = 0.97
local QUIET_HOVER = 3 -- pixels

local PanelKit = {
	MARGIN = 0.025,
	RIGHT = 0.475,
	LABEL_SIZE = 0.0125,
	HEADING_SIZE = 0.011,
	SMALL_SIZE = 0.0105,
	RULE_LINE = 0.108,
	CAP_HEIGHT = 0.7, -- of a font's size, for all three fonts
	TITLE_INSET = 0.055, -- of the size: the blank space left of a Title letter
	NAVY = Palette.DeepNavy,
}

local NAVY = PanelKit.NAVY

function PanelKit.label(parent: Instance, style: string, size: number, x: number, y: number, right: boolean?, color: Color3?): any
	local unit = MenuPanel.unit()
	return TypeLabel.new(parent, {
		style = style,
		size = size * unit,
		tracking = TRACKING * unit,
		color = color or NAVY,
		right = right,
		shadow = false,
		position = UDim2.fromOffset(x * unit, y * unit),
	})
end

function PanelKit.line(parent: Instance, text: string, x: number, y: number, right: boolean?): any
	local drawn = PanelKit.label(parent, "Label", PanelKit.LABEL_SIZE, x, y, right)
	drawn:set(text)
	return drawn
end

function PanelKit.heading(parent: Instance, text: string, y: number): any
	local drawn = PanelKit.label(parent, "LabelBold", PanelKit.HEADING_SIZE, PanelKit.MARGIN, y)
	drawn:set(text)
	return drawn
end

function PanelKit.rule(parent: Instance, x: number, y: number, width: number): Frame
	local unit = MenuPanel.unit()
	local rule = Instance.new("Frame")
	rule.BorderSizePixel = 0
	rule.BackgroundColor3 = NAVY
	rule.BackgroundTransparency = RULE_FADE
	rule.Position = UDim2.fromOffset(x * unit, y * unit)
	rule.Size = UDim2.fromOffset(width * unit, 1)
	rule.Parent = parent
	return rule
end

function PanelKit.title(parent: Instance, text: string)
	local unit = MenuPanel.unit()
	local big = TypeLabel.new(parent, {
		style = "Title",
		size = TITLE_SIZE * unit,
		tracking = 0,
		color = NAVY,
		shadow = false,
		position = UDim2.fromOffset((PanelKit.MARGIN - TITLE_SIZE * PanelKit.TITLE_INSET) * unit, TITLE_LINE * unit),
	})
	big:set(text)
	PanelKit.rule(parent, PanelKit.MARGIN, PanelKit.RULE_LINE, PanelKit.RIGHT - PanelKit.MARGIN)
end

function PanelKit.block(parent: Instance, x: number, top: number, width: number, height: number, color: Color3): Frame
	local unit = MenuPanel.unit()
	local frame = Instance.new("Frame")
	frame.BorderSizePixel = 0
	frame.BackgroundColor3 = color
	frame.Position = UDim2.fromOffset(x * unit, top * unit)
	frame.Size = UDim2.fromOffset(width * unit, height * unit)
	frame.Parent = parent
	return frame
end

function PanelKit.hitBox(parent: Instance, x: number, top: number, width: number, height: number): TextButton
	local unit = MenuPanel.unit()
	local button = Instance.new("TextButton")
	button.Text = ""
	button.AutoButtonColor = false
	button.BackgroundTransparency = 1
	button.BorderSizePixel = 0
	button.Position = UDim2.fromOffset(x * unit, top * unit)
	button.Size = UDim2.fromOffset(width * unit, height * unit)
	button.Parent = parent
	return button
end

-- A labelled button that inverts under the mouse and dips when pressed.
-- active leaves it in Signal Acid, and disabled greys it out and stops clicks. quiet thickens the
-- border instead of inverting, for buttons with their own contents.
function PanelKit.button(
	parent: Instance,
	text: string,
	x: number,
	top: number,
	width: number,
	height: number,
	options: { active: boolean?, disabled: boolean?, quiet: boolean?, size: number? }?
): TextButton
	local choice = options or {}
	local unit = MenuPanel.unit()
	local size = choice.size or PanelKit.LABEL_SIZE
	local button = PanelKit.hitBox(parent, x, top, width, height)
	button.BackgroundTransparency = if choice.disabled then 0.9 else 0
	button.BackgroundColor3 = if choice.disabled then NAVY elseif choice.active then Palette.SignalAcid else Palette.Bone
	local stroke = Instance.new("UIStroke")
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Color = NAVY
	stroke.Transparency = if choice.disabled then 0.7 else 0
	stroke.Parent = button
	local scale = Instance.new("UIScale")
	scale.Parent = button
	local word = PanelKit.label(button, "LabelBold", size, 0, 0)
	word:setPosition(UDim2.new(0.5, 0, 0, (height + size) / 2 * unit))
	word:set(text)
	word:setPosition(UDim2.new(0.5, -word:width() / 2, 0, (height + size) / 2 * unit))
	if choice.disabled then
		button.Active = false
		button.Interactable = false
		return button
	end
	local rest = button.BackgroundColor3
	button.MouseEnter:Connect(function()
		if choice.quiet then
			stroke.Thickness = QUIET_HOVER
		else
			button.BackgroundColor3 = NAVY
			word:setColor(Palette.Bone)
		end
	end)
	button.MouseLeave:Connect(function()
		stroke.Thickness = 1
		button.BackgroundColor3 = rest
		word:setColor(NAVY)
		scale.Scale = 1
	end)
	button.MouseButton1Down:Connect(function()
		scale.Scale = PRESSED_SHRINK
	end)
	button.MouseButton1Up:Connect(function()
		scale.Scale = 1
	end)
	return button
end

return PanelKit
