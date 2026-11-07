-- The glow on the panel's left edge while it moves.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Guns = ReplicatedStorage:WaitForChild("Guns")
local Palette = require(Guns:WaitForChild("Palette"))
local PanelMotion = require(Guns:WaitForChild("Hud"):WaitForChild("PanelMotion"))

local GLOW_LAYER = 4 -- under the panel
local GLOW_WIDTH = 0.14 -- share of the screen
local GLOW_STRENGTH = 0.75 -- 1 is solid at the panel's edge

local PanelGlow = {}
PanelGlow.__index = PanelGlow

function PanelGlow.new(parent: Instance): any
	local self = setmetatable({}, PanelGlow)
	self.frame = Instance.new("Frame")
	self.frame.AnchorPoint = Vector2.new(1, 0)
	self.frame.BackgroundColor3 = Palette.Bone
	self.frame.BorderSizePixel = 0
	self.frame.Size = UDim2.fromScale(GLOW_WIDTH, 1)
	self.frame.ZIndex = GLOW_LAYER
	self.frame.Visible = false
	self.frame.Parent = parent
	local gradient = Instance.new("UIGradient")
	gradient.Transparency = NumberSequence.new(1, 0)
	gradient.Parent = self.frame
	return self
end

-- edge is where the panel's left side is, as a share of the screen's width.
function PanelGlow:show(edge: number, travel: number)
	local glow = PanelMotion.glow(travel)
	self.frame.Visible = glow > 0
	self.frame.Position = UDim2.fromScale(edge, 0)
	self.frame.BackgroundTransparency = 1 - GLOW_STRENGTH * glow
end

function PanelGlow:hide()
	self.frame.Visible = false
end

return PanelGlow
