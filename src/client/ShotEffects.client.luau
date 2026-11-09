-- Bullet tracers and blood: an acid green mist and drops, with no splats left behind. The server sends where each
-- bullet really went, spread included.
local Palette = require(game:GetService("ReplicatedStorage"):WaitForChild("Guns"):WaitForChild("Palette"))
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local GunAudio = require(script.Parent.GunAudio)
local GunSounds = require(ReplicatedStorage.Guns.GunSounds)
local GunView = require(script.Parent.GunView)
local Flyby = require(ReplicatedStorage.Guns.Flyby)
local Tracer = require(ReplicatedStorage.Guns.Tracer)

local remotes = ReplicatedStorage:WaitForChild("GunRemotes")
local shotsRemote = remotes:WaitForChild("Shots") :: RemoteEvent

local TRACER_SPEED = 600
local TRACER_LENGTH = 12
local TRACER_WIDTH = 0.07
local TRACER_COLOR = Palette.DataCyan

local BLOOD_COLOR = Palette.SignalAcid -- acid green, not red
local MIST_BURST = 30
local DROPS = 18
local HEADSHOT_SCALE = 2 -- headshots throw this much more blood
local DROP_SPEED = 26
local DROP_LIFE = 0.45
local DROP_SIZE = 0.16
local GRAVITY = 110

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
mist.LightEmission = 0
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

local function addDrop(position: Vector3, direction: Vector3)
	local spread = direction + random:NextUnitVector() * 0.8
	local size = Vector3.one * DROP_SIZE * random:NextNumber(0.6, 1.4)
	local part = makePart(size, BLOOD_COLOR, Enum.Material.SmoothPlastic)
	part.CFrame = CFrame.new(position)
	part.Parent = folder
	table.insert(drops, {
		part = part,
		velocity = spread.Unit * DROP_SPEED * random:NextNumber(0.4, 1),
		size = size,
		age = 0,
	})
end

local function bleed(shot: any)
	local scale = if shot.head then HEADSHOT_SCALE else 1
	mistAnchor.CFrame = CFrame.lookAt(shot.to, shot.to + shot.direction)
	mist:Emit(MIST_BURST * scale)
	for _ = 1, DROPS * scale do
		addDrop(shot.to, -shot.direction)
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
		addTracer(from, shot.to)
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
			drop.part.Position += drop.velocity * dt
			drop.part.Size = drop.size * (1 - drop.age / DROP_LIFE)
		else
			drop.part:Destroy()
			table.remove(drops, index)
		end
	end
end

RunService.RenderStepped:Connect(function(dt)
	stepTracers(dt)
	stepDrops(dt)
end)
