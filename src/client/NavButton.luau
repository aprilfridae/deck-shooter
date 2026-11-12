-- One button of the Outpost nav: a solid slanted plate (docs/specs/hud-redesign.md). Bone with navy text at rest;
-- under the mouse or open it flips to navy with a Bone outline, and the name kicks right. Buttons slide in one
-- after another.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Guns = ReplicatedStorage:WaitForChild("Guns")
local Palette = require(Guns:WaitForChild("Palette"))
local HudShapes = require(Guns:WaitForChild("Hud"):WaitForChild("HudShapes"))
local PanelMotion = require(Guns:WaitForChild("Hud"):WaitForChild("PanelMotion"))
local TypeLabel = require(script.Parent.TypeLabel)

local KICK_TIME = 0.28 -- seconds
local ENTER_TIME = 0.3 -- seconds
local ENTER_STAGGER = 0.06 -- seconds between buttons
local KICK = 0.006 -- how far the name moves, as a share of the unit
local NUMBER_SIZE = 0.8 -- of the name's size

export type Options = {
	parent: Instance, -- clips, so buttons slide in from its left edge
	name: string,
	index: number,
	unit: number,
	width: number,
	height: number,
	gap: number, -- between one button and the next
	left: number, -- from the button's left edge to its name: past the plate's slanted end
	padding: number, -- from the button's right edge to its number
	textSize: number,
	tracking: number,
	onClick: () -> (),
	onHover: () -> (),
}

local NavButton = {}
NavButton.__index = NavButton

local function shape(parent: Instance, image: string, color: Color3): ImageLabel
	local label = Instance.new("ImageLabel")
	label.BackgroundTransparency = 1
	label.Image = image
	label.ImageColor3 = color
	label.Size = UDim2.fromScale(1, 1)
	label.Parent = parent
	return label
end

local function stepped(elapsed: number, duration: number): number
	local frame = math.floor(elapsed * PanelMotion.FPS + 1e-6)
	return math.min(frame / PanelMotion.FPS / duration, 1)
end

function NavButton.new(options: Options): any
	local self = setmetatable({}, NavButton)
	self.active = false
	self.hovering = false
	self.share = 0 -- how far the name has kicked, 0 to 1
	self.from = 0
	self.elapsed = 0
	self.width = options.width
	self.index = options.index
	self.top = (options.index - 1) * (options.height + options.gap)
	self.left = options.left
	self.baseline = (options.height + options.textSize) / 2
	self.kick = KICK * options.unit

	self.button = Instance.new("TextButton")
	self.button.Text = ""
	self.button.AutoButtonColor = false
	self.button.BackgroundTransparency = 1
	self.button.BorderSizePixel = 0
	self.button.Position = UDim2.fromOffset(0, self.top)
	self.button.Size = UDim2.fromOffset(options.width, options.height)
	self.button.Parent = options.parent

	self.plate = shape(self.button, HudShapes.Plate, Palette.Bone)
	self.outline = shape(self.button, HudShapes.PlateOutline, Palette.Bone)

	self.text = TypeLabel.new(self.button, {
		style = "LabelBold",
		size = options.textSize,
		tracking = options.tracking,
		color = Palette.DeepNavy,
		shadow = false,
		position = UDim2.fromOffset(options.left, self.baseline),
	})
	self.text:set(options.name)
	self.mark = TypeLabel.new(self.button, {
		style = "Label",
		size = options.textSize * NUMBER_SIZE,
		tracking = options.tracking,
		color = Palette.DeepNavy,
		right = true,
		shadow = false,
		position = UDim2.new(1, -options.padding, 0, self.baseline),
	})
	self.number = string.format("%02d", options.index)
	self.mark:set(self.number)

	self.button.MouseEnter:Connect(function()
		self.hovering = true
		options.onHover()
		self:retarget()
	end)
	self.button.MouseLeave:Connect(function()
		self.hovering = false
		self:retarget()
	end)
	self.button.Activated:Connect(options.onClick)
	self:paint()
	return self
end

function NavButton:target(): number
	return if self.active or self.hovering then 1 else 0
end

-- The colours flip at once. Only the name's kick takes time.
function NavButton:paint()
	local lit = self:target() == 1
	local ink = if lit then Palette.Bone else Palette.DeepNavy
	self.plate.ImageColor3 = if lit then Palette.DeepNavy else Palette.Bone
	self.outline.Visible = lit
	self.text:setColor(ink)
	self.mark:setColor(ink)
	self.mark:set(if lit then ">" else self.number)
	self.text:setPosition(UDim2.fromOffset(self.left + self.kick * self.share, self.baseline))
end

function NavButton:step(dt: number)
	self.elapsed += dt
	local share = PanelMotion.share(self.from, self:target(), stepped(self.elapsed, KICK_TIME))
	if share ~= self.share then
		self.share = share
		self:paint()
	end
	if self.elapsed >= KICK_TIME + 1 / PanelMotion.FPS then
		self.connection:Disconnect()
		self.connection = nil
	end
end

-- Starts the kick from wherever it is, so a quick pass of the mouse doesn't jump.
function NavButton:retarget()
	self.from = self.share
	self.elapsed = 0
	self:paint()
	if not self.connection then
		self.connection = RunService.RenderStepped:Connect(function(dt)
			self:step(dt)
		end)
	end
end

function NavButton:setActive(active: boolean)
	if active ~= self.active then
		self.active = active
		self:retarget()
	end
end

-- Slides the button in from the left.
function NavButton:enter()
	if self.entering then
		self.entering:Disconnect()
	end
	local elapsed = -ENTER_STAGGER * (self.index - 1)
	self.button.Position = UDim2.fromOffset(-self.width, self.top)
	self.entering = RunService.RenderStepped:Connect(function(dt)
		elapsed += dt
		local progress = stepped(math.max(elapsed, 0), ENTER_TIME)
		self.button.Position = UDim2.fromOffset(self.width * (PanelMotion.share(0, 1, progress) - 1), self.top)
		if progress >= 1 then
			self.entering:Disconnect()
			self.entering = nil
		end
	end)
end

function NavButton:destroy()
	if self.connection then
		self.connection:Disconnect()
	end
	if self.entering then
		self.entering:Disconnect()
	end
	self.button:Destroy()
end

return NavButton
