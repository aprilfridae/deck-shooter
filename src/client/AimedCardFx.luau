-- Siphon's bolt and Kickplate's blast in the world, for everyone (they used to be a red line and a pale disc).
--
-- Siphon: a jagged red bolt that flickers twice and is gone, a pop where it stops, and on a hit a thin tether from
-- the body hit to whoever drained it, with motes running along it toward the drainer for as long as the slow lasts.
-- Kickplate: the card's own plate punches out of the surface and fades, a ring of hard segments and speed lines run
-- out along the surface, chips and dust kick up off it and a short acid light flashes.
--
-- Everything is flat neon pieces, like the HUD and the skip burst: no soft blobs. Nothing here can be hit by a
-- shot (CanQuery off).
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local CardCore = ReplicatedStorage:WaitForChild("CardCore")
local CardArt = require(CardCore:WaitForChild("CardArt"))
local CardLook = require(CardCore:WaitForChild("CardLook"))
local Variant = require(CardCore:WaitForChild("Variant"))
local Palette = require(ReplicatedStorage:WaitForChild("Guns"):WaitForChild("Palette"))

local RED = Palette.HazardRed
local HOT = Color3.fromRGB(255, 235, 235) -- the bolt's core
local ACID = Palette.SignalAcid
local BONE = Palette.Bone

-- The bolt.
local BOLT_STEP = 3 -- studs between kinks
local BOLT_KINK = 0.8 -- studs a kink strays from the straight line, at most
local BOLT_GLOW = 0.45 -- the red's transparency, so the hot core shows through it
local BOLT_WIDTH = 0.2
local CORE_WIDTH = 0.07
local FLICKERS = { 0, 0.05, 0.1 } -- seconds: when the bolt is drawn again with new kinks
local BOLT_FADE = 0.2
local OWN_HAND = Vector3.new(0.55, -0.45, -1.6) -- your own bolt starts here, in camera space, not in your eye
local POP_SIZE = 3
local POP_SECONDS = 0.18

-- The tether.
local TETHER_WIDTH = 0.1
local TETHER_LONGEST = 6 -- seconds
local TETHER_FADE = 0.4
local MOTE_EVERY = 0.09
local MOTE_SECONDS = 0.38
local MOTE_SIZE = 0.28

-- The blast.
local PLATE = Vector3.new(2.4, 3.84, 0.1) -- a card's shape, big enough to read
local PLATE_PUNCH = 1.6 -- studs it moves out along the surface's normal
local PLATE_SECONDS = 0.35
local RING_PIECES = 16
local RING_FROM, RING_TO = 1, 7.5 -- radius
local RING_SECONDS = 0.32
local LINES = 9
local LINE_SECONDS = 0.28
local LIGHT_SECONDS = 0.25

local AimedCardFx = {}

local function bit(color: Color3, size: Vector3): Part
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Material = Enum.Material.Neon
	part.Color = color
	part.Size = size
	return part
end

local function fadeOut(part: BasePart, seconds: number, goal: { [string]: any }?)
	local wanted = goal or {}
	wanted.Transparency = 1
	TweenService:Create(part, TweenInfo.new(seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), wanted):Play()
	Debris:AddItem(part, seconds + 0.1)
end

-- A burst of particles from a point, thrown out around `up` (or every way when up is nil).
local function spray(at: Vector3, up: Vector3?, options: { [string]: any })
	local holder = bit(BONE, Vector3.one * 0.1)
	holder.Transparency = 1
	holder.CFrame = if up then CFrame.lookAt(at, at + up) * CFrame.Angles(-math.pi / 2, 0, 0) else CFrame.new(at)
	holder.Parent = workspace
	local emitter = Instance.new("ParticleEmitter")
	emitter.EmissionDirection = Enum.NormalId.Top
	emitter.Rate = 0
	emitter.LightInfluence = 0
	for key, value in options do
		if key ~= "count" then
			(emitter :: any)[key] = value
		end
	end
	emitter.Parent = holder
	emitter:Emit(options.count)
	Debris:AddItem(holder, 1.5)
end

-- The points along a jagged line from a to b. The ends stay put; the kinks stray most in the middle.
local function kinks(a: Vector3, b: Vector3): { Vector3 }
	local length = (b - a).Magnitude
	local count = math.clamp(math.floor(length / BOLT_STEP), 2, 16)
	local frame = CFrame.lookAt(a, b)
	local points = { a }
	for i = 1, count - 1 do
		local share = i / count
		local stray = BOLT_KINK * math.sin(share * math.pi)
		local offset = frame.RightVector * (math.random() * 2 - 1) * stray + frame.UpVector * (math.random() * 2 - 1) * stray
		table.insert(points, a:Lerp(b, share) + offset)
	end
	table.insert(points, b)
	return points
end

local function segment(color: Color3, width: number, a: Vector3, b: Vector3): Part
	local length = (b - a).Magnitude
	local part = bit(color, Vector3.new(width, width, length))
	part.CFrame = CFrame.lookAt(a, b) * CFrame.new(0, 0, -length / 2)
	part.Parent = workspace
	return part
end

local function pop(at: Vector3, color: Color3)
	local ball = bit(color, Vector3.one * 0.4)
	ball.Shape = Enum.PartType.Ball
	ball.Position = at
	ball.Parent = workspace
	fadeOut(ball, POP_SECONDS, { Size = Vector3.one * POP_SIZE })
	spray(at, nil, {
		count = 14,
		Texture = "rbxasset://textures/particles/sparkles_main.dds",
		Color = ColorSequence.new(HOT, RED),
		LightEmission = 1,
		Lifetime = NumberRange.new(0.15, 0.35),
		Speed = NumberRange.new(10, 22),
		SpreadAngle = Vector2.new(180, 180),
		Drag = 6,
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 0) }),
	})
end

local function rootOf(model: Instance?): BasePart?
	if not model then
		return nil
	end
	local root = model:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
end

-- The drain: a thin line from the body hit to the drainer, and motes running along it to the drainer.
local function tether(victim: BasePart, drainer: BasePart, seconds: number)
	local lasts = math.min(seconds, TETHER_LONGEST)
	local from, to = Instance.new("Attachment"), Instance.new("Attachment")
	from.Name, to.Name = "SiphonFrom", "SiphonTo"
	from.Parent, to.Parent = victim, drainer
	local line = Instance.new("Beam")
	line.Attachment0, line.Attachment1 = from, to
	line.Color = ColorSequence.new(RED, HOT)
	line.Width0, line.Width1 = TETHER_WIDTH, TETHER_WIDTH * 0.5
	line.FaceCamera = true
	line.LightEmission = 1
	line.LightInfluence = 0
	line.Segments = 1
	line.Transparency = NumberSequence.new(0.35)
	line.Parent = victim
	local started = os.clock()
	local nextMote = 0
	local motes: { { part: Part, born: number } } = {}
	local connection: RBXScriptConnection
	connection = RunService.Heartbeat:Connect(function()
		local age = os.clock() - started
		local gone = not victim.Parent or not drainer.Parent or not victim:IsDescendantOf(workspace)
			or not drainer:IsDescendantOf(workspace)
		if gone or age >= lasts then
			connection:Disconnect()
			line:Destroy()
			from:Destroy()
			to:Destroy()
			for _, mote in motes do
				mote.part:Destroy()
			end
			return
		end
		-- The line thins out over its last moments.
		local fading = math.clamp((lasts - age) / TETHER_FADE, 0, 1)
		line.Transparency = NumberSequence.new(1 - 0.65 * fading)
		if age >= nextMote and fading == 1 then
			nextMote = age + MOTE_EVERY
			local part = bit(RED, Vector3.one * MOTE_SIZE)
			part.Parent = workspace
			table.insert(motes, { part = part, born = age })
		end
		local a, b = victim.Position, drainer.Position
		for i = #motes, 1, -1 do
			local mote = motes[i]
			local share = (age - mote.born) / MOTE_SECONDS
			if share >= 1 then
				mote.part:Destroy()
				table.remove(motes, i)
			else
				-- Slow away from the body, quick into you, and shrinking as it goes.
				mote.part.CFrame = CFrame.new(a:Lerp(b, share * share)) * CFrame.Angles(age * 9, age * 7, 0)
				mote.part.Size = Vector3.one * MOTE_SIZE * (1 - 0.6 * share)
				mote.part.Color = RED:Lerp(HOT, share)
			end
		end
	end)
end

-- Siphon's bolt. hit says it reached a body (`model`); `seconds` is how long the drain lasts.
function AimedCardFx.bolt(from: Vector3, to: Vector3, hit: boolean, thrower: number?, model: Instance?, seconds: number?)
	local player = Players.LocalPlayer
	local own = thrower == player.UserId
	local start = if own then workspace.CurrentCamera.CFrame * OWN_HAND else from
	if (to - start).Magnitude < 0.5 then
		return
	end
	local pieces: { Part } = {}
	local function draw()
		for _, piece in pieces do
			piece:Destroy()
		end
		table.clear(pieces)
		local points = kinks(start, to)
		for i = 1, #points - 1 do
			local glow = segment(RED, BOLT_WIDTH, points[i], points[i + 1])
			glow.Transparency = BOLT_GLOW
			table.insert(pieces, glow)
			table.insert(pieces, segment(HOT, CORE_WIDTH, points[i], points[i + 1]))
		end
	end
	for index, at in FLICKERS do
		task.delay(at, function()
			draw()
			if index == #FLICKERS then
				for _, piece in pieces do
					fadeOut(piece, BOLT_FADE, { Size = Vector3.new(0.02, 0.02, piece.Size.Z) })
				end
			end
		end)
	end
	pop(to, if hit then RED else BONE)
	if hit and type(seconds) == "number" and seconds > 0 then
		local drainerPlayer = if type(thrower) == "number" then Players:GetPlayerByUserId(thrower) else nil
		local victim, drainer = rootOf(model), rootOf(drainerPlayer and drainerPlayer.Character)
		if victim and drainer then
			tether(victim, drainer, seconds)
		end
	end
end

-- Kickplate's blast at `at` on a surface facing `normal`. tier picks the plate's look.
function AimedCardFx.blast(at: Vector3, normal: Vector3, tier: any)
	local up = if normal.Magnitude > 0.01 then normal.Unit else Vector3.yAxis
	-- Its front faces out of the surface, and the card's top leans the way the camera's top does, so the plate reads
	-- the right way up to whoever sees it (on a floor the normal alone left it upside down half the time).
	local facing = CFrame.lookAt(at, at + up, workspace.CurrentCamera.CFrame.UpVector)

	-- The plate: the card itself, punched out of the surface.
	local plate = Instance.new("Part")
	plate.Anchored = true
	plate.CanCollide = false
	plate.CanQuery = false
	plate.CanTouch = false
	plate.CastShadow = false
	plate.Material = Enum.Material.SmoothPlastic
	plate.Color = BONE
	plate.Size = PLATE * 0.6
	plate.CFrame = facing * CFrame.new(0, 0, -0.08)
	local image = if type(tier) == "string" then CardArt.base("kickplate", CardLook.look(tier, Variant.Base)) else nil
	if image then
		local decal = Instance.new("Decal")
		decal.Face = Enum.NormalId.Front
		decal.Texture = image
		decal.Parent = plate
	end
	plate.Parent = workspace
	local punch = TweenInfo.new(PLATE_SECONDS, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
	TweenService:Create(plate, punch, {
		Size = PLATE,
		CFrame = facing * CFrame.new(0, 0, -PLATE_PUNCH) * CFrame.Angles(math.rad(-25), 0, 0),
		Transparency = 1,
	}):Play()
	for _, decal in plate:GetChildren() do
		if decal:IsA("Decal") then
			TweenService:Create(decal, punch, { Transparency = 1 }):Play()
		end
	end
	Debris:AddItem(plate, PLATE_SECONDS + 0.1)

	-- The ring: hard segments running out along the surface.
	local grow = TweenInfo.new(RING_SECONDS, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
	local arc = 2 * math.pi * RING_TO / RING_PIECES
	for i = 1, RING_PIECES do
		local angle = (i - 1) / RING_PIECES * 2 * math.pi
		local spin = facing * CFrame.Angles(0, 0, angle)
		local piece = bit(if i % 2 == 0 then ACID else BONE, Vector3.new(0.18, arc * RING_FROM / RING_TO * 0.8, 0.06))
		piece.CFrame = spin * CFrame.new(RING_FROM, 0, -0.1)
		piece.Parent = workspace
		TweenService:Create(piece, grow, {
			CFrame = spin * CFrame.new(RING_TO, 0, -0.1),
			Size = Vector3.new(0.06, arc * 0.8, 0.04),
			Transparency = 1,
		}):Play()
		Debris:AddItem(piece, RING_SECONDS + 0.1)
	end

	-- Speed lines along the surface, at uneven angles and lengths so they don't read as a stamp.
	for i = 1, LINES do
		local angle = (i + math.random() * 0.6) / LINES * 2 * math.pi
		local spin = facing * CFrame.Angles(0, 0, angle)
		local long = 1.2 + math.random() * 1.4
		local line = bit(BONE, Vector3.new(long, 0.08, 0.04))
		line.CFrame = spin * CFrame.new(1.4 + long / 2, 0, -0.12)
		line.Parent = workspace
		TweenService:Create(line, TweenInfo.new(LINE_SECONDS, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			CFrame = spin * CFrame.new(5 + long, 0, -0.12),
			Size = Vector3.new(long * 0.4, 0.02, 0.02),
			Transparency = 1,
		}):Play()
		Debris:AddItem(line, LINE_SECONDS + 0.1)
	end

	-- Chips and dust kicked up off the surface: the dark dust is what lets the bright pieces read on a pale floor.
	local out = at + up * 0.3
	spray(out, up, {
		count = 18,
		Texture = "rbxasset://textures/particles/sparkles_main.dds",
		Color = ColorSequence.new(BONE, ACID),
		LightEmission = 1,
		Lifetime = NumberRange.new(0.2, 0.45),
		Speed = NumberRange.new(18, 34),
		SpreadAngle = Vector2.new(55, 55),
		Drag = 5,
		Acceleration = Vector3.new(0, -60, 0),
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.4), NumberSequenceKeypoint.new(1, 0) }),
	})
	spray(out, up, {
		count = 10,
		Texture = "rbxasset://textures/particles/smoke_main.dds",
		Color = ColorSequence.new(Palette.DeepNavy),
		LightEmission = 0,
		Lifetime = NumberRange.new(0.4, 0.7),
		Speed = NumberRange.new(6, 12),
		SpreadAngle = Vector2.new(80, 80),
		Drag = 4,
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 1) }),
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.5), NumberSequenceKeypoint.new(1, 3.5) }),
	})

	local holder = bit(ACID, Vector3.one * 0.1)
	holder.Transparency = 1
	holder.Position = out + up
	holder.Parent = workspace
	local light = Instance.new("PointLight")
	-- A flash on the spot, not the room: pure acid at range 18 and brightness 6 washed floors and walls green.
	light.Color = ACID:Lerp(BONE, 0.5)
	light.Range = 10
	light.Brightness = 2
	light.Shadows = false
	light.Parent = holder
	TweenService:Create(light, TweenInfo.new(LIGHT_SECONDS, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Brightness = 0 }):Play()
	Debris:AddItem(holder, LIGHT_SECONDS + 0.1)
end

return AimedCardFx
