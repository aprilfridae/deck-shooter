-- One row of the Outpost nav. Colour wipes across it in stepped frames with a fading copy behind,
-- the same way the panels move, and the name kicks right. Rows slide in one after another.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Guns = ReplicatedStorage:WaitForChild("Guns")
local Palette = require(Guns:WaitForChild("Palette"))
local PanelMotion = require(Guns:WaitForChild("Hud"):WaitForChild("PanelMotion"))
local TypeLabel = require(script.Parent.TypeLabel)

local WIPE_TIME = 0.2 -- seconds
local ENTER_TIME = 0.3 -- seconds
local ENTER_STAGGER = 0.06 -- seconds between rows
local KICK = 0.008 -- how far the name moves, as a share of the unit
local TEXT_SWAP = 0.5 -- of the wipe, when the text changes colour
local COPY_FADE = 0.55
local RULE_FADE = 0.8
local NUMBER_SIZE = 0.8 -- of the name's size

export type Options = {
	parent: Instance,
	name: string,
	index: number,
	unit: number,
	width: number,
	height: number,
	padding: number,
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

local function stepped(elapsed: number, duration: number): number
	local frame = math.floor(elapsed * PanelMotion.FPS + 1e-6)
	return math.min(frame / PanelMotion.FPS / duration, 1)
end

function NavButton.new(options: Options): any
	local self = setmetatable({}, NavButton)
	self.active = false
	self.hovering = false
	self.pressed = false
	self.share = 0
	self.from = 0
	self.elapsed = 0
	self.width = options.width
	self.index = options.index
	self.top = (options.index - 1) * options.height
	self.padding = options.padding
	self.baseline = (options.height + options.textSize) / 2
	self.kick = KICK * options.unit

	self.button = Instance.new("TextButton")
	self.button.Text = ""
	self.button.AutoButtonColor = false
	self.button.BackgroundColor3 = Palette.DeepNavy
	self.button.BorderSizePixel = 0
	self.button.ClipsDescendants = true
	self.button.Position = UDim2.fromOffset(0, self.top)
	self.button.Size = UDim2.fromOffset(options.width, options.height)
	self.button.Parent = options.parent

	self.copy = wipeFrame(self.button, Palette.DataCyan)
	self.copy.BackgroundTransparency = COPY_FADE
	self.wipe = wipeFrame(self.button, Palette.Bone)

	self.text = TypeLabel.new(self.button, {
		style = "LabelBold",
		size = options.textSize,
		tracking = options.tracking,
		color = Palette.Bone,
		shadow = false,
		position = UDim2.fromOffset(options.padding, self.baseline),
	})
	self.text:set(options.name)
	self.mark = TypeLabel.new(self.button, {
		style = "Label",
		size = options.textSize * NUMBER_SIZE,
		tracking = options.tracking,
		color = Palette.Bone,
		right = true,
		shadow = false,
		position = UDim2.new(1, -options.padding, 0, self.baseline),
	})
	self.number = string.format("%02d", options.index)
	self.mark:set(self.number)

	if options.index > 1 then
		local rule = Instance.new("Frame")
		rule.BorderSizePixel = 0
		rule.BackgroundColor3 = Palette.Bone
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
		self.pressed = false
		self:retarget()
	end)
	self.button.MouseButton1Down:Connect(function()
		self.pressed = true
		self:paint()
	end)
	self.button.MouseButton1Up:Connect(function()
		self.pressed = false
		self:paint()
	end)
	self.button.Activated:Connect(options.onClick)
	self:paint()
	return self
end

function NavButton:target(): number
	return if self.active or self.hovering then 1 else 0
end

function NavButton:paint()
	local lit = self.share > TEXT_SWAP
	local ink = if lit then Palette.DeepNavy else Palette.Bone
	self.text:setColor(ink)
	self.mark:setColor(ink)
	self.mark:set(if self:target() == 1 then ">" else self.number)
	self.wipe.BackgroundColor3 = if self.pressed
		then Palette.DataCyan
		elseif self.active then Palette.SignalAcid
		else Palette.Bone
	self.wipe.Size = UDim2.fromScale(math.min(self.share, 1), 1)
	self.text:setPosition(UDim2.fromOffset(self.padding + self.kick * self.share, self.baseline))
end

function NavButton:step(dt: number)
	self.elapsed += dt
	local target = self:target()
	local share = PanelMotion.share(self.from, target, stepped(self.elapsed, WIPE_TIME))
	if share ~= self.share then
		self.copy.Size = UDim2.fromScale(math.min(self.share, 1), 1)
		self.copy.Visible = true
		self.share = share
		self:paint()
	end
	if self.elapsed >= WIPE_TIME + 1 / PanelMotion.FPS then
		self.copy.Visible = false
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

-- Slides the row in from the left.
function NavButton:enter()
	if self.entering then
		self.entering:Disconnect()
	end
	local elapsed = -ENTER_STAGGER * (self.index - 1)
	self.button.Position = UDim2.fromOffset(-self.width, self.top)
	self.entering = RunService.RenderStepped:Connect(function(dt)
		elapsed += dt
		local progress = stepped(math.max(elapsed, 0), ENTER_TIME)
		local share = PanelMotion.share(0, 1, progress)
		self.button.Position = UDim2.fromOffset(self.width * (share - 1), self.top)
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
