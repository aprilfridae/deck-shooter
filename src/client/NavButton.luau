-- One row of the Outpost nav. Navy wipes across it in stepped frames with fading copies behind
-- and a glow ahead, the same way the panels move, and the name kicks right. Rows slide in one after
-- another.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Guns = ReplicatedStorage:WaitForChild("Guns")
local Palette = require(Guns:WaitForChild("Palette"))
local PanelMotion = require(Guns:WaitForChild("Hud"):WaitForChild("PanelMotion"))
local TypeLabel = require(script.Parent.TypeLabel)

local WIPE_TIME = 0.28 -- seconds
local ENTER_TIME = 0.3 -- seconds
local ENTER_STAGGER = 0.06 -- seconds between rows
local KICK = 0.008 -- how far the name moves, as a share of the unit
local TEXT_SWAP = 0.5 -- of the wipe, when the text changes colour
local GLOW_WIDTH = 0.05 -- how far the glow reaches ahead of the wipe, as a share of the unit
local HALO_WIDTH = 0.045 -- how far the glow spills past the row, as a share of the unit
local HALO_FROM = 0.75 -- of the wipe, when the glow reaches the end of the row
local GLOW_STRENGTH = 0.85 -- 1 is solid at its brightest
local RULE_FADE = 0.8
local NUMBER_SIZE = 0.8 -- of the name's size

export type Options = {
	parent: Instance,
	glowParent: Instance, -- isn't clipped, so the glow can spill out of the row
	name: string,
	index: number,
	unit: number,
	width: number,
	height: number,
	left: number, -- from the row's left edge to its name
	padding: number, -- from the row's right edge to its number
	textSize: number,
	tracking: number,
	onClick: () -> (),
	onHover: () -> (),
}

local NavButton = {}
NavButton.__index = NavButton

local function wipeFrame(parent: Instance, color: Color3): Frame
	local frame = Instance.new("Frame")
	frame.BorderSizePixel = 0
	frame.BackgroundColor3 = color
	frame.Size = UDim2.fromScale(0, 1)
	frame.Parent = parent
	return frame
end

local function glowFrame(parent: Instance, fade: NumberSequence): Frame
	local frame = Instance.new("Frame")
	frame.BackgroundColor3 = Palette.DeepNavy
	frame.BorderSizePixel = 0
	frame.Visible = false
	frame.Parent = parent
	local gradient = Instance.new("UIGradient")
	gradient.Transparency = fade
	gradient.Parent = frame
	return frame
end

local function stepped(elapsed: number, duration: number): number
	local frame = math.floor(elapsed * PanelMotion.FPS + 1e-6)
	return math.min(frame / PanelMotion.FPS / duration, 1)
end

function NavButton.new(options: Options): any
	local self = setmetatable({}, NavButton)
	self.active = false
	self.hovering = false
	self.share = 0
	self.from = 0
	self.elapsed = 0
	self.width = options.width
	self.index = options.index
	self.top = (options.index - 1) * options.height
	self.left = options.left
	self.baseline = (options.height + options.textSize) / 2
	self.kick = KICK * options.unit

	self.ghosts = {} -- blur behind the row while it slides in
	for _ = 1, PanelMotion.COPIES do
		local ghost = Instance.new("Frame")
		ghost.BackgroundColor3 = Palette.DeepNavy
		ghost.BorderSizePixel = 0
		ghost.Size = UDim2.fromOffset(options.width, options.height)
		ghost.Visible = false
		ghost.Parent = options.parent
		table.insert(self.ghosts, ghost)
	end

	self.button = Instance.new("TextButton")
	self.button.Text = ""
	self.button.AutoButtonColor = false
	self.button.BackgroundColor3 = Palette.Bone
	self.button.BorderSizePixel = 0
	self.button.ClipsDescendants = true
	self.button.Position = UDim2.fromOffset(0, self.top)
	self.button.Size = UDim2.fromOffset(options.width, options.height)
	self.button.Parent = options.parent

	self.copies = {}
	for _ = 1, PanelMotion.COPIES do
		table.insert(self.copies, wipeFrame(self.button, Palette.DeepNavy))
	end
	self.wipe = wipeFrame(self.button, Palette.DeepNavy)
	local fadeOut = NumberSequence.new(0, 1)
	self.glow = glowFrame(self.button, fadeOut)
	self.glow.Size = UDim2.new(0, GLOW_WIDTH * options.unit, 1, 0)
	self.halo = glowFrame(options.glowParent, fadeOut)
	self.halo.Position = UDim2.fromOffset(options.width, self.top)
	self.halo.Size = UDim2.fromOffset(HALO_WIDTH * options.unit, options.height)

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

	if options.index > 1 then
		local rule = Instance.new("Frame")
		rule.BorderSizePixel = 0
		rule.BackgroundColor3 = Palette.DeepNavy
		rule.BackgroundTransparency = RULE_FADE
		rule.Size = UDim2.new(1, 0, 0, 1)
		rule.Parent = self.button
	end

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

function NavButton:paint()
	local ink = if self.share > TEXT_SWAP then Palette.Bone else Palette.DeepNavy
	self.text:setColor(ink)
	self.mark:setColor(ink)
	self.mark:set(if self:target() == 1 then ">" else self.number)
	self.wipe.Size = UDim2.fromScale(math.min(self.share, 1), 1)
	self.text:setPosition(UDim2.fromOffset(self.left + self.kick * self.share, self.baseline))
end

-- The blur and glow for one frame of the wipe. A move of nothing clears them.
function NavButton:smear(from: number, to: number)
	local trail = PanelMotion.trail(from, to)
	for index, copy in self.copies do
		local step = trail[index]
		copy.Visible = step ~= nil
		if step then
			copy.Size = UDim2.fromScale(math.clamp(step.share, 0, 1), 1)
			copy.BackgroundTransparency = step.transparency
		end
	end
	local bright = PanelMotion.glow(to - from)
	local fade = 1 - GLOW_STRENGTH * bright
	self.glow.Visible = bright > 0
	self.glow.Position = UDim2.fromScale(math.min(to, 1), 0)
	self.glow.BackgroundTransparency = fade
	self.halo.Visible = bright > 0 and to >= HALO_FROM
	self.halo.BackgroundTransparency = fade
end

function NavButton:step(dt: number)
	self.elapsed += dt
	local target = self:target()
	local share = PanelMotion.share(self.from, target, stepped(self.elapsed, WIPE_TIME))
	if share ~= self.share then
		self:smear(self.share, share)
		self.share = share
		self:paint()
	end
	if self.elapsed >= WIPE_TIME + 1 / PanelMotion.FPS then
		self:smear(share, share)
		self.connection:Disconnect()
		self.connection = nil
	end
end

-- Starts the wipe from wherever it is, so a quick pass of the mouse doesn't jump.
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

function NavButton:showGhosts(from: number, to: number)
	local trail = PanelMotion.trail(from, to)
	for index, ghost in self.ghosts do
		local step = trail[index]
		ghost.Visible = step ~= nil
		if step then
			ghost.Position = UDim2.fromOffset(self.width * (step.share - 1), self.top)
			ghost.BackgroundTransparency = step.transparency
		end
	end
end

-- Slides the row in from the left.
function NavButton:enter()
	if self.entering then
		self.entering:Disconnect()
	end
	local elapsed = -ENTER_STAGGER * (self.index - 1)
	local last = 0
	self.button.Position = UDim2.fromOffset(-self.width, self.top)
	self.entering = RunService.RenderStepped:Connect(function(dt)
		elapsed += dt
		local progress = stepped(math.max(elapsed, 0), ENTER_TIME)
		local share = PanelMotion.share(0, 1, progress)
		self.button.Position = UDim2.fromOffset(self.width * (share - 1), self.top)
		if share ~= last then
			self:showGhosts(last, share)
			last = share
		end
		if progress >= 1 then
			self:showGhosts(share, share)
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
	self.halo:Destroy()
end

return NavButton
