-- Brings the Outpost's monitors and server towers to life (the server builds them: Wired.luau). Code screens
-- scroll made-up code, glow screens hum a blank blue, and tower lights blink. Only while you're in the Outpost,
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

type Screen = {
	part: BasePart,
	kind: string,
	seed: number,
	label: TextLabel?,
	glow: Frame?,
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
	local screen: Screen = { part = part, kind = kind, seed = seed, lines = {}, nextAt = 0, every = 0.12 + (seed % 7) * 0.05 }
	if kind == "Code" then
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
