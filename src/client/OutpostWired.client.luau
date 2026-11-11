-- Brings the Outpost's monitors and server towers to life (the server builds them: Wired.luau). Code screens
-- scroll made-up code, wave screens slide red-to-blue waveforms across a scope, glow screens hum a blank blue,
-- and tower lights blink. Only while you're in the Outpost,
-- and only screens near enough to read are updated.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Guns = ReplicatedStorage:WaitForChild("Guns")
local CodeLines = require(Guns:WaitForChild("CodeLines"))
local Flicker = require(Guns:WaitForChild("Flicker"))
local Zones = require(Guns:WaitForChild("Zones"))
local Perf = require(script.Parent:WaitForChild("Perf"))

local SCREEN_TAG = "OutpostWiredScreen"
local LED_TAG = "OutpostWiredLed"
local PIXELS_PER_STUD = 50
local LINES = 9
local TICK = 1 / 12
local NEAR = 90 -- studs; screens further than this hold still
local CODE_COLORS = {
	Color3.fromRGB(150, 210, 255),
	Color3.fromRGB(150, 210, 255),
	Color3.fromRGB(170, 255, 190),
	Color3.fromRGB(220, 226, 240),
}
local GLOW_COLOR = Color3.fromRGB(150, 196, 255)
local BACK = Color3.fromRGB(8, 14, 26)

-- One colour for every visualisation: the palette's Deep Navy, lifted so it reads on a black screen (River
-- found the red-to-pink-to-blue mix weird and wanted it simple). The names are from the old mix.
local NAVY = Color3.fromRGB(104, 126, 198)
local CREAM = Color3.fromRGB(168, 182, 226) -- rules, ticks and readouts: the same navy, paler
local WAVE_RED = NAVY
local WAVE_PINK = NAVY
local WAVE_BLUE = NAVY
local WAVES = 11 -- curves in a scope
local WAVE_STEPS = 18 -- straight pieces per curve, per period
local WAVE_PERIOD = 4 -- seconds for the waves to slide one screen across

-- A thin straight line from a to b, in pixels.
local function line(parent: Instance, a: Vector2, b: Vector2, thick: number, color: Color3, transparency: number)
	local span = b - a
	local piece = Instance.new("Frame")
	piece.AnchorPoint = Vector2.new(0.5, 0.5)
	piece.Position = UDim2.fromOffset((a.X + b.X) / 2, (a.Y + b.Y) / 2)
	piece.Size = UDim2.fromOffset(span.Magnitude + thick * 0.5, thick)
	piece.Rotation = math.deg(math.atan2(span.Y, span.X))
	piece.BorderSizePixel = 0
	piece.BackgroundColor3 = color
	piece.BackgroundTransparency = transparency
	piece.Parent = parent
end

local function waveColor(share: number): Color3
	return if share < 0.5 then WAVE_RED:Lerp(WAVE_PINK, share * 2) else WAVE_PINK:Lerp(WAVE_BLUE, share * 2 - 1)
end

-- A scope: cream rules top and bottom with a scale, crosses, a running time readout, and a bundle of waves
-- that each fall and rise once per screen width, a little behind the one before, sliding along. The waves are
-- drawn once over two widths and the strip slides and wraps, so moving them costs one property a tick.
local function buildWave(back: Frame, width: number, height: number): (Frame, TextLabel)
	back.BackgroundColor3 = Color3.new(0, 0, 0)
	local top, bottom = height * 0.16, height * 0.78
	local high, low = height * 0.22, height * 0.72
	local rule = math.max(height * 0.012, 1)
	line(back, Vector2.new(width * 0.04, top), Vector2.new(width * 0.96, top), rule, CREAM, 0)
	line(back, Vector2.new(width * 0.04, bottom), Vector2.new(width * 0.96, bottom), rule, CREAM, 0)
	for tick = 0, 20 do
		local x = width * (0.06 + 0.88 * tick / 20)
		line(back, Vector2.new(x, bottom), Vector2.new(x, bottom + height * (if tick % 2 == 0 then 0.04 else 0.02)), 1, CREAM, 0.1)
	end
	local window = Instance.new("Frame")
	window.BackgroundTransparency = 1
	window.Position = UDim2.fromOffset(width * 0.04, 0)
	window.Size = UDim2.fromOffset(width * 0.92, height)
	window.ClipsDescendants = true
	window.Parent = back
	local span = width * 0.92
	local strip = Instance.new("Frame")
	strip.BackgroundTransparency = 1
	strip.Size = UDim2.fromOffset(span * 2, height)
	strip.Parent = window
	local thick = math.max(height * 0.008, 1)
	for wave = 0, WAVES - 1 do
		local share = wave / (WAVES - 1)
		local shift = share * 0.45 -- of a period
		local color = waveColor(share)
		local last: Vector2? = nil
		for step = 0, WAVE_STEPS * 2 do
			local along = step / WAVE_STEPS -- periods
			local fall = (math.cos((along + shift) * math.pi * 2) + 1) / 2
			local point = Vector2.new(along * span, low + (high - low) * fall)
			if last then
				line(strip, last, point, thick, color, 0.15)
			end
			last = point
		end
	end
	for row = 0, 2 do
		for col = 0, 3 do
			local cross = Instance.new("TextLabel")
			cross.BackgroundTransparency = 1
			cross.AnchorPoint = Vector2.new(0.5, 0.5)
			cross.Position = UDim2.fromOffset(width * (0.2 + col * 0.2), top + (bottom - top) * (0.1 + row * 0.4))
			cross.Size = UDim2.fromOffset(height * 0.1, height * 0.1)
			cross.Font = Enum.Font.Code
			cross.Text = "+"
			cross.TextSize = height * 0.08
			cross.TextColor3 = CREAM
			cross.Parent = back
		end
	end
	local clock = Instance.new("TextLabel")
	clock.BackgroundTransparency = 1
	clock.AnchorPoint = Vector2.new(1, 1)
	clock.Position = UDim2.fromOffset(width * 0.96, top - rule)
	clock.Size = UDim2.fromOffset(width * 0.6, height * 0.08)
	clock.Font = Enum.Font.Code
	clock.TextSize = height * 0.07
	clock.TextXAlignment = Enum.TextXAlignment.Right
	clock.TextColor3 = CREAM
	clock.Text = ""
	clock.Parent = back
	return strip, clock
end

-- A radar: rings and a cross in cream, and a pink-to-blue sweep going round. Returns what turns.
local function buildRadar(back: Frame, width: number, height: number): Frame
	back.BackgroundColor3 = Color3.new(0, 0, 0)
	local radius = math.min(width, height) * 0.42
	local centre = UDim2.fromOffset(width / 2, height / 2)
	for ring = 1, 3 do
		local circle = Instance.new("Frame")
		circle.AnchorPoint = Vector2.new(0.5, 0.5)
		circle.Position = centre
		circle.Size = UDim2.fromOffset(radius * 2 * ring / 3, radius * 2 * ring / 3)
		circle.BackgroundTransparency = 1
		local round = Instance.new("UICorner")
		round.CornerRadius = UDim.new(0.5, 0)
		round.Parent = circle
		local stroke = Instance.new("UIStroke")
		stroke.Color = CREAM
		stroke.Transparency = if ring == 3 then 0.1 else 0.55
		stroke.Thickness = 1
		stroke.Parent = circle
		circle.Parent = back
	end
	line(back, Vector2.new(width / 2 - radius, height / 2), Vector2.new(width / 2 + radius, height / 2), 1, CREAM, 0.6)
	line(back, Vector2.new(width / 2, height / 2 - radius), Vector2.new(width / 2, height / 2 + radius), 1, CREAM, 0.6)
	-- The sweep: a bar across the whole circle, lit on one half only, turned about its middle.
	local sweep = Instance.new("Frame")
	sweep.AnchorPoint = Vector2.new(0.5, 0.5)
	sweep.Position = centre
	sweep.Size = UDim2.fromOffset(radius * 2, math.max(height * 0.012, 1.5))
	sweep.BackgroundColor3 = WAVE_BLUE
	sweep.BorderSizePixel = 0
	local fade = Instance.new("UIGradient")
	fade.Color = ColorSequence.new(WAVE_PINK, WAVE_BLUE)
	fade.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.5, 1),
		NumberSequenceKeypoint.new(0.501, 0.5),
		NumberSequenceKeypoint.new(1, 0),
	})
	fade.Parent = sweep
	sweep.Parent = back
	-- A few blips that the sweep lights as it passes.
	for _ = 1, 4 do
		local blip = Instance.new("Frame")
		blip.AnchorPoint = Vector2.new(0.5, 0.5)
		local angle, out = math.random() * math.pi * 2, radius * (0.2 + math.random() * 0.75)
		blip.Position = UDim2.fromOffset(width / 2 + math.cos(angle) * out, height / 2 + math.sin(angle) * out)
		blip.Size = UDim2.fromOffset(height * 0.035, height * 0.035)
		blip.BackgroundColor3 = WAVE_RED
		blip.BorderSizePixel = 0
		blip:SetAttribute("Angle", math.deg(angle))
		blip.Name = "Blip"
		blip.Parent = back
	end
	return sweep
end

local BARS = 14

-- A spectrum: bars in a red-to-blue run between cream rules. Returns the bars.
local function buildBars(back: Frame, width: number, height: number): { Frame }
	back.BackgroundColor3 = Color3.new(0, 0, 0)
	local top, bottom = height * 0.14, height * 0.84
	line(back, Vector2.new(width * 0.05, top), Vector2.new(width * 0.95, top), 1, CREAM, 0.2)
	line(back, Vector2.new(width * 0.05, bottom), Vector2.new(width * 0.95, bottom), 1, CREAM, 0)
	local bars = {}
	local slot = width * 0.86 / BARS
	for index = 1, BARS do
		local bar = Instance.new("Frame")
		bar.AnchorPoint = Vector2.new(0, 1)
		bar.Position = UDim2.fromOffset(width * 0.07 + (index - 1) * slot, bottom - 1)
		bar.Size = UDim2.fromOffset(slot * 0.62, 0)
		bar.BackgroundColor3 = waveColor((index - 1) / (BARS - 1))
		bar.BorderSizePixel = 0
		bar:SetAttribute("Room", bottom - top - 2)
		bar.Parent = back
		table.insert(bars, bar)
	end
	return bars
end

type Screen = {
	part: BasePart,
	kind: string,
	seed: number,
	label: TextLabel?,
	glow: Frame?,
	strip: Frame?,
	sweep: Frame?,
	bars: { Frame }?,
	clock: TextLabel?,
	span: number,
	stream: CodeLines.Stream?,
	lines: { string },
	nextAt: number,
	every: number,
}

local player = Players.LocalPlayer
local screens: { Screen } = {}
local leds: { { part: BasePart, seed: number } } = {}

local function addScreen(part: Instance)
	if not part:IsA("BasePart") or part:FindFirstChild("WiredGui") then
		return
	end
	local kind = part:GetAttribute("WiredKind") or "Code"
	local seed = part:GetAttribute("WiredSeed") or 1
	local gui = Instance.new("SurfaceGui")
	gui.Name = "WiredGui"
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = PIXELS_PER_STUD
	gui.LightInfluence = 0
	gui.Brightness = 1.6
	gui.ClipsDescendants = true
	local back = Instance.new("Frame")
	back.Size = UDim2.fromScale(1, 1)
	back.BorderSizePixel = 0
	back.BackgroundColor3 = if kind == "Glow" then GLOW_COLOR else BACK
	back.Parent = gui
	-- The tube's curve: darker toward the edges.
	local shade = Instance.new("UIGradient")
	shade.Rotation = 90
	shade.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.35),
		NumberSequenceKeypoint.new(0.5, 0),
		NumberSequenceKeypoint.new(1, 0.35),
	})
	shade.Parent = back
	local width, height = part.Size.X * PIXELS_PER_STUD, part.Size.Y * PIXELS_PER_STUD
	local screen: Screen = {
		part = part,
		kind = kind,
		seed = seed,
		lines = {},
		nextAt = 0,
		every = 0.12 + (seed % 7) * 0.05,
		span = width * 0.92,
	}
	if kind == "Wave" then
		shade:Destroy()
		screen.strip, screen.clock = buildWave(back, width, height)
	elseif kind == "Radar" then
		shade:Destroy()
		screen.sweep = buildRadar(back, width, height)
	elseif kind == "Bars" then
		shade:Destroy()
		screen.bars = buildBars(back, width, height)
	elseif kind == "Code" then
		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.Position = UDim2.fromScale(0.05, 0.04)
		label.Size = UDim2.fromScale(0.92, 0.92)
		label.Font = Enum.Font.Code
		label.TextScaled = false
		label.TextSize = math.max(part.Size.Y * PIXELS_PER_STUD / (LINES + 1), 6)
		label.TextXAlignment = Enum.TextXAlignment.Left
		label.TextYAlignment = Enum.TextYAlignment.Bottom
		label.TextColor3 = CODE_COLORS[seed % #CODE_COLORS + 1]
		label.TextTransparency = 0.05
		label.Text = ""
		label.Parent = back
		screen.label = label
		screen.stream = CodeLines.new(seed)
		for _ = 1, LINES do
			table.insert(screen.lines, CodeLines.next(screen.stream :: any))
		end
		label.Text = table.concat(screen.lines, "\n")
	else
		screen.glow = back
	end
	gui.Parent = part
	table.insert(screens, screen)
end

local function addLed(part: Instance)
	if part:IsA("BasePart") then
		table.insert(leds, { part = part, seed = part:GetAttribute("WiredSeed") or 1 })
	end
end

CollectionService:GetInstanceAddedSignal(SCREEN_TAG):Connect(addScreen)
for _, part in CollectionService:GetTagged(SCREEN_TAG) do
	addScreen(part)
end
CollectionService:GetInstanceAddedSignal(LED_TAG):Connect(addLed)
for _, part in CollectionService:GetTagged(LED_TAG) do
	addLed(part)
end

local waited = 0
RunService.Heartbeat:Connect(function(dt)
	waited += dt
	if waited < TICK then
		return
	end
	waited = 0
	if Zones.of(player) ~= Zones.Outpost then
		return
	end
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	local eye = camera.CFrame.Position
	local now = os.clock()
	local slower = Perf.pick(1, 1.5, 2.5) -- a slower machine types slower
	for _, screen in screens do
		if (screen.part.Position - eye).Magnitude > NEAR then
			continue
		end
		if screen.label and screen.stream and now >= screen.nextAt then
			-- Bursts of lines, then pauses, like something compiling.
			screen.nextAt = now + screen.every * slower * (if (screen.seed + math.floor(now)) % 5 == 0 then 6 else 1)
			table.remove(screen.lines, 1)
			table.insert(screen.lines, CodeLines.next(screen.stream))
			screen.label.Text = table.concat(screen.lines, "\n")
		elseif screen.strip and screen.clock then
			local through = ((now + screen.seed) / WAVE_PERIOD) % 1
			screen.strip.Position = UDim2.fromOffset(-through * screen.span, 0)
			local total = now + screen.seed % 3600
			screen.clock.Text = string.format("±%d:%02d:%05d", total // 3600, total // 60 % 60, math.floor(total * 1000) % 100000)
		elseif screen.sweep then
			local turn = ((now + screen.seed) * 90) % 360
			screen.sweep.Rotation = turn
			for _, blip in screen.sweep.Parent:GetChildren() do
				if blip.Name == "Blip" and blip:IsA("Frame") then
					-- Bright just after the sweep passes, then fading out over most of a turn.
					local since = (turn - (blip:GetAttribute("Angle") :: number)) % 360
					blip.BackgroundTransparency = math.clamp(since / 300, 0, 1)
				end
			end
		elseif screen.bars then
			for index, bar in screen.bars do
				local level = (math.sin(now * (3 + index * 0.7) + screen.seed + index) + math.sin(now * 5.3 + index * 1.9) + 2) / 4
				local room = bar:GetAttribute("Room") :: number
				bar.Size = UDim2.fromOffset(bar.Size.X.Offset, math.max(room * level * (1 - index / (BARS * 1.6)), 1))
			end
		elseif screen.glow then
			screen.glow.BackgroundTransparency = (1 - Flicker.at(screen.seed, now * 3)) * 1.5
		end
	end
	for _, led in leds do
		-- Each light has its own rhythm: mostly on, with quick blinks of activity.
		local phase = math.floor(now * (2 + led.seed % 5)) + led.seed
		led.part.Transparency = if phase % (3 + led.seed % 4) == 0 then 0.85 else 0
	end
end)
