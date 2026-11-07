-- What the panel's left edge throws off while it moves: a glow, and bands of colour dragged out of
-- the sheet like sorted pixels. Roblox can't touch the picture's pixels, so these are plain frames.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Guns = ReplicatedStorage:WaitForChild("Guns")
local Palette = require(Guns:WaitForChild("Palette"))
local PanelMotion = require(Guns:WaitForChild("Hud"):WaitForChild("PanelMotion"))

local BAR_LAYER = 5 -- under the panel
local GLOW_LAYER = 4
local GLOW_WIDTH = 0.14 -- share of the screen
local GLOW_STRENGTH = 0.75 -- 1 is solid at the panel's edge
local CYAN_FROM = 0.7 -- bars past this are Data Cyan, the rest Bone
local ACID_FROM = 0.87 -- bars past this are Signal Acid

-- Hard steps along each bar, so it breaks up in blocks instead of fading smoothly.
local BAR_FADE = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 0.9),
	NumberSequenceKeypoint.new(0.25, 0.9),
	NumberSequenceKeypoint.new(0.2501, 0.65),
	NumberSequenceKeypoint.new(0.5, 0.65),
	NumberSequenceKeypoint.new(0.5001, 0.35),
	NumberSequenceKeypoint.new(0.75, 0.35),
	NumberSequenceKeypoint.new(0.7501, 0.1),
	NumberSequenceKeypoint.new(1, 0.1),
})

local PanelSmear = {}
PanelSmear.__index = PanelSmear

local function tintOf(tint: number): Color3
	if tint >= ACID_FROM then
		return Palette.SignalAcid
	elseif tint >= CYAN_FROM then
		return Palette.DataCyan
	end
	return Palette.Bone
end

local function strip(parent: Instance, fade: NumberSequence, layer: number): Frame
	local frame = Instance.new("Frame")
	frame.AnchorPoint = Vector2.new(1, 0)
	frame.BorderSizePixel = 0
	frame.ZIndex = layer
	frame.Visible = false
	frame.Parent = parent
	local gradient = Instance.new("UIGradient")
	gradient.Transparency = fade
	gradient.Parent = frame
	return frame
end

function PanelSmear.new(parent: Instance): any
	local self = setmetatable({}, PanelSmear)
	self.parent = parent
	self.bars = {}
	self.glow = strip(parent, NumberSequence.new(1, 0), GLOW_LAYER)
	self.glow.BackgroundColor3 = Palette.SignalAcid
	self.glow.Size = UDim2.fromScale(GLOW_WIDTH, 1)
	return self
end

-- edge is where the panel's left side is, as a share of the screen's width.
function PanelSmear:show(edge: number, travel: number)
	local rows = PanelMotion.smear(travel, math.random)
	for index, row in rows do
		local bar = self.bars[index]
		if not bar then
			bar = strip(self.parent, BAR_FADE, BAR_LAYER)
			self.bars[index] = bar
		end
		bar.BackgroundColor3 = tintOf(row.tint)
		bar.Position = UDim2.fromScale(edge, row.top)
		bar.Size = UDim2.fromScale(row.length, row.height)
		bar.Visible = true
	end
	for index = #rows + 1, #self.bars do
		self.bars[index].Visible = false
	end
	local glow = PanelMotion.glow(travel)
	self.glow.Visible = glow > 0
	self.glow.Position = UDim2.fromScale(edge, 0)
	self.glow.BackgroundTransparency = 1 - GLOW_STRENGTH * glow
end

function PanelSmear:hide()
	self:show(1, 0)
end

return PanelSmear
