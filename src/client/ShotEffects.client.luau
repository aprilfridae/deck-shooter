-- Bullet tracers and blood: a dark, glowing red mist and drops, with no splats left behind. The server sends where each
-- bullet really went, spread included.
local Palette = require(game:GetService("ReplicatedStorage"):WaitForChild("Guns"):WaitForChild("Palette"))
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local GunAudio = require(script.Parent.GunAudio)
local GunSounds = require(ReplicatedStorage.Guns.GunSounds)
local GunView = require(script.Parent.GunView)
local Collision = require(ReplicatedStorage.Guns.Collision)
local Flyby = require(ReplicatedStorage.Guns.Flyby)
local Tracer = require(ReplicatedStorage.Guns.Tracer)

local remotes = ReplicatedStorage:WaitForChild("GunRemotes")
local shotsRemote = remotes:WaitForChild("Shots") :: RemoteEvent
local deathRemote = remotes:WaitForChild("DeathBurst") :: RemoteEvent

local TRACER_SPEED = 600
-- Coins burst out of a body when it dies, bounce on the floor and shrink away.
local COINS = 16
local COIN_SIZE = Vector3.new(0.1, 0.65, 0.65) -- a cylinder lies along X, so this is a flat coin
local COIN_COLOR = Color3.fromRGB(255, 196, 46)
local COIN_UP = { 26, 44 }
local COIN_OUT = { 10, 24 }
local COIN_SPIN = 25
local COIN_LIFE = 2.6
local COIN_SHRINK = 0.4
local TRACER_LENGTH = 12
local TRACER_WIDTH = 0.07
local TRACER_COLOR = Palette.DataCyan

-- Blood is a dark, dark red that glows: the mist is the dark body of it, the drops and the headshot ring are a deep
-- red that shines (Neon), and the sparks and the light it throws on things nearby are the brightest red.
local BLOOD_COLOR = Color3.fromRGB(92, 0, 8)
local BLOOD_GLOW = Color3.fromRGB(190, 0, 16)
local BLOOD_LIGHT = Palette.HazardRed
local MIST_BURST = 30
local SPARKS = 14
local DROPS = 14 -- back toward the shooter
local EXIT_DROPS = 12 -- out the far side, faster and tighter
local HEADSHOT_SCALE = 2 -- headshots throw this much more blood
local DROP_SPEED = 26
local EXIT_SPEED = 48
local DROP_LIFE = 0.45
local DROP_SIZE = 0.13
local STREAK = 0.022 -- a drop stretches this many studs along its path per stud a second it moves
local GRAVITY = 110
local FLASH_BRIGHTNESS = 2.2
local FLASH_RANGE = 7
local FLASH_TIME = 0.14
local RING_SIZE = 5 -- a headshot's ring grows to this wide
local RING_TIME = 0.18

local player = Players.LocalPlayer
local random = Random.new()

local folder = Instance.new("Folder")
folder.Name = "ShotEffects"
folder.Parent = workspace

local function makePart(size: Vector3, color: Color3, material: Enum.Material): Part
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Size = size
	part.Color = color
	part.Material = material
	return part
end

-- A puff that bursts back toward the shooter. One emitter serves every hit.
local mistAnchor = makePart(Vector3.one, BLOOD_COLOR, Enum.Material.SmoothPlastic)
mistAnchor.Transparency = 1
mistAnchor.Parent = folder
local mist = Instance.new("ParticleEmitter")
mist.Texture = "rbxasset://textures/particles/smoke_main.dds"
mist.Color = ColorSequence.new(BLOOD_COLOR)
mist.LightEmission = 0.15 -- mostly its own dark colour, so it reads as dark red and doesn't wash out
mist.Lifetime = NumberRange.new(0.2, 0.4)
mist.Speed = NumberRange.new(5, 16)
mist.SpreadAngle = Vector2.new(35, 35)
mist.Drag = 7
mist.Acceleration = Vector3.new(0, -20, 0)
mist.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 1.7) })
mist.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 1) })
mist.EmissionDirection = Enum.NormalId.Back
mist.Rate = 0
mist.Parent = mistAnchor
-- Bright specks that spit out of the wound and glow.
local sparks = Instance.new("ParticleEmitter")
sparks.Texture = "rbxasset://textures/particles/sparkles_main.dds"
sparks.Color = ColorSequence.new(BLOOD_LIGHT, BLOOD_GLOW)
sparks.LightEmission = 1
sparks.LightInfluence = 0
sparks.Lifetime = NumberRange.new(0.15, 0.35)
sparks.Speed = NumberRange.new(14, 34)
sparks.SpreadAngle = Vector2.new(60, 60)
sparks.Drag = 4
sparks.Acceleration = Vector3.new(0, -40, 0)
sparks.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 0) })
sparks.EmissionDirection = Enum.NormalId.Back
sparks.Rate = 0
sparks.Parent = mistAnchor
-- A red flash lights up whatever is around the hit.
local flash = Instance.new("PointLight")
flash.Color = BLOOD_LIGHT
flash.Range = FLASH_RANGE
flash.Brightness = 0
flash.Shadows = false
flash.Parent = mistAnchor
local flashAt = -math.huge
local rings: { any } = {}

local tracers: { any } = {}
local drops: { any } = {}

local function addTracer(from: Vector3, to: Vector3)
	local line = to - from
	if line.Magnitude < 0.1 then
		return
	end
	local part = makePart(Vector3.new(TRACER_WIDTH, TRACER_WIDTH, 0.1), TRACER_COLOR, Enum.Material.Neon)
	part.Parent = folder
	table.insert(tracers, { part = part, from = from, unit = line.Unit, total = line.Magnitude, age = 0 })
end

-- A glowing drop that streaks along its path as it flies.
local function addDrop(position: Vector3, direction: Vector3, speed: number, cone: number)
	local spread = direction + random:NextUnitVector() * cone
	local part = makePart(Vector3.one * DROP_SIZE, BLOOD_GLOW, Enum.Material.Neon)
	part.Shape = Enum.PartType.Ball
	part.CFrame = CFrame.new(position)
	part.Parent = folder
	table.insert(drops, {
		part = part,
		position = position,
		velocity = spread.Unit * speed * random:NextNumber(0.4, 1),
		width = DROP_SIZE * random:NextNumber(0.6, 1.4),
		age = 0,
	})
end

-- A thin shell of light that snaps outward from a headshot.
local function addRing(position: Vector3, direction: Vector3)
	local part = makePart(Vector3.new(0.05, 1, 1), BLOOD_GLOW, Enum.Material.Neon)
	part.Shape = Enum.PartType.Cylinder
	part.CFrame = CFrame.lookAt(position, position + direction) * CFrame.Angles(0, math.rad(90), 0)
	part.Parent = folder
	table.insert(rings, { part = part, age = 0 })
end

local function bleed(shot: any)
	local scale = if shot.head then HEADSHOT_SCALE else 1
	mistAnchor.CFrame = CFrame.lookAt(shot.to, shot.to + shot.direction)
	mist:Emit(MIST_BURST * scale)
	sparks:Emit(SPARKS * scale)
	flashAt = os.clock()
	for _ = 1, DROPS * scale do
		addDrop(shot.to, -shot.direction, DROP_SPEED, 0.8)
	end
	for _ = 1, EXIT_DROPS * scale do
		addDrop(shot.to, shot.direction, EXIT_SPEED, 0.35)
	end
	if shot.head then
		addRing(shot.to, shot.direction)
	end
end

-- Someone else's bullet that misses you close by whizzes past, once per shot, from its closest
-- pellet, timed to the tracer reaching you.
local function whizz(origin: Vector3, shots: { any })
	local listener = workspace.CurrentCamera.CFrame.Position
	local nearest, nearestAlong, nearestDistance = nil, 0, math.huge
	for _, shot in shots do
		if shot.hit ~= player.Character then
			local along, distance = Flyby.pass(origin, shot.to, listener)
			if along and distance and distance < nearestDistance then
				nearest, nearestAlong, nearestDistance = shot, along, distance
			end
		end
	end
	if nearest then
		local direction = (nearest.to - origin).Unit
		local wait = math.max(nearestAlong / TRACER_SPEED - GunSounds.whizzPeakSeconds, 0)
		task.delay(wait, GunAudio.playWhizz, origin + direction * nearestAlong, direction)
	end
end

shotsRemote.OnClientEvent:Connect(function(shooter: Player, origin: Vector3, shots: { any })
	local from = if shooter == player then GunView.muzzle() or origin else origin
	for _, shot in shots do
		-- A collateral sends a blood mark for each body it went through and one tracer past them all.
		if not shot.through then
			addTracer(from, shot.to)
		end
		if shot.hit then
			bleed(shot)
		end
	end
	if shooter ~= player then
		whizz(origin, shots)
	end
end)

local function stepTracers(dt: number)
	for index = #tracers, 1, -1 do
		local tracer = tracers[index]
		tracer.age += dt
		local tail, head = Tracer.span(tracer.total, tracer.age, TRACER_SPEED, TRACER_LENGTH)
		if tail and head then
			local length = math.max(head - tail, 0.01)
			tracer.part.Size = Vector3.new(TRACER_WIDTH, TRACER_WIDTH, length)
			local middle = tracer.from + tracer.unit * ((tail + head) / 2)
			tracer.part.CFrame = CFrame.lookAt(middle, middle + tracer.unit)
		else
			tracer.part:Destroy()
			table.remove(tracers, index)
		end
	end
end

local function stepDrops(dt: number)
	for index = #drops, 1, -1 do
		local drop = drops[index]
		drop.age += dt
		if drop.age < DROP_LIFE then
			drop.velocity += Vector3.new(0, -GRAVITY * dt, 0)
			drop.position += drop.velocity * dt
			local fade = 1 - drop.age / DROP_LIFE
			local width = drop.width * fade
			local speed = drop.velocity.Magnitude
			drop.part.Size = Vector3.new(width, width, width + speed * STREAK * fade)
			drop.part.Shape = if speed * STREAK > width then Enum.PartType.Block else Enum.PartType.Ball
			drop.part.CFrame = CFrame.lookAt(drop.position, drop.position + drop.velocity)
		else
			drop.part:Destroy()
			table.remove(drops, index)
		end
	end
end

local function stepFlash(dt: number)
	local share = 1 - (os.clock() - flashAt) / FLASH_TIME
	flash.Brightness = FLASH_BRIGHTNESS * math.max(share, 0) ^ 2
	for index = #rings, 1, -1 do
		local ring = rings[index]
		ring.age += dt
		local t = ring.age / RING_TIME
		if t < 1 then
			local wide = RING_SIZE * (1 - (1 - t) ^ 3)
			ring.part.Size = Vector3.new(0.05, wide, wide)
			ring.part.Transparency = t * t
		else
			ring.part:Destroy()
			table.remove(rings, index)
		end
	end
end

RunService.RenderStepped:Connect(function(dt)
	stepTracers(dt)
	stepDrops(dt)
	stepFlash(dt)
end)

local function burstCoins(position: Vector3)
	GunAudio.playCoins(position)
	for _ = 1, COINS do
		local coin = Instance.new("Part")
		coin.Name = "Coin"
		coin.Shape = Enum.PartType.Cylinder
		coin.Size = COIN_SIZE
		coin.Color = COIN_COLOR
		coin.Material = Enum.Material.Metal
		coin.Reflectance = 0.2
		coin.CanQuery = false
		coin.CanTouch = false
		coin.CastShadow = false
		coin.CollisionGroup = Collision.corpse
		coin.CFrame = CFrame.new(position + random:NextUnitVector() * 0.5) * CFrame.Angles(
			random:NextNumber(0, 2 * math.pi),
			random:NextNumber(0, 2 * math.pi),
			0
		)
		local angle = random:NextNumber(0, 2 * math.pi)
		coin.AssemblyLinearVelocity = Vector3.new(math.cos(angle), 0, math.sin(angle))
				* random:NextNumber(COIN_OUT[1], COIN_OUT[2])
			+ Vector3.new(0, random:NextNumber(COIN_UP[1], COIN_UP[2]), 0)
		coin.AssemblyAngularVelocity = random:NextUnitVector() * COIN_SPIN
		coin.Parent = folder
		task.delay(COIN_LIFE, function()
			local start = os.clock()
			while coin.Parent and os.clock() - start < COIN_SHRINK do
				local share = 1 - (os.clock() - start) / COIN_SHRINK
				coin.Size = COIN_SIZE * math.max(share, 0.05)
				task.wait()
			end
			coin:Destroy()
		end)
	end
end

deathRemote.OnClientEvent:Connect(burstCoins)
