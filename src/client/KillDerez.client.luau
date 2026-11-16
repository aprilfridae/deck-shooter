-- A body killed by a gun doesn't just drop: it shorts out and is scanned away. It flashes white and flickers between
-- white and Data Cyan, parts of it blinking out, for a moment (the short); then a ring of light runs down it from
-- the top, and everything the ring passes breaks into small cubes of light that burst away from the shot, float up,
-- cool from white to cyan and shrink to nothing. A headshot pops the head into cubes at once, harder. Everyone sees
-- it. Your own body waits a moment first, so the soul sees it drop before it goes. Timings are in KillFx.
-- The server says which body died and who did it with DeathBurst, which also starts the coin burst.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Guns = ReplicatedStorage:WaitForChild("Guns")
local Palette = require(Guns:WaitForChild("Palette"))
local KillFx = require(Guns:WaitForChild("KillFx"))
local Perf = require(script.Parent.Perf)

local SHARDS = 90 -- cubes a whole body breaks into, on a fast machine
local SHARD_PUSH = { 5, 15 } -- studs a second away from the shot
local SHARD_OUT = { 2, 8 } -- and out from the body's middle
local SHARD_UP = { 3, 11 }
local SHARD_SPIN = { 6, 16 } -- radians a second
local SHARD_DRAG = 3.5 -- how fast they slow, a second
local SHARD_RISE = 14 -- studs a second gained upward each second: they float
local HEAD_SHARDS = 2 -- a headshot's head breaks into this many times its share
local HEAD_KICK = 1.8 -- and they fly this much faster
local HEAD_NEAR = 2.5 -- hats and hair this close to the head go with it
local RING_EXTRA = 1.2 -- studs the ring reaches past the body each side
local RING_WIDTH = 0.16
local RING_HEIGHT = 0.06
local LIGHT_BRIGHTNESS = 4
local LIGHT_RANGE = { 8, 18 } -- grows as it fades
local HOT = Color3.new(1, 1, 1)
local COOL = Palette.DataCyan

local player = Players.LocalPlayer
local deathRemote = ReplicatedStorage:WaitForChild("GunRemotes"):WaitForChild("DeathBurst") :: RemoteEvent
local random = Random.new()

local folder = Instance.new("Folder")
folder.Name = "KillDerez"
folder.Parent = workspace

-- A part of the body, with the faces drawn on it (decals) and how see-through each was.
type Piece = { part: BasePart, transparency: number, decals: { [Decal]: number }, gone: boolean }
type Derez = {
	model: Model,
	startedAt: number,
	push: Vector3, -- the way the shot was going, flat
	headshot: boolean,
	pieces: { Piece },
	head: BasePart?,
	headGone: boolean,
	shown: boolean, -- whether the glow is up yet
	glow: Highlight?,
	anchor: BasePart?, -- carries the ring and the light
	ring: CylinderHandleAdornment?,
	light: PointLight?,
	top: number?, -- the body's top and bottom, taken when the scan starts
	bottom: number?,
	middle: Vector3?,
	reach: number?,
	lastStep: number,
}
type Shard = {
	part: BasePart,
	velocity: Vector3,
	axis: Vector3,
	spin: number,
	turn: CFrame,
	size: number,
	age: number,
	life: number,
}

local derezzes: { Derez } = {}
local shards: { Shard } = {}
local started: { [Model]: boolean } = setmetatable({}, { __mode = "k" }) :: any

local function between(range: { number }): number
	return random:NextNumber(range[1], range[2])
end

-- Breaks count cubes off a part. kick makes them fly faster.
local function breakOff(derez: Derez, part: BasePart, count: number, kick: number)
	local middle = derez.middle or part.Position
	for _ = 1, count do
		local size = between(KillFx.SHARD_SIZE)
		local offset = Vector3.new(random:NextNumber(-0.5, 0.5), random:NextNumber(-0.5, 0.5), random:NextNumber(-0.5, 0.5))
			* part.Size
		local at = part.CFrame:PointToWorldSpace(offset)
		local out = at - middle
		out = if out.Magnitude > 0.01 then out.Unit else random:NextUnitVector()
		local shard = Instance.new("Part")
		shard.Name = "Shard"
		shard.Anchored = true
		shard.CanCollide = false
		shard.CanQuery = false
		shard.CanTouch = false
		shard.CastShadow = false
		shard.Material = Enum.Material.Neon
		shard.Color = HOT
		shard.Size = Vector3.one * size
		local turn = CFrame.fromAxisAngle(random:NextUnitVector(), random:NextNumber(0, math.pi))
		shard.CFrame = CFrame.new(at) * turn
		shard.Parent = folder
		table.insert(shards, {
			part = shard,
			velocity = (derez.push * between(SHARD_PUSH) + out * between(SHARD_OUT) + Vector3.yAxis * between(SHARD_UP))
				* kick,
			axis = random:NextUnitVector(),
			spin = between(SHARD_SPIN),
			turn = turn,
			size = size,
			age = 0,
			life = between(KillFx.SHARD_LIFE),
		})
	end
end

local function setShown(piece: Piece, shown: boolean)
	piece.part.Transparency = if shown then piece.transparency else 1
	for decal, transparency in piece.decals do
		decal.Transparency = if shown then transparency else 1
	end
end

local function hide(piece: Piece)
	piece.gone = true
	setShown(piece, false)
end

local function shardBudget(): number
	return Perf.pick(SHARDS, math.floor(SHARDS / 2), math.floor(SHARDS / 4))
end

-- Breaks a part into its share of the body's cubes and hides it.
local function take(derez: Derez, piece: Piece, share: number, kick: number)
	if piece.gone then
		return
	end
	breakOff(derez, piece.part, share, kick)
	hide(piece)
end

-- Each part's share of the body's cubes, by its volume.
local function shares(derez: Derez): { [Piece]: number }
	local volumes = {}
	for index, piece in derez.pieces do
		local size = piece.part.Size
		volumes[index] = size.X * size.Y * size.Z
	end
	local counts = KillFx.shardCounts(volumes, shardBudget())
	local byPiece = {}
	for index, piece in derez.pieces do
		byPiece[piece] = counts[index]
	end
	return byPiece
end

local function isHeadPiece(derez: Derez, part: BasePart): boolean
	local head = derez.head
	if not head then
		return false
	end
	return part == head or (part.Parent ~= nil and part.Parent:IsA("Accessory") and (part.Position - head.Position).Magnitude < HEAD_NEAR)
end

-- The glow, the ring and its light, made when the derez starts.
local function show(derez: Derez)
	derez.shown = true
	derez.model:SetAttribute("Derezzed", true) -- RemotePoses hides the gun and hands it shows on this body
	local glow = Instance.new("Highlight")
	glow.Adornee = derez.model
	glow.DepthMode = Enum.HighlightDepthMode.Occluded
	glow.FillColor = HOT
	glow.OutlineColor = COOL
	glow.OutlineTransparency = 0
	glow.FillTransparency = 0.05
	glow.Parent = folder
	derez.glow = glow

	local anchor = Instance.new("Part")
	anchor.Name = "DerezRing"
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.Transparency = 1
	anchor.Size = Vector3.one * 0.2
	anchor.Parent = folder
	derez.anchor = anchor
	local light = Instance.new("PointLight")
	light.Color = COOL
	light.Brightness = 0
	light.Range = LIGHT_RANGE[1]
	light.Shadows = false
	light.Parent = anchor
	derez.light = light
end

-- Takes the body's measure as the scan starts. It has fallen some way by now, so this is where it lies.
local function measure(derez: Derez)
	local top, bottom = -math.huge, math.huge
	local low, high = Vector3.one * math.huge, -Vector3.one * math.huge
	for _, piece in derez.pieces do
		local part = piece.part
		local half = part.Size.Magnitude * 0.3
		top = math.max(top, part.Position.Y + half)
		bottom = math.min(bottom, part.Position.Y - half)
		low = low:Min(part.Position)
		high = high:Max(part.Position)
	end
	if top < bottom then
		return
	end
	derez.top, derez.bottom = top, bottom
	derez.middle = (low + high) / 2
	local flat = Vector3.new(high.X - low.X, 0, high.Z - low.Z)
	derez.reach = flat.Magnitude / 2 + RING_EXTRA

	local anchor = derez.anchor
	local ring = Instance.new("CylinderHandleAdornment")
	ring.Adornee = anchor
	ring.Radius = derez.reach :: number
	ring.InnerRadius = (derez.reach :: number) - RING_WIDTH
	ring.Height = RING_HEIGHT
	ring.CFrame = CFrame.Angles(math.pi / 2, 0, 0) -- its axis is its Z; stand it up so it lies flat
	ring.Color3 = COOL
	ring.AlwaysOnTop = false
	ring.ZIndex = 1
	ring.Parent = anchor
	derez.ring = ring
end

local function finish(derez: Derez)
	if derez.glow then
		derez.glow:Destroy()
	end
	if derez.anchor then
		derez.anchor:Destroy()
	end
end

local function stepDerez(derez: Derez): boolean
	local age = os.clock() - derez.startedAt
	if age < 0 then
		return true -- your own body, waiting
	end
	if not derez.model.Parent then
		finish(derez)
		return false
	end
	if not derez.shown then
		show(derez)
		if derez.headshot and not derez.headGone then
			derez.headGone = true
			local counts = shares(derez)
			for _, piece in derez.pieces do
				if isHeadPiece(derez, piece.part) then
					take(derez, piece, counts[piece] * HEAD_SHARDS, HEAD_KICK)
				end
			end
		end
	end

	local glow = derez.glow :: Highlight
	local fill, cool = KillFx.glow(age)
	glow.FillTransparency = fill
	glow.FillColor = HOT:Lerp(COOL, cool)
	glow.OutlineTransparency = fill

	local step = KillFx.flickerStep(age)
	if step then
		if step ~= derez.lastStep then
			derez.lastStep = step
			for index, piece in derez.pieces do
				if not piece.gone then
					setShown(piece, not KillFx.blinkedOut(step, index))
				end
			end
		end
		return true
	end

	-- The scan.
	if not derez.top then
		for _, piece in derez.pieces do
			if not piece.gone then
				setShown(piece, true)
			end
		end
		measure(derez)
		if not derez.top then
			finish(derez)
			return false
		end
	end
	local scan = KillFx.scan(age)
	local line = (derez.top :: number) - ((derez.top :: number) - (derez.bottom :: number)) * scan
	local counts: { [Piece]: number }? = nil
	for _, piece in derez.pieces do
		if not piece.gone and (piece.part.Position.Y >= line or scan >= 1) then
			counts = counts or shares(derez)
			take(derez, piece, (counts :: any)[piece], 1)
		end
	end
	local middle = derez.middle :: Vector3
	local anchor = derez.anchor :: BasePart
	anchor.CFrame = CFrame.new(middle.X, line, middle.Z)
	local ring = derez.ring :: CylinderHandleAdornment
	ring.Transparency = KillFx.ring(age)
	local light = derez.light :: PointLight
	local fade = 1 - math.min((age - KillFx.SHORT) / (KillFx.SCAN + KillFx.RING_FADE), 1)
	light.Brightness = LIGHT_BRIGHTNESS * fade
	light.Range = LIGHT_RANGE[1] + (LIGHT_RANGE[2] - LIGHT_RANGE[1]) * (1 - fade)

	if KillFx.done(age) then
		finish(derez)
		return false
	end
	return true
end

local function stepShards(dt: number)
	local parts, frames = {}, {}
	for index = #shards, 1, -1 do
		local shard = shards[index]
		shard.age += dt
		local share = shard.age / shard.life
		if share >= 1 then
			shard.part:Destroy()
			table.remove(shards, index)
		else
			shard.velocity = shard.velocity * math.exp(-dt * SHARD_DRAG) + Vector3.yAxis * SHARD_RISE * dt
			shard.turn = CFrame.fromAxisAngle(shard.axis, shard.spin * dt) * shard.turn
			local size, cool, transparency = KillFx.shard(share)
			shard.part.Size = Vector3.one * math.max(shard.size * size, 0.02)
			shard.part.Color = HOT:Lerp(COOL, cool)
			shard.part.Transparency = transparency
			table.insert(parts, shard.part)
			table.insert(frames, CFrame.new(shard.part.Position + shard.velocity * dt) * shard.turn)
		end
	end
	if #parts > 0 then
		workspace:BulkMoveTo(parts, frames, Enum.BulkMoveMode.FireCFrameChanged)
	end
end

RunService.RenderStepped:Connect(function(dt)
	for index = #derezzes, 1, -1 do
		if not stepDerez(derezzes[index]) then
			table.remove(derezzes, index)
		end
	end
	stepShards(dt)
end)

-- The way the shot was going: from the killer through the body, flat. Straight up if nobody is known.
local function pushFrom(body: Vector3, killer: Player?): Vector3
	local root = killer and killer.Character and killer.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if root then
		local away = body - root.Position
		local flat = Vector3.new(away.X, 0, away.Z)
		if flat.Magnitude > 0.5 then
			return flat.Unit
		end
	end
	return Vector3.zero
end

local function begin(at: Vector3, killer: Player?, model: Model?, headshot: boolean?)
	if typeof(model) ~= "Instance" or not model:IsA("Model") or not model.Parent or started[model] then
		return
	end
	started[model] = true
	local pieces: { Piece } = {}
	for _, item in model:GetDescendants() do
		if item:IsA("BasePart") and item.Name ~= "HumanoidRootPart" and item.Transparency < 1 then
			local decals = {}
			for _, child in item:GetChildren() do
				if child:IsA("Decal") then
					decals[child] = child.Transparency
				end
			end
			table.insert(pieces, { part = item, transparency = item.Transparency, decals = decals, gone = false })
		end
	end
	if #pieces == 0 then
		return
	end
	local head = model:FindFirstChild("Head")
	table.insert(derezzes, {
		model = model,
		startedAt = os.clock() + (if model == player.Character then KillFx.OWN_DELAY else 0),
		push = pushFrom(at, killer),
		headshot = headshot == true,
		pieces = pieces,
		head = if head and head:IsA("BasePart") then head else nil,
		headGone = false,
		shown = false,
		lastStep = -1,
	})
end

deathRemote.OnClientEvent:Connect(begin)
