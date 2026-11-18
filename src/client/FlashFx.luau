-- Flashpoint in the world: the card skims flat and spinning across the room on a shallow arc, then bursts in a
-- white flash. Everyone sees the burst. Whoever the server says could see it gets the blindness: the screen goes
-- white and fades back, for less time the more they had their back to it (CardAim.flashFacing).
--
-- Your own card is one motion with the first-person hand, as Switchback's is (CardThrowFx): the server's word on
-- where it goes is kept (`report`), and the hand hands over the very card it held when it lets go (`release`).
local Debris = game:GetService("Debris")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local CardCore = ReplicatedStorage:WaitForChild("CardCore")
local CardAim = require(CardCore:WaitForChild("CardAim"))
local CardArt = require(CardCore:WaitForChild("CardArt"))
local CardLook = require(CardCore:WaitForChild("CardLook"))
local Config = require(CardCore:WaitForChild("Config"))
local Variant = require(CardCore:WaitForChild("Variant"))
local Guns = ReplicatedStorage:WaitForChild("Guns")
local CardFlourish = require(Guns:WaitForChild("CardFlourish"))
local Palette = require(Guns:WaitForChild("Palette"))

local CARD_SIZE = Vector3.new(1.6, 0.05, 2.56) -- in the world: bigger than a real card, so it reads
local GROW = 0.4 -- of the flight: grown by here
local SETTLE = 0.3 -- of the flight: lying flat by here
local SPIN = 26 -- radians a second, flat like a thrown disc
local ARC = 0.07 -- the arc's height, as a share of the distance
local GLOW = Palette.SignalAcid
local TRAIL_SECONDS = 0.18

-- The burst.
local BURST_SIZE = 16 -- studs across at its widest
local BURST_SECONDS = 0.4
local LIGHT_RANGE = 45
local LIGHT_SECONDS = 0.6
local RING_SIZE = 26
local SPARKS = 36
local WHITE = Color3.fromRGB(255, 255, 250)

-- The blindness on your own screen.
local HOLD = 0.35 -- of the time it lasts, the screen stays fully white
local REPORT_KEPT = 1
local BLIND_RANGE = 30 -- how far your card flies if the server's report is late

local FlashFx = {}

local reported: { to: Vector3, tier: any, at: number }? = nil

local function bit(shape: Enum.PartType, color: Color3): Part
	local part = Instance.new("Part")
	part.Shape = shape
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Material = Enum.Material.Neon
	part.Color = color
	return part
end

-- The flash everyone sees: a white ball that blooms and is gone, a light that floods the room, an acid ring and a
-- spray of sparks.
function FlashFx.burst(at: Vector3)
	local ball = bit(Enum.PartType.Ball, WHITE)
	ball.Size = Vector3.one
	ball.Position = at
	ball.Parent = workspace
	local grow = TweenInfo.new(BURST_SECONDS, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
	TweenService:Create(ball, grow, { Size = Vector3.one * BURST_SIZE, Transparency = 1 }):Play()
	Debris:AddItem(ball, BURST_SECONDS + 0.1)

	local light = Instance.new("PointLight")
	light.Color = WHITE
	light.Range = LIGHT_RANGE
	light.Brightness = 14
	light.Shadows = false
	light.Parent = ball
	TweenService:Create(light, TweenInfo.new(LIGHT_SECONDS, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Brightness = 0 }):Play()

	-- The ring lies flat, so it reads as a shockwave from any height.
	local ring = bit(Enum.PartType.Cylinder, GLOW)
	ring.Size = Vector3.new(0.15, 2, 2)
	ring.CFrame = CFrame.new(at) * CFrame.Angles(0, 0, math.rad(90))
	ring.Transparency = 0.2
	ring.Parent = workspace
	TweenService:Create(ring, grow, { Size = Vector3.new(0.05, RING_SIZE, RING_SIZE), Transparency = 1 }):Play()
	Debris:AddItem(ring, BURST_SECONDS + 0.1)

	local holder = bit(Enum.PartType.Block, WHITE)
	holder.Size = Vector3.one * 0.1
	holder.Transparency = 1
	holder.Position = at
	holder.Parent = workspace
	local sparks = Instance.new("ParticleEmitter")
	sparks.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	sparks.Color = ColorSequence.new(WHITE, GLOW)
	sparks.LightEmission = 1
	sparks.LightInfluence = 0
	sparks.Lifetime = NumberRange.new(0.3, 0.6)
	sparks.Speed = NumberRange.new(18, 40)
	sparks.SpreadAngle = Vector2.new(180, 180)
	sparks.Drag = 6
	sparks.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 0) })
	sparks.Rate = 0
	sparks.Parent = holder
	sparks:Emit(SPARKS)
	Debris:AddItem(holder, 1)
end

-- Flies the card from `start` (where it is and how it's turned, at `startSize`) to `to`, then bursts.
local function fly(start: CFrame, startSize: Vector3, to: Vector3, tier: any)
	local from = start.Position
	local length = (to - from).Magnitude
	if length < 0.5 then
		FlashFx.burst(to)
		return
	end
	local card = Instance.new("Part")
	card.Name = "FlashpointCard"
	card.Anchored = true
	card.CanCollide = false
	card.CanQuery = false
	card.CanTouch = false
	card.CastShadow = false
	card.Size = startSize
	card.Material = Enum.Material.SmoothPlastic
	card.Color = Palette.Bone
	local image = if type(tier) == "string" then CardArt.base("flashpoint", CardLook.look(tier, Variant.Base)) else nil
	if image then
		for _, side in { Enum.NormalId.Top, Enum.NormalId.Bottom } do
			local decal = Instance.new("Decal")
			decal.Face = side
			decal.Texture = image
			decal.Parent = card
		end
	end
	-- It glows harder the nearer it is to going off.
	local light = Instance.new("PointLight")
	light.Color = GLOW
	light.Range = 8
	light.Brightness = 0
	light.Parent = card
	local left, right = Instance.new("Attachment"), Instance.new("Attachment")
	left.Parent, right.Parent = card, card
	local trail = Instance.new("Trail")
	trail.Attachment0, trail.Attachment1 = left, right
	trail.Color = ColorSequence.new(GLOW)
	trail.Transparency = NumberSequence.new(0.5, 1)
	trail.Lifetime = TRAIL_SECONDS
	trail.LightEmission = 1
	trail.FaceCamera = true
	trail.Parent = card
	card.CFrame = start
	card.Parent = workspace

	local held = start.Rotation
	-- Flat, its long side pointing the way it goes.
	local across = Vector3.new(to.X - from.X, 0, to.Z - from.Z)
	local level = if across.Magnitude > 0.01 then CFrame.lookAt(Vector3.zero, across) else CFrame.identity
	local flight = CardAim.flashFlight(length, Config.FlashSpeed, Config.FlashLeast)
	local started = os.clock()
	local connection: RBXScriptConnection
	connection = RunService.RenderStepped:Connect(function()
		local age = os.clock() - started
		local share = math.min(age / flight, 1)
		local size = startSize:Lerp(CARD_SIZE, math.min(share / GROW, 1))
		card.Size = size
		left.Position, right.Position = Vector3.new(-size.X * 0.4, 0, 0), Vector3.new(size.X * 0.4, 0, 0)
		local flat = held:Lerp(level, math.min(share / SETTLE, 1)) * CFrame.Angles(0, -age * SPIN, 0)
		local lift = math.sin(share * math.pi) * ARC * length
		card.CFrame = CFrame.new(from:Lerp(to, share) + Vector3.new(0, lift, 0)) * flat
		light.Brightness = 4 * share * share
		if share < 1 then
			return
		end
		connection:Disconnect()
		card:Destroy()
		FlashFx.burst(to)
	end)
end

-- Someone else's flick: from their chest, after the wind-up.
function FlashFx.throw(from: Vector3, to: Vector3, tier: any)
	task.delay(CardFlourish.FLICK_RELEASE, fly, CFrame.lookAt(from, to), CARD_SIZE, to, tier)
end

-- The server's word on where your own card goes. It is drawn when your hand lets go.
function FlashFx.report(to: Vector3, tier: any)
	reported = { to = to, tier = tier, at = os.clock() }
end

function FlashFx.release(card: CFrame, size: Vector3, look: CFrame)
	local known = reported
	reported = nil
	if known and os.clock() - known.at <= REPORT_KEPT then
		fly(card, size, known.to, known.tier)
	else
		fly(card, size, look.Position + look.LookVector * BLIND_RANGE, nil)
	end
end

-- Blinds you, if you could see a burst at `at`: the server has already taken off for how far away it was, and
-- this takes off for the way you were facing. `seconds` is the most it can last.
local overlay: Frame? = nil
local grade: ColorCorrectionEffect? = nil
local blindUntil = 0
local blindLength = 0

local function screen(): (Frame, ColorCorrectionEffect)
	if overlay and overlay.Parent and grade and grade.Parent then
		return overlay, grade
	end
	local gui = Instance.new("ScreenGui")
	gui.Name = "Flashpoint"
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 50 -- over the HUD
	gui.ResetOnSpawn = false
	local frame = Instance.new("Frame")
	frame.BackgroundColor3 = WHITE
	frame.BorderSizePixel = 0
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundTransparency = 1
	frame.Parent = gui
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	local effect = Instance.new("ColorCorrectionEffect")
	effect.Name = "Flashpoint"
	effect.Parent = Lighting
	overlay, grade = frame, effect
	return frame, effect
end

function FlashFx.blind(at: Vector3, seconds: number)
	local camera = workspace.CurrentCamera
	local toward = at - camera.CFrame.Position
	local facing = if toward.Magnitude > 0.01 then camera.CFrame.LookVector:Dot(toward.Unit) else 1
	local length = seconds * CardAim.flashFacing(facing)
	-- A second flash only ever makes it worse.
	local now = os.clock()
	if now + length > blindUntil then
		blindUntil = now + length
		blindLength = length
	end
	screen()
end

RunService.RenderStepped:Connect(function()
	if not overlay then
		return
	end
	local left = blindUntil - os.clock()
	local frame, effect = screen()
	if left <= 0 then
		frame.BackgroundTransparency = 1
		effect.Brightness, effect.Saturation, effect.Contrast = 0, 0, 0
		return
	end
	-- White for the first part, then it fades back, slowly at first and quicker at the end, with the world washed
	-- out and grey under it for a little longer.
	local through = 1 - left / blindLength
	local fading = math.clamp((through - HOLD) / (1 - HOLD), 0, 1)
	frame.BackgroundTransparency = fading ^ 0.6
	effect.Brightness = 0.6 * (1 - fading)
	effect.Saturation = -1 * (1 - fading * fading)
	effect.Contrast = -0.3 * (1 - fading)
end)

return FlashFx
