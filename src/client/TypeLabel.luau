-- A piece of text on screen, drawn from the font sheets. Roblox can't import font files.
local Palette = require(game:GetService("ReplicatedStorage"):WaitForChild("Guns"):WaitForChild("Palette"))
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Hud = ReplicatedStorage:WaitForChild("Guns"):WaitForChild("Hud")
local FontImages = require(Hud:WaitForChild("FontImages"))
local GlyphData = require(Hud:WaitForChild("GlyphData"))
local TypeLayout = require(Hud:WaitForChild("TypeLayout"))

local SHADOW_COLOR = Palette.DeepNavy
local SHADOW_OFFSET = Vector2.new(1, 2)

export type Options = {
	style: string,
	size: number,
	tracking: number,
	color: Color3,
	right: boolean?,
	position: UDim2,
}

local TypeLabel = {}
TypeLabel.__index = TypeLabel

local function piece(self: any, color: Color3, layer: number): ImageLabel
	local image = Instance.new("ImageLabel")
	image.BackgroundTransparency = 1
	image.Image = FontImages[self.style]
	image.ImageColor3 = color
	image.ZIndex = layer
	image.Parent = self.frame
	return image
end

-- The frame's origin sits on the baseline. Its own scale means letters are placed in whole
-- sheet pixels, so small text doesn't drift from rounding.
function TypeLabel.new(parent: GuiObject, options: Options): any
	local self = setmetatable({}, TypeLabel)
	self.style = options.style
	self.size = options.size
	self.tracking = options.tracking
	self.color = options.color
	self.right = options.right
	self.text = ""
	self.textWidth = 0
	self.pieces = {}
	self.source = GlyphData[options.style].source

	self.frame = Instance.new("Frame")
	self.frame.BackgroundTransparency = 1
	self.frame.Position = options.position
	self.frame.Parent = parent

	local scale = Instance.new("UIScale")
	scale.Scale = options.size / self.source
	scale.Parent = self.frame
	return self
end

function TypeLabel:set(text: string)
	if text == self.text then
		return
	end
	self.text = text
	local width, placed = TypeLayout.lay(text, self.style, self.size, self.tracking)
	self.textWidth = width
	local toSheet = self.source / self.size
	local start = if self.right then -width else 0
	local shadowX = math.round(SHADOW_OFFSET.X * toSheet)
	local shadowY = math.round(SHADOW_OFFSET.Y * toSheet)
	for index, glyph in placed do
		local pair = self.pieces[index]
		if not pair then
			pair = { shadow = piece(self, SHADOW_COLOR, 1), glyph = piece(self, self.color, 2) }
			self.pieces[index] = pair
		end
		local x = math.round((start + glyph.x) * toSheet)
		local y = math.round(glyph.y * toSheet)
		for _, image in pair do
			image.ImageRectOffset = Vector2.new(glyph.rectX, glyph.rectY)
			image.ImageRectSize = Vector2.new(glyph.rectW, glyph.rectH)
			image.Size = UDim2.fromOffset(glyph.rectW, glyph.rectH)
			image.Visible = true
		end
		pair.glyph.Position = UDim2.fromOffset(x, y)
		pair.shadow.Position = UDim2.fromOffset(x + shadowX, y + shadowY)
	end
	for index = #placed + 1, #self.pieces do
		self.pieces[index].shadow.Visible = false
		self.pieces[index].glyph.Visible = false
	end
end

function TypeLabel:width(): number
	return self.textWidth
end

function TypeLabel:setColor(color: Color3)
	if color == self.color then
		return
	end
	self.color = color
	for _, pair in self.pieces do
		pair.glyph.ImageColor3 = color
	end
end

function TypeLabel:setPosition(position: UDim2)
	self.frame.Position = position
end

function TypeLabel:setVisible(visible: boolean)
	self.frame.Visible = visible
end

return TypeLabel
