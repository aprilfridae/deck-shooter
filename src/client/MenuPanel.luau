-- The Outpost's side panel: a Bone sheet that slides over the right half of the screen.
-- It swings in with some weight, with plain copies of its shape standing in for motion blur.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Guns = ReplicatedStorage:WaitForChild("Guns")
local Palette = require(Guns:WaitForChild("Palette"))
local PanelMotion = require(Guns:WaitForChild("Hud"):WaitForChild("PanelMotion"))

local PANEL_WIDTH = 0.5 -- share of the screen
local BLEED = 0.05 -- extra sheet off the right edge, so swinging past its mark shows no gap
local PANEL_LAYER = 10 -- above its copies

local MenuPanel = {}
MenuPanel.__index = MenuPanel

-- The title screen's unit: the screen's width, or 16/9 of its height on wider screens.
function MenuPanel.unit(): number
	local size = Workspace.CurrentCamera.ViewportSize
	return math.min(size.X, size.Y * 16 / 9)
end

local function sheet(parent: Instance): Frame
	local frame = Instance.new("Frame")
	frame.BorderSizePixel = 0
	frame.BackgroundColor3 = Palette.Bone
	frame.Size = UDim2.fromScale(PANEL_WIDTH + BLEED, 1)
	frame.Visible = false
	frame.Parent = parent
	return frame
end

local function place(frame: Frame, share: number)
	frame.Position = UDim2.fromScale(1 - PANEL_WIDTH * share, 0)
end

function MenuPanel.new(parent: Instance): any
	local self = setmetatable({}, MenuPanel)
	self.opening = false
	self.share = 0 -- 0 is closed, 1 is open
	self.from = 0
	self.elapsed = 0

	self.clip = Instance.new("Frame")
	self.clip.BackgroundTransparency = 1
	self.clip.ClipsDescendants = true
	self.clip.Size = UDim2.fromScale(1, 1)
	self.clip.Parent = parent

	self.copies = {}
	for _ = 1, PanelMotion.COPIES do
		table.insert(self.copies, sheet(self.clip))
	end

	self.frame = sheet(self.clip)
	self.frame.Active = true -- clicks on the sheet stop here
	self.frame.ZIndex = PANEL_LAYER
	place(self.frame, 0)

	self.content = Instance.new("Frame")
	self.content.BackgroundTransparency = 1
	self.content.Size = UDim2.fromScale(PANEL_WIDTH / (PANEL_WIDTH + BLEED), 1)
	self.content.Parent = self.frame
	return self
end

function MenuPanel:clear()
	self.content:ClearAllChildren()
end

function MenuPanel:isOpen(): boolean
	return self.opening
end

function MenuPanel:showCopies(from: number, to: number)
	local trail = PanelMotion.trail(from, to)
	for index, copy in self.copies do
		local step = trail[index]
		copy.Visible = step ~= nil
		if step then
			place(copy, step.share)
			copy.BackgroundTransparency = step.transparency
		end
	end
end

function MenuPanel:step(dt: number)
	self.elapsed += dt
	local target = if self.opening then 1 else 0
	local share = PanelMotion.share(self.from, target, PanelMotion.held(self.elapsed))
	if share ~= self.share then
		self:showCopies(self.share, share)
		self.share = share
		place(self.frame, share)
	end
	-- The last frame is held too, so its copies get their moment.
	if self.elapsed >= PanelMotion.DURATION + 1 / PanelMotion.FPS then
		self:showCopies(share, share)
		self.frame.Visible = self.opening
		self.connection:Disconnect()
		self.connection = nil
	end
end

function MenuPanel:move(opening: boolean)
	if opening == self.opening and (self.connection or self.share == (if opening then 1 else 0)) then
		return
	end
	self.opening = opening
	self.frame.Visible = true
	-- Picks up from where the panel is, so a reversed move doesn't jump.
	self.from = self.share
	self.elapsed = 0
	if not self.connection then
		self.connection = RunService.RenderStepped:Connect(function(dt)
			self:step(dt)
		end)
	end
end

function MenuPanel:open()
	self:move(true)
end

function MenuPanel:close()
	self:move(false)
end

return MenuPanel
