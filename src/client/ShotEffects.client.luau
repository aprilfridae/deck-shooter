-- Bullet tracers and blood. The server sends where each bullet really went, spread included.
local Palette = require(game:GetService("ReplicatedStorage"):WaitForChild("Guns"):WaitForChild("Palette"))
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local GunView = require(script.Parent.GunView)
local Tracer = require(ReplicatedStorage.Guns.Tracer)
local Collision = require(ReplicatedStorage.Guns.Collision)

local remotes = ReplicatedStorage:WaitForChild("GunRemotes")
local shotsRemote = remotes:WaitForChild("Shots") :: RemoteEvent

local TRACER_SPEED = 600
local TRACER_LENGTH = 12
local TRACER_WIDTH = 0.07
local TRACER_COLOR = Palette.DataCyan

local BLOOD_COLOR = Palette.HazardRed
local MIST_BURST = 30
local DROPS = 18
local HEADSHOT_SCALE = 2 -- headshots throw this much more blood
local DROP_SPEED = 26
local DROP_LIFE = 0.45
local DROP_SIZE = 0.16
local GRAVITY = 110
local SPLAT_REACH = 9
local SPLAT_MIN = 0.9
local SPLAT_MAX = 2.2
local SPLAT_LIFE = 20
local MAX_SPLATS = 140
local SURFACE_GAP = 0.02

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
local splats: { BasePart } = {}

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

local function addSplat(position: Vector3, normal: Vector3)
	local size = random:NextNumber(SPLAT_MIN, SPLAT_MAX)
	local part = makePart(Vector3.new(size, size, 0.03), BLOOD_COLOR, Enum.Material.SmoothPlastic)
	local front = position + normal * SURFACE_GAP
	part.CFrame = CFrame.lookAt(front, front + normal) * CFrame.Angles(0, 0, random:NextNumber(0, math.pi))
	part.Parent = folder
	table.insert(splats, part)
	if #splats > MAX_SPLATS then
		table.remove(splats, 1):Destroy()
	end
	task.delay(SPLAT_LIFE, function()
		local index = table.find(splats, part)
		if index then
			table.remove(splats, index)
			part:Destroy()
		end
	end)
end

-- Blood lands on whatever is behind the target, then on the ground beneath it.
local function splatter(position: Vector3, direction: Vector3, hit: Instance?)
	local ignored: { Instance } = { folder, workspace.CurrentCamera }
	if hit then
		table.insert(ignored, hit)
	end
	if player.Character then
		table.insert(ignored, player.Character)
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignored
	params.RespectCanCollide = true
	Collision.forShots(params)
	for _, reach in { direction * SPLAT_REACH, Vector3.new(0, -SPLAT_REACH, 0) } do
		local surface = workspace:Raycast(position, reach, params)
		if surface then
			addSplat(surface.Position, surface.Normal)
		end
	end
end

local function bleed(shot: any)
	local scale = if shot.head then HEADSHOT_SCALE else 1
	mistAnchor.CFrame = CFrame.lookAt(shot.to, shot.to + shot.direction)
	mist:Emit(MIST_BURST * scale)
	for _ = 1, DROPS * scale do
		addDrop(shot.to, -shot.direction)
	end
	splatter(shot.to, shot.direction, shot.hit)
end

shotsRemote.OnClientEvent:Connect(function(shooter: Player, origin: Vector3, shots: { any })
	local from = if shooter == player then GunView.muzzle() or origin else origin
	for _, shot in shots do
		addTracer(from, shot.to)
		if shot.hit then
			bleed(shot)
		end
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
