-- The radio's strip on the HUD: a row of bars that move with the music, and the track's title and artist beside
-- them, in the top-left corner. River picked this layout from four mock-ups (docs/specs/radio.md).
-- When the track changes, the old title and artist slide left off the screen and the new ones slide in from
-- behind the bars: the text is cropped at the bars' edge, so it never crosses them. The strip is bright for a change and then dims.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Guns = ReplicatedStorage:WaitForChild("Guns")
local MusicBars = require(Guns:WaitForChild("MusicBars"))
local Palette = require(Guns:WaitForChild("Palette"))
local TypeLabel = require(script.Parent.TypeLabel)

-- Sizes are for a screen 1080 high and scale with it.
local LEFT, TOP = 22, 14
local BARS = 9
local BAR_WIDTH, BAR_GAP = 5, 3
local BAR_HEIGHT = 40
local BAR_FLOOR = 3 -- a bar is never shorter than this
local TEXT_GAP = 14 -- from the bars to the text
local TEXT_INSET = 9 -- how far inside its window the text rests, so the window's edge sits just off the bars
local TITLE_SIZE, ARTIST_SIZE = 22, 17
local TITLE_LINE, ARTIST_LINE = 18, 39 -- baselines, down from the strip's top
local TRACKING = 0.08 -- of the text's size
local TEAL = Color3.fromRGB(60, 210, 200)
local ORANGE = Color3.fromRGB(255, 150, 60)
local ARTIST_COLOR = Color3.fromRGB(170, 176, 182)
local SLIDE_OUT, SLIDE_IN = 0.25, 0.35 -- seconds
local BRIGHT_SECONDS = 4 -- how long the strip stays bright after a change
local DIM = 0.45 -- its transparency once it has settled
local DIM_SECONDS = 0.8
local OFF_TEXT = "RADIO OFF"

local RadioHud = {}
RadioHud.__index = RadioHud

function RadioHud.new()
	local self = setmetatable({}, RadioHud)
	-- Everything is laid out for a screen 1080 high, and one scale on the root fits it to the real screen. (The
	-- first version measured the screen once as the script started, when it was still a pixel high, and built
	-- the whole strip at no size.)
	local unit = 1
	self.unit = unit
	self.levels = table.create(BARS, 0)
	self.changes = 0 -- counts changes, so a slide that's been overtaken stops

	local gui = Instance.new("ScreenGui")
	gui.Name = "RadioHud"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 2
	self.gui = gui

	-- One group, so the whole strip can dim together. It starts at the screen's left edge so sliding text
	-- leaves the screen, not the group.
	local root = Instance.new("Frame")
	root.BackgroundTransparency = 1
	root.Size = UDim2.fromScale(1, 1)
	root.Parent = gui
	local scale = Instance.new("UIScale")
	scale.Parent = root
	local function fit()
		scale.Scale = math.max(workspace.CurrentCamera.ViewportSize.Y / 1080, 0.01)
	end
	fit()
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(fit)

	local group = Instance.new("CanvasGroup")
	group.BackgroundTransparency = 1
	group.Position = UDim2.fromOffset(0, TOP * unit)
	group.Size = UDim2.fromOffset(900 * unit, (BAR_HEIGHT + 8) * unit)
	group.Parent = root
	self.group = group

	local barsWide = BARS * BAR_WIDTH + (BARS - 1) * BAR_GAP
	-- The words live in a window that starts just past the bars and crops whatever leaves it. Sliding left,
	-- they vanish at the bars' edge as if going behind them, and new words come out from that same edge.
	-- (River's ask: the visualizer is "off the screen" for the text.)
	local window = Instance.new("Frame")
	window.BackgroundTransparency = 1
	window.ClipsDescendants = true
	window.Position = UDim2.fromOffset((LEFT + barsWide + TEXT_GAP - TEXT_INSET) * unit, 0)
	window.Size = UDim2.fromOffset(760 * unit, (BAR_HEIGHT + 8) * unit)
	window.Parent = group
	self.textHome = TEXT_INSET * unit -- where the words rest, inside the window
	local text = Instance.new("Frame")
	text.BackgroundTransparency = 1
	text.Position = UDim2.fromOffset(self.textHome, 0)
	text.Size = UDim2.fromOffset(700 * unit, (BAR_HEIGHT + 8) * unit)
	text.Parent = window
	self.text = text
	self.title = TypeLabel.new(text, {
		style = "LabelBold",
		size = TITLE_SIZE * unit,
		tracking = TITLE_SIZE * TRACKING * unit,
		color = Palette.Bone,
		position = UDim2.fromOffset(0, TITLE_LINE * unit),
	})
	self.artist = TypeLabel.new(text, {
		style = "Label",
		size = ARTIST_SIZE * unit,
		tracking = ARTIST_SIZE * TRACKING * unit,
		color = ARTIST_COLOR,
		position = UDim2.fromOffset(0, ARTIST_LINE * unit),
	})

	self.bars = {}
	for index = 1, BARS do
		local bar = Instance.new("Frame")
		bar.BorderSizePixel = 0
		bar.BackgroundColor3 = if index % 3 == 0 then ORANGE else TEAL
		bar.AnchorPoint = Vector2.new(0, 1)
		bar.Position = UDim2.fromOffset((LEFT + (index - 1) * (BAR_WIDTH + BAR_GAP)) * unit, BAR_HEIGHT * unit)
		bar.Size = UDim2.fromOffset(BAR_WIDTH * unit, BAR_FLOOR * unit)
		bar.ZIndex = 2
		bar.Parent = group
		self.bars[index] = bar
	end

	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	return self
end

function RadioHud:setVisible(visible: boolean)
	self.gui.Enabled = visible
end

-- Bright now, dim after a while, unless something else has changed by then.
local function brighten(self: any, change: number)
	self.group.GroupTransparency = 0
	task.delay(BRIGHT_SECONDS, function()
		if self.changes == change then
			TweenService:Create(self.group, TweenInfo.new(DIM_SECONDS), { GroupTransparency = DIM }):Play()
		end
	end)
end

-- Slides the old words out to the left and these in from the left.
function RadioHud:show(title: string, artist: string)
	self.changes += 1
	local change = self.changes
	local text = self.text
	local off = UDim2.fromOffset(-(math.max(self.title:width(), self.artist:width()) + 12 * self.unit), 0)
	local out = TweenService:Create(text, TweenInfo.new(SLIDE_OUT, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Position = off })
	out:Play()
	task.delay(SLIDE_OUT, function()
		if self.changes ~= change then
			return
		end
		self.title:set(title)
		self.artist:set(artist)
		local wide = math.max(self.title:width(), self.artist:width())
		text.Position = UDim2.fromOffset(-(wide + 12 * self.unit), 0)
		TweenService:Create(text, TweenInfo.new(SLIDE_IN, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
			Position = UDim2.fromOffset(self.textHome, 0),
		}):Play()
	end)
	brighten(self, change)
end

function RadioHud:showOff()
	self:show(OFF_TEXT, "")
end

-- Moves the bars. loudness is the track's PlaybackLoudness, or 0 when nothing plays.
function RadioHud:update(dt: number, loudness: number)
	local now = os.clock()
	for index, bar in self.bars do
		local target = MusicBars.level(loudness, index, BARS, now)
		local level = MusicBars.ease(self.levels[index], target, dt)
		self.levels[index] = level
		bar.Size = UDim2.fromOffset(BAR_WIDTH * self.unit, math.max(BAR_FLOOR, level * BAR_HEIGHT) * self.unit)
	end
end

return RadioHud
