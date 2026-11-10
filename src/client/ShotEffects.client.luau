-- Bullet tracers and what a hit throws off: no blood, but a burst of electricity, with nothing left behind. The server sends where each
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
-- Coins burst out of a body when it dies, hang for a moment, then are pulled to whoever made the kill. They're
-- small wireframes in Signal Acid with a streak behind each for motion blur. They burst, fall and bounce with real
-- physics; the pull to the killer is done in code.
local COINS = 16
local COIN_RADIUS = 0.2
local COIN_THICK = 0.06
local COIN_SIDES = 12 -- straight edges round each rim
local COIN_LINE = 1.5 -- pixels
local COIN_COLOR = Palette.SignalAcid
local COIN_UP = { 26, 44 }
local COIN_OUT = { 10, 24 }
local COIN_SPIN = 25 -- radians a second
local COIN_HANG = 0.8 -- seconds of falling and bouncing before the first is pulled
local COIN_STAGGER = 0.35 -- and the last, this much later
local COIN_PULL = 160 -- studs a second gained each second of pull
local COIN_PULL_TOP = 110
local COIN_TAKEN = 1.6 -- studs from the killer where a coin is taken
local COIN_BLUR = 0.09 -- seconds of its path the streak covers
local COIN_LIFE = 3 -- seconds at most, if there's nobody to go to
local TRACER_LENGTH = 12
local TRACER_WIDTH = 0.07
local TRACER_COLOR = Palette.DataCyan

-- A hit doesn't bleed: it shorts out. A white-hot pop, a shower of sparks, hot streaks that arc away and fall, a few
-- jagged bolts that crackle out of it for an instant, and a hard flash of light on everything nearby. White at the
-- core and Data Cyan as it cools. (The names below still say blood, mist and drops from when it was blood.)
local BLOOD_COLOR = Color3.new(1, 1, 1) -- the pop
local BLOOD_GLOW = Palette.DataCyan -- streaks, bolts and the headshot ring
local BLOOD_LIGHT = Color3.fromRGB(170, 240, 255) -- the light it throws
local MIST_BURST = 6 -- puffs in the pop
local SPARKS = 40
local DROPS = 18 -- streaks back toward the shooter
local EXIT_DROPS = 14 -- and out the far side, faster and tighter
local HEADSHOT_SCALE = 2 -- headshots throw this much more
local DROP_SPEED = 42
local EXIT_SPEED = 72
local DROP_LIFE = 0.3
local DROP_SIZE = 0.07
local STREAK = 0.03 -- a streak stretches this many studs along its path per stud a second it moves
local GRAVITY = 90
local FLASH_BRIGHTNESS = 5
local FLASH_RANGE = 11
local FLASH_TIME = 0.1
local BOLTS = 3 -- jagged bolts out of a hit
local BOLT_REACH = { 1.5, 4 } -- studs
local BOLT_KINKS = 4 -- straight pieces in each
local BOLT_JITTER = 0.5 -- how far each kink strays
local BOLT_WIDTH = 0.05
local BOLT_TIME = 0.07 -- seconds a bolt shows, redrawn once on the way so it crackles
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
mist.Color = ColorSequence.new(BLOOD_COLOR, BLOOD_GLOW)
mist.LightEmission = 1
mist.LightInfluence = 0
mist.Lifetime = NumberRange.new(0.06, 0.14)
mist.Speed = NumberRange.new(2, 9)
mist.SpreadAngle = Vector2.new(180, 180)
mist.Drag = 6
mist.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.8), NumberSequenceKeypoint.new(1, 2.6) })
mist.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.15), NumberSequenceKeypoint.new(1, 1) })
mist.EmissionDirection = Enum.NormalId.Back
mist.Rate = 0
mist.Parent = mistAnchor
-- Bright specks that spit out of the wound and glow.
local sparks = Instance.new("ParticleEmitter")
sparks.Texture = "rbxasset://textures/particles/sparkles_main.dds"
sparks.Color = ColorSequence.new(BLOOD_COLOR, BLOOD_GLOW)
sparks.LightEmission = 1
sparks.LightInfluence = 0
sparks.Lifetime = NumberRange.new(0.15, 0.45)
sparks.Speed = NumberRange.new(20, 62)
sparks.SpreadAngle = Vector2.new(180, 180)
sparks.Drag = 3
sparks.Acceleration = Vector3.new(0, -60, 0)
sparks.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 0) })
sparks.EmissionDirection = Enum.NormalId.Back
sparks.Rate = 0
sparks.Parent = mistAnchor
-- A hard flash lights up whatever is around the hit.
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
	-- Some streaks are white-hot, the rest already cooling.
	local part = makePart(
		Vector3.one * DROP_SIZE,
		if random:NextNumber() < 0.4 then BLOOD_COLOR else BLOOD_GLOW,
		Enum.Material.Neon
	)
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

-- Jagged bolts that crackle out of a hit for an instant.
local bolts: { any } = {}
local function drawBolt(bolt: any)
	local at = bolt.from
	for kink, part in bolt.parts do
		local share = kink / #bolt.parts
		local to = bolt.from + bolt.reach * share + (if kink < #bolt.parts then random:NextUnitVector() * BOLT_JITTER else Vector3.zero)
		part.Size = Vector3.new(BOLT_WIDTH, BOLT_WIDTH, (to - at).Magnitude)
		part.CFrame = CFrame.lookAt((at + to) / 2, to)
		at = to
	end
end
local function addBolt(position: Vector3, away: Vector3)
	local reach = (away + random:NextUnitVector() * 1.4).Unit * random:NextNumber(BOLT_REACH[1], BOLT_REACH[2])
	local bolt = { from = position, reach = reach, parts = {}, age = 0, redrawn = false }
	for kink = 1, BOLT_KINKS do
		local part = makePart(Vector3.one * BOLT_WIDTH, if kink % 2 == 0 then BLOOD_COLOR else BLOOD_GLOW, Enum.Material.Neon)
		part.Parent = folder
		bolt.parts[kink] = part
	end
	drawBolt(bolt)
	table.insert(bolts, bolt)
end
local function stepBolts(dt: number)
	for index = #bolts, 1, -1 do
		local bolt = bolts[index]
		bolt.age += dt
		if bolt.age >= BOLT_TIME then
			for _, part in bolt.parts do
				part:Destroy()
			end
			table.remove(bolts, index)
		elseif not bolt.redrawn and bolt.age >= BOLT_TIME / 2 then
			bolt.redrawn = true
			drawBolt(bolt) -- a new jagged path to the same place
		end
	end
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
	for _ = 1, BOLTS * scale do
		addBolt(shot.to, -shot.direction)
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
	stepBolts(dt)
	stepFlash(dt)
end)

-- One coin: nothing but its edges, drawn as lines in Signal Acid. Two rims joined across the edge, and a diamond
-- on each face.
local function coinLines(wire: WireframeHandleAdornment)
	local rims = { {}, {} }
	for side = 1, COIN_SIDES do
		local turn = side / COIN_SIDES * 2 * math.pi
		local y, z = math.cos(turn) * COIN_RADIUS, math.sin(turn) * COIN_RADIUS
		rims[1][side] = Vector3.new(-COIN_THICK / 2, y, z)
		rims[2][side] = Vector3.new(COIN_THICK / 2, y, z)
		if side % 3 == 0 then
			wire:AddLine(rims[1][side], rims[2][side])
		end
	end
	for face, rim in rims do
		wire:AddPath(rim, true)
		local x = rim[1].X
		local mark = COIN_RADIUS * 0.5
		wire:AddPath({
			Vector3.new(x, mark, 0),
			Vector3.new(x, 0, mark),
			Vector3.new(x, -mark, 0),
			Vector3.new(x, 0, -mark),
		}, true)
	end
end

local coins: { any } = {}

-- Coins burst out of a body when it dies, hang for a moment, then are pulled to whoever made the kill.
local function burstCoins(position: Vector3, killer: Player?)
	GunAudio.playCoins(position)
	local burst = { sucked = false } -- whether this burst's pull has made its sound yet
	for index = 1, COINS do
		local part = Instance.new("Part")
		part.Name = "Coin"
		part.Shape = Enum.PartType.Cylinder -- lies along X, so this is a flat coin: what it lands and rolls on
		part.Size = Vector3.new(COIN_THICK, COIN_RADIUS * 2, COIN_RADIUS * 2)
		part.Transparency = 1 -- only its wireframe shows
		part.CollisionGroup = Collision.corpse
		part.CanQuery = false
		part.CanTouch = false
		part.CastShadow = false
		local wire = Instance.new("WireframeHandleAdornment")
		wire.Color3 = COIN_COLOR
		wire.Thickness = COIN_LINE
		wire.Adornee = part
		coinLines(wire)
		wire.Parent = part
		-- Motion blur: a streak the width of the coin trails where it has just been.
		local top, bottom = Instance.new("Attachment"), Instance.new("Attachment")
		top.Position, bottom.Position = Vector3.new(0, COIN_RADIUS, 0), Vector3.new(0, -COIN_RADIUS, 0)
		top.Parent, bottom.Parent = part, part
		local blur = Instance.new("Trail")
		blur.Attachment0, blur.Attachment1 = top, bottom
		blur.Color = ColorSequence.new(COIN_COLOR)
		blur.LightEmission = 1
		blur.LightInfluence = 0
		blur.Lifetime = COIN_BLUR
		blur.MinLength = 0
		blur.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.45), NumberSequenceKeypoint.new(1, 1) })
		blur.Parent = part
		local angle = random:NextNumber(0, 2 * math.pi)
		part.CFrame = CFrame.new(position + random:NextUnitVector() * 0.5)
			* CFrame.Angles(random:NextNumber(0, 2 * math.pi), random:NextNumber(0, 2 * math.pi), 0)
		part.Parent = folder
		-- Physics throws it, drops it and bounces it.
		part.AssemblyLinearVelocity = Vector3.new(math.cos(angle), 0, math.sin(angle))
				* random:NextNumber(COIN_OUT[1], COIN_OUT[2])
			+ Vector3.new(0, random:NextNumber(COIN_UP[1], COIN_UP[2]), 0)
		part.AssemblyAngularVelocity = random:NextUnitVector() * COIN_SPIN
		table.insert(coins, {
			part = part,
			pulling = false, -- whether code has taken it over from physics
			burst = burst,
			position = part.Position,
			velocity = Vector3.zero,
			turn = CFrame.identity,
			spin = Vector3.zero,
			age = 0,
			pullAt = COIN_HANG + (index - 1) / COINS * COIN_STAGGER, -- they peel off one after another
			killer = killer,
		})
	end
end

local function stepCoins(dt: number)
	for index = #coins, 1, -1 do
		local coin = coins[index]
		coin.age += dt
		local character = coin.killer and coin.killer.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local pulled = coin.age - coin.pullAt
		local done = coin.age > COIN_LIFE
		if pulled > 0 and root then
			if not coin.pulling then
				-- Code takes it from wherever physics left it, still moving and spinning as it was.
				coin.pulling = true
				if not coin.burst.sucked then
					coin.burst.sucked = true
					GunAudio.playCoinSuck(root :: BasePart) -- once, as the first one goes
				end
				coin.position = coin.part.Position
				coin.velocity = coin.part.AssemblyLinearVelocity
				coin.turn = coin.part.CFrame.Rotation
				coin.spin = coin.part.AssemblyAngularVelocity
				coin.part.Anchored = true
				coin.part.CanCollide = false
			end
			-- Pulled in like a magnet: slowly at first, then faster and straighter the longer it goes.
			local to = (root :: BasePart).Position - coin.position
			local speed = math.min(COIN_PULL * pulled, COIN_PULL_TOP)
			local steer = 1 - math.exp(-dt * (4 + 30 * pulled))
			coin.velocity = coin.velocity:Lerp(to.Unit * math.max(speed, coin.velocity.Magnitude * 0.6), steer)
			if to.Magnitude < COIN_TAKEN + speed * dt then
				done = true
			end
		end
		if done then
			coin.part:Destroy()
			table.remove(coins, index)
		elseif coin.pulling then
			coin.position += coin.velocity * dt
			local spun = coin.spin * dt
			if spun.Magnitude > 1e-4 then
				coin.turn = CFrame.fromAxisAngle(spun.Unit, spun.Magnitude) * coin.turn
			end
			coin.part.CFrame = CFrame.new(coin.position) * coin.turn
		end
	end
end
RunService.RenderStepped:Connect(stepCoins)

deathRemote.OnClientEvent:Connect(burstCoins)
