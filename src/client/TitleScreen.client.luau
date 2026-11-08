-- The Split Deck title screen. It shows once per join and PLAY leads into the game.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Guns = ReplicatedStorage:WaitForChild("Guns")
local GunSounds = require(Guns:WaitForChild("GunSounds"))
local SoundGroups = require(script.Parent.SoundGroups)
local MenuState = require(Guns:WaitForChild("MenuState"))
local MusicBars = require(Guns:WaitForChild("MusicBars"))
local Palette = require(Guns:WaitForChild("Palette"))
local TypeLabel = require(script.Parent.TypeLabel)

-- Layout, as shares of the screen's width. Very wide screens use a 16:9 width, so nothing runs off the bottom.
local WIDE_SHAPE = 16 / 9
local MARGIN = 0.05
local TITLE_SIZE = 0.15
local SPLIT_LINE = 0.185
local DECK_LINE = 0.315
local RULE_LINE = 0.34
local RULE_WIDTH = 0.4
local MENU_SIZE = 0.017
local MENU_FIRST_LINE = 0.375
local MENU_SPACING = 0.036
local MENU_TRACKING = 0.004
local SOON_SIZE = 0.0105
local SOON_GAP = 0.015
local DETAIL_SIZE = 0.0125
local DETAIL_SPACING = 0.021
local DETAIL_TRACKING = 0.003
local BARCODE_WIDTH = 0.18
local BARCODE_HEIGHT = 0.04
local BARCODE_BARS = { 2, 4, 1, 3, 1, 5, 2, 1, 4, 2, 3, 1 } -- each bar's width, then the same gap
-- The cut runs from 68% along the top to 52% along the bottom of a 16:9 screen.
local CUT_MIDDLE = 0.6
local CUT_DEGREES = 15.9
local CUT_DRIFT = 0.018 -- share of the width the cut slides toward the cursor
local CUT_TILT = 2 -- degrees it leans with the cursor's height
local CUT_EASE = 5
local RULE_TRANSPARENCY = 0.65
local DIM_SHARE = 0.6 -- how far unbuilt buttons fade toward the navy
local PLAY_HIT_WIDTH = 0.16
local MUSIC_FADE_SECONDS = 0.6
local VISUALIZER_WIDTH = 0.3
local VISUALIZER_HEIGHT = 0.13
local VISUALIZER_GAP = 0.02 -- below the barcode
local VISUALIZER_BARS = 36
local VISUALIZER_SEGMENTS = 15
local SEGMENT_FILL = 0.7 -- of each slot, leaving the gaps

local player = Players.LocalPlayer
local controls = require(player:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule")):GetControls()
controls:Disable()

local gui = Instance.new("ScreenGui")
gui.Name = "TitleScreen"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 10
gui.Parent = player:WaitForChild("PlayerGui")

local screen = Instance.new("Frame")
screen.Size = UDim2.fromScale(1, 1)
screen.BackgroundColor3 = Palette.Bone
screen.BorderSizePixel = 0
screen.ClipsDescendants = true
screen.Active = true
screen.Parent = gui

local music = Instance.new("Sound")
music.Name = "MenuMusic"
music.SoundId = GunSounds.menuMusic
music.Looped = true
music.SoundGroup = SoundGroups.music
music.Parent = SoundService
music:Play()

local selectSound = Instance.new("Sound")
selectSound.Name = "MenuSelect"
selectSound.SoundId = GunSounds.menuSelect
selectSound.SoundGroup = SoundGroups.menu
selectSound.Parent = SoundService

local columns: { { Frame } } = {}
local navy: Frame? = nil
local cursor = Vector2.zero -- eased, -1 to 1 across the screen
local levels: { number } = table.create(VISUALIZER_BARS, 0)

local function bar(parent: Frame, color: Color3, x: number, y: number, width: number, height: number): Frame
	local frame = Instance.new("Frame")
	frame.Position = UDim2.fromOffset(x, y)
	frame.Size = UDim2.fromOffset(width, height)
	frame.BackgroundColor3 = color
	frame.BorderSizePixel = 0
	frame.Parent = parent
	return frame
end

local function text(parent: Frame, style: string, words: string, color: Color3, x: number, y: number, size: number, tracking: number, right: boolean?): any
	local label = TypeLabel.new(parent, {
		style = style,
		size = size,
		tracking = tracking,
		color = color,
		right = right,
		position = UDim2.fromOffset(x, y),
	})
	label:set(words)
	return label
end

-- A big navy frame rotates about its own centre, so its right edge lands on the cut.
local function placeNavy(width: number, height: number)
	if not navy then
		return
	end
	local degrees = CUT_DEGREES + cursor.Y * CUT_TILT
	local angle = math.rad(degrees)
	local size = navy.Size.X.Offset
	navy.Position = UDim2.fromOffset(
		width * (CUT_MIDDLE + cursor.X * CUT_DRIFT) - math.cos(angle) * size / 2,
		height / 2 - math.sin(angle) * size / 2
	)
	navy.Rotation = degrees
end

local function addNavy(parent: Frame, width: number, height: number)
	local size = (width + height) * 2
	local frame = Instance.new("Frame")
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Size = UDim2.fromOffset(size, size)
	frame.BackgroundColor3 = Palette.DeepNavy
	frame.BorderSizePixel = 0
	frame.Parent = parent
	navy = frame
	placeNavy(width, height)
end

local function addBarcode(parent: Frame, right: number, bottom: number, unit: number)
	local total = 0
	for _, bars in BARCODE_BARS do
		total += bars * 2
	end
	local step = BARCODE_WIDTH * unit / total
	local height = BARCODE_HEIGHT * unit
	local x = right - BARCODE_WIDTH * unit
	for _, bars in BARCODE_BARS do
		bar(parent, Palette.DeepNavy, x, bottom - height, bars * step, height)
		x += bars * 2 * step
	end
end

local function addVisualizer(parent: Frame, right: number, bottom: number, unit: number)
	local slotWidth = VISUALIZER_WIDTH * unit / VISUALIZER_BARS
	local slotHeight = VISUALIZER_HEIGHT * unit / VISUALIZER_SEGMENTS
	local left = right - VISUALIZER_WIDTH * unit
	columns = {}
	for column = 1, VISUALIZER_BARS do
		local segments = {}
		for segment = 1, VISUALIZER_SEGMENTS do
			local x = left + (column - 1) * slotWidth
			local y = bottom - segment * slotHeight
			local block = bar(parent, Palette.DeepNavy, x, y, slotWidth * SEGMENT_FILL, slotHeight * SEGMENT_FILL)
			block.Visible = false
			segments[segment] = block
		end
		columns[column] = segments
	end
end

local function updateVisualizer(dt: number)
	local time = os.clock()
	for column, segments in columns do
		local target = MusicBars.level(music.PlaybackLoudness, column, VISUALIZER_BARS, time)
		levels[column] = MusicBars.ease(levels[column], target, dt)
		local lit = MusicBars.lit(levels[column], VISUALIZER_SEGMENTS)
		for segment, block in segments do
			block.Visible = segment <= lit
		end
	end
end

local function updateCut(dt: number)
	local size = screen.AbsoluteSize
	if size.X <= 0 or size.Y <= 0 then
		return
	end
	local mouse = UserInputService:GetMouseLocation()
	local target = Vector2.new(mouse.X / size.X, mouse.Y / size.Y) * 2 - Vector2.one
	target = Vector2.new(math.clamp(target.X, -1, 1), math.clamp(target.Y, -1, 1))
	cursor = cursor:Lerp(target, 1 - math.exp(-dt * CUT_EASE))
	placeNavy(size.X, size.Y)
end

local frameLoop = RunService.RenderStepped:Connect(function(dt: number)
	updateVisualizer(dt)
	updateCut(dt)
end)

local function play()
	MenuState.play(MenuState.shared)
	controls:Enable()
	frameLoop:Disconnect()
	gui:Destroy()
	selectSound:Play()
	-- The music belongs to the title screen only.
	local fading = TweenService:Create(music, TweenInfo.new(MUSIC_FADE_SECONDS), { Volume = 0 })
	fading.Completed:Once(function()
		music:Destroy()
	end)
	fading:Play()
end

local function addMenu(parent: Frame, unit: number)
	local x = MARGIN * unit
	local size = MENU_SIZE * unit
	local tracking = MENU_TRACKING * unit
	local line = MENU_FIRST_LINE * unit
	local spacing = MENU_SPACING * unit
	local playLabel = text(parent, "LabelBold", "PLAY", Palette.Bone, x, line, size, tracking)

	local button = Instance.new("TextButton")
	button.Text = ""
	button.BackgroundTransparency = 1
	button.Position = UDim2.fromOffset(x, line - spacing * 0.75)
	button.Size = UDim2.fromOffset(PLAY_HIT_WIDTH * unit, spacing)
	button.Modal = true -- frees the mouse in first person
	button.ZIndex = 3
	button.Parent = parent
	button.MouseEnter:Connect(function()
		playLabel:set("> PLAY")
	end)
	button.MouseLeave:Connect(function()
		playLabel:set("PLAY")
	end)
	button.Activated:Connect(play)

	local dim = Palette.Bone:Lerp(Palette.DeepNavy, DIM_SHARE)
	for index, name in { "LOADOUT", "SETTINGS" } do
		local y = line + spacing * index
		local label = text(parent, "LabelBold", name, dim, x, y, size, tracking)
		text(parent, "Label", "SOON", dim, x + label:width() + SOON_GAP * unit, y, SOON_SIZE * unit, tracking / 2)
	end
end

local function draw()
	screen:ClearAllChildren()
	local width, height = screen.AbsoluteSize.X, screen.AbsoluteSize.Y
	if width <= 0 or height <= 0 then
		return
	end
	local unit = math.min(width, height * WIDE_SHAPE)
	local frame = Instance.new("Frame")
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundTransparency = 1
	frame.Parent = screen

	addNavy(frame, width, height)
	local left = MARGIN * unit
	local title = TITLE_SIZE * unit
	text(frame, "Title", "SPLIT", Palette.Bone, left, SPLIT_LINE * unit, title, 0)
	text(frame, "Title", "DECK", Palette.Bone, left, DECK_LINE * unit, title, 0)
	local rule = bar(frame, Palette.Bone, left, RULE_LINE * unit, RULE_WIDTH * unit, 1)
	rule.BackgroundTransparency = RULE_TRANSPARENCY
	addMenu(frame, unit)

	local right = width - MARGIN * unit
	local detail = DETAIL_SIZE * unit
	local tracking = DETAIL_TRACKING * unit
	local top = MARGIN * unit + detail
	text(frame, "Label", "BUILD 0.4", Palette.DeepNavy, right, top, detail, tracking, true)
	text(frame, "Label", "2 GUNS / 3 CARDS", Palette.DeepNavy, right, top + DETAIL_SPACING * unit, detail, tracking, true)
	local bottom = height - MARGIN * unit
	addVisualizer(frame, right, bottom, unit)
	addBarcode(frame, right, bottom - (VISUALIZER_HEIGHT + VISUALIZER_GAP) * unit, unit)
end

screen:GetPropertyChangedSignal("AbsoluteSize"):Connect(draw)
draw()
