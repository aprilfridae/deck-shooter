-- The Outpost's side panel: a Bone sheet that slides over the right half of the screen.
-- It swings in with some weight, with plain copies of its shape standing in for motion blur.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Guns = ReplicatedStorage:WaitForChild("Guns")
local Palette = require(Guns:WaitForChild("Palette"))
local PanelMotion = require(Guns:WaitForChild("Hud"):WaitForChild("PanelMotion"))
local PanelGlow = require(script.Parent.PanelGlow)

local PANEL_WIDTH = 0.5 -- share of the screen
local BLEED = 0.05 -- extra sheet off the right edge, so swinging past its mark shows no gap
local PANEL_LAYER = 10 -- above its copies
local STEP_NAME = "OutpostMenuPanel"

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
	frame.BackgroundColor3 = Palette.DeepNavy
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
	self.moving = false
	self.share = 0 -- 0 is closed, 1 is open
	self.travel = 0 -- how far the panel went over one blur frame, opening being positive
	self.blurLeft = 1 -- how much of the blur shows, which a closing panel fades early
	self.view = 0 -- where the camera is, which moves smoothly while the panel steps
	self.viewTravel = 0 -- how far the camera went over the length of one panel frame
	self.viewFrom = 0
	self.shake = PanelMotion.landShake(PanelMotion.SHAKE_TIME) -- none yet
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

	self.glow = PanelGlow.new(self.clip)

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
			copy.BackgroundTransparency = 1 - (1 - step.transparency) * self.blurLeft
		end
	end
end

function MenuPanel:step(dt: number)
	self.elapsed += dt
	local target = if self.opening then 1 else 0
	local function shareAt(elapsed: number): number
		return PanelMotion.share(self.from, target, math.clamp(elapsed / PanelMotion.DURATION, 0, 1))
	end
	local share = shareAt(self.elapsed)
	-- Blur is measured over a fixed stretch of time, so it looks the same at any frame rate.
	local before = shareAt(self.elapsed - 1 / PanelMotion.FPS)
	local progress = math.min(self.elapsed / PanelMotion.DURATION, 1)
	self.blurLeft = if self.opening then 1 else PanelMotion.closeFade(progress)
	local function viewAt(elapsed: number): number
		return PanelMotion.viewShare(self.viewFrom, target, math.clamp(elapsed / PanelMotion.DURATION, 0, 1))
	end
	self.view = viewAt(self.elapsed)
	self.viewTravel = self.view - viewAt(self.elapsed - 1 / PanelMotion.FPS)
	self.travel = share - before
	self.share = share
	place(self.frame, share)
	self:showCopies(before, share)
	self.glow:show(1 - PANEL_WIDTH * share, self.travel * self.blurLeft)
	local held = self.elapsed >= PanelMotion.DURATION + 1 / PanelMotion.FPS
	-- A closing sheet lands hard, so it runs on a little longer to shake the view.
	local sinceLanding = self.elapsed - PanelMotion.DURATION
	self.shake = PanelMotion.landShake(if self.opening then PanelMotion.SHAKE_TIME else sinceLanding)
	if held and (self.opening or sinceLanding >= PanelMotion.SHAKE_TIME) then
		self.frame.Visible = self.opening
		self.moving = false
		RunService:UnbindFromRenderStep(STEP_NAME)
	end
end

function MenuPanel:move(opening: boolean)
	if opening == self.opening and (self.moving or self.share == (if opening then 1 else 0)) then
		return
	end
	self.opening = opening
	self.frame.Visible = true
	-- Picks up from where the panel is, so a reversed move doesn't jump.
	self.from = self.share
	self.viewFrom = self.view
	self.elapsed = 0
	if not self.moving then
		self.moving = true
		-- Steps just before MenuCamera reads it.
		RunService:BindToRenderStep(STEP_NAME, Enum.RenderPriority.Camera.Value, function(dt)
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
