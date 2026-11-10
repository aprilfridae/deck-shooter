-- The back of an unopened card, in its pack's colours. The card's real back would give away its name.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Guns = ReplicatedStorage:WaitForChild("Guns")
local CardMotion = require(Guns:WaitForChild("Hud"):WaitForChild("CardMotion"))
local CardEffects = require(script.Parent.CardEffects)
local PackFace = require(script.Parent.PackFace)
local TypeLabel = require(script.Parent.TypeLabel)

-- In card units: a card is 150 wide and 240 tall.
local WIDTH = 150
local HEIGHT = 240
local CORNER = 10
local FRAME_INSET = 6
local FRAME_CORNER = 6
local FRAME_THICKNESS = 1.5
local TOP_STRIPES = Rect.new(16, 16, 134, 30)
local BOTTOM_STRIPES = Rect.new(16, 210, 134, 224)
local SET_SIZE = 78
local SET_LINE = 136
local NAME_SIZE = 11
local NAME_LINE = 166
local NAME_TRACKING = 0.12 -- of the size
local RULE_LEFT = 40
local RULE_LINE = 174
local RULE_HEIGHT = 2
local SHINE_HALF_WIDTH = 0.07 -- of the gradient

local PackCardBack = {}

local function centredWords(root: GuiObject, unit: number, style: string, size: number, tracking: number, color: Color3, line: number, text: string)
	local words = TypeLabel.new(root, {
		style = style,
		size = size * unit,
		tracking = tracking * unit,
		color = color,
		shadow = false,
		position = UDim2.new(),
	})
	words:set(text)
	words:setPosition(UDim2.fromOffset((WIDTH * unit - words:width()) / 2, line * unit))
end

-- still leaves the moving shine off.
function PackCardBack.new(parent: Instance, pack: string, width: number, still: boolean?): Frame
	local look = PackFace.look(pack)
	local unit = width / WIDTH

	local root = Instance.new("Frame")
	root.Name = "PackCardBack"
	root.BackgroundColor3 = look.back
	root.BorderSizePixel = 0
	root.Size = UDim2.fromOffset(width, HEIGHT * unit)
	CardEffects.rounded(root, UDim.new(0, CORNER * unit))

	local inner = Instance.new("Frame")
	inner.BackgroundTransparency = 1
	inner.Position = UDim2.fromOffset(FRAME_INSET * unit, FRAME_INSET * unit)
	inner.Size = UDim2.new(1, -2 * FRAME_INSET * unit, 1, -2 * FRAME_INSET * unit)
	CardEffects.rounded(inner, UDim.new(0, FRAME_CORNER * unit))
	inner.Parent = root
	local line = Instance.new("UIStroke")
	line.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	line.Color = look.art
	line.Thickness = FRAME_THICKNESS * unit
	line.Parent = inner

	CardEffects.stripes(root, unit, look.art, TOP_STRIPES)
	CardEffects.stripes(root, unit, look.art, BOTTOM_STRIPES)
	centredWords(root, unit, "LabelLarge", SET_SIZE, 0, look.art, SET_LINE, "S1")
	centredWords(root, unit, "LabelBold", NAME_SIZE, NAME_SIZE * NAME_TRACKING, look.ink, NAME_LINE, "SPLIT DECK")

	local rule = Instance.new("Frame")
	rule.BackgroundColor3 = look.art
	rule.BorderSizePixel = 0
	rule.Position = UDim2.fromOffset(RULE_LEFT * unit, RULE_LINE * unit)
	rule.Size = UDim2.fromOffset((WIDTH - 2 * RULE_LEFT) * unit, RULE_HEIGHT * unit)
	rule.Parent = root

	root.Parent = parent
	if still then
		return root
	end

	local shine = CardEffects.band(root, CORNER * unit, SHINE_HALF_WIDTH, ColorSequence.new(Color3.new(1, 1, 1)), look.shine)
	CardEffects.animate(root, function(elapsed: number)
		shine.Offset = Vector2.new(CardMotion.shineOffset(elapsed), 0)
	end)
	return root
end

return PackCardBack
