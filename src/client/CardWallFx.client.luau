-- Draws Bulwark's walls (CardWalls.luau on the server, found by the CardWall tag). The server's part is the real,
-- invisible wall; this draws a giant card on it. It swings up off the ground onto its long edge with a burst of
-- dust and an acid ring, faces the way its thrower looked (its face to the enemy, its back to the thrower), jolts
-- and flashes when shot, flickers when nearly gone, and either shatters (shot down) or sinks away (time up).
local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local CardCore = ReplicatedStorage:WaitForChild("CardCore")
local CardArt = require(CardCore:WaitForChild("CardArt"))
local CardLook = require(CardCore:WaitForChild("CardLook"))
local Variant = require(CardCore:WaitForChild("Variant"))
local Palette = require(ReplicatedStorage:WaitForChild("Guns"):WaitForChild("Palette"))

local TAG = "CardWall"
local RISE = 0.24 -- seconds it takes to stand up
local OVERSHOOT = 1.7 -- how far past upright it springs (Back easing's strength)
local HIT_SECONDS = 0.12
local HIT_JOLT = 0.12 -- studs it's knocked back by a hit
local LOW = 0.35 -- of its health: below this it flickers
local SINK_SECONDS = 0.35
local SHARDS = 18
local EDGE = 0.12 -- studs: the glowing rim's width
local PIXELS_ACROSS = 1100 -- the printed face's size

local random = Random.new()

type Shown = {
	wall: BasePart,
	model: Model,
	card: Part,
	rim: { Part },
	glow: SurfaceLight,
	bornAt: number,
	hitAt: number,
	hp: number,
	maxHp: number,
	connections: { RBXScriptConnection },
}

local shown: { [BasePart]: Shown } = {}

local function piece(name: string, size: Vector3, color: Color3, material: Enum.Material): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Color = color
	part.Material = material
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = true
	return part
end

-- An image laid on one face of the card, turned a quarter so a tall card picture fills the wide face.
local function printOn(card: Part, face: Enum.NormalId, image: string?, fallback: Color3)
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
	local wide = PIXELS_ACROSS
	local tall = math.floor(wide * card.Size.Y / card.Size.X)
	gui.CanvasSize = Vector2.new(wide, tall)
	gui.LightInfluence = 1
	gui.Parent = card
	local label = Instance.new("ImageLabel")
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Position = UDim2.fromScale(0.5, 0.5)
	label.Size = UDim2.fromOffset(tall, wide)
	label.Rotation = 90
	label.BackgroundColor3 = fallback
	label.BackgroundTransparency = if image then 1 else 0
	label.Image = image or ""
	label.ScaleType = Enum.ScaleType.Stretch
	label.Parent = gui
	if not image then
		-- No art yet: a plain card in the tier's colour with a Bone border.
		local stroke = Instance.new("UIStroke")
		stroke.Color = Palette.Bone
		stroke.Thickness = 24
		stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		stroke.Parent = label
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 60)
		corner.Parent = label
	end
end

local function tierColor(tier: any): Color3
	return (Palette.Tiers :: any)[tier] or Palette.Bone
end

-- Where the card stands, `risen` from 0 (down in the ground) to 1 (up), plus any jolt.
local function placed(entry: Shown, risen: number, jolt: number): CFrame
	local wall = entry.wall
	local height = wall.Size.Y
	-- It swings up like a drawbridge, hinged on its bottom edge: from lying face down where the card was slapped,
	-- top edge toward the enemy, up onto its edge (and a little past, toward its thrower, as it springs).
	local base = wall.CFrame * CFrame.new(0, -height / 2, 0)
	local lean = math.rad(90) * (1 - risen)
	return base * CFrame.new(0, 0, jolt) * CFrame.Angles(-lean, 0, 0) * CFrame.new(0, height / 2, 0)
end

local function dust(at: CFrame, width: number)
	local holder = piece("Dust", Vector3.new(width, 0.2, 1), Palette.Bone, Enum.Material.SmoothPlastic)
	holder.Transparency = 1
	holder.CFrame = at
	holder.Parent = workspace
	local smoke = Instance.new("ParticleEmitter")
	smoke.Texture = "rbxasset://textures/particles/smoke_main.dds"
	smoke.Color = ColorSequence.new(Color3.fromRGB(150, 150, 145))
	smoke.LightInfluence = 0.6
	smoke.Lifetime = NumberRange.new(0.5, 0.9)
	smoke.Speed = NumberRange.new(5, 11)
	smoke.SpreadAngle = Vector2.new(70, 20)
	smoke.EmissionDirection = Enum.NormalId.Top
	smoke.Drag = 4
	smoke.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.2), NumberSequenceKeypoint.new(1, 3.5) })
	smoke.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.55), NumberSequenceKeypoint.new(1, 1) })
	smoke.Rate = 0
	smoke.Parent = holder
	smoke:Emit(20)
	local ring = piece("Ring", Vector3.new(0.1, 2, 2), Palette.SignalAcid, Enum.Material.Neon)
	ring.Shape = Enum.PartType.Cylinder
	ring.CastShadow = false
	ring.CFrame = at * CFrame.Angles(0, 0, math.rad(90))
	ring.Transparency = 0.2
	ring.Parent = workspace
	TweenService:Create(ring, TweenInfo.new(0.4, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
		Size = Vector3.new(0.05, width * 1.6, width * 1.6),
		Transparency = 1,
	}):Play()
	Debris:AddItem(ring, 0.5)
	Debris:AddItem(holder, 1.2)
end

local function build(wall: BasePart)
	if shown[wall] then
		return
	end
	local tier = wall:GetAttribute("Tier")
	local look = if type(tier) == "string" then CardLook.look(tier, Variant.Base) else nil
	local image = if look then CardArt.base("bulwark", look) else nil
	local model = Instance.new("Model")
	model.Name = "BulwarkCard"
	local card = piece("Card", wall.Size, Palette.Bone, Enum.Material.SmoothPlastic)
	card.Parent = model
	printOn(card, Enum.NormalId.Front, image, tierColor(tier)) -- its face, to the enemy
	printOn(card, Enum.NormalId.Back, CardArt.HAND_BACK, Palette.DeepNavy) -- its back, to the thrower
	-- A thin glowing rim round its edge, in the tier's colour.
	local rim = {}
	local w, h, t = wall.Size.X, wall.Size.Y, wall.Size.Z + 0.02
	for _, spec in {
		{ Vector3.new(w, EDGE, t), Vector3.new(0, h / 2, 0) },
		{ Vector3.new(w, EDGE, t), Vector3.new(0, -h / 2, 0) },
		{ Vector3.new(EDGE, h, t), Vector3.new(w / 2, 0, 0) },
		{ Vector3.new(EDGE, h, t), Vector3.new(-w / 2, 0, 0) },
	} do
		local edge = piece("Rim", spec[1], tierColor(tier), Enum.Material.Neon)
		edge.CastShadow = false
		edge:SetAttribute("Offset", spec[2])
		edge.Parent = model
		table.insert(rim, edge)
	end
	local glow = Instance.new("SurfaceLight")
	glow.Face = Enum.NormalId.Front
	glow.Color = tierColor(tier)
	glow.Range = 10
	glow.Brightness = 1.2
	glow.Angle = 120
	glow.Parent = card
	model.Parent = workspace
	local maxHp = wall:GetAttribute("WallMaxHp")
	local entry: Shown = {
		wall = wall,
		model = model,
		card = card,
		rim = rim,
		glow = glow,
		bornAt = os.clock(),
		hitAt = -1,
		hp = wall:GetAttribute("WallHp") or 1,
		maxHp = if type(maxHp) == "number" and maxHp > 0 then maxHp else 1,
		connections = {},
	}
	shown[wall] = entry
	table.insert(entry.connections, wall:GetAttributeChangedSignal("WallHp"):Connect(function()
		local hp = wall:GetAttribute("WallHp")
		if type(hp) == "number" and hp < entry.hp then
			entry.hitAt = os.clock()
		end
		entry.hp = if type(hp) == "number" then hp else entry.hp
	end))
	dust(wall.CFrame * CFrame.new(0, -wall.Size.Y / 2 + 0.1, 0), wall.Size.X)
end

local function shatter(entry: Shown)
	local card = entry.card
	for _ = 1, SHARDS do
		local size = Vector3.new(random:NextNumber(0.6, 1.6), random:NextNumber(0.5, 1.3), card.Size.Z * 0.6)
		local shard = piece("Shard", size, if random:NextNumber() < 0.6 then Palette.Bone else Palette.DeepNavy, Enum.Material.SmoothPlastic)
		local at = card.CFrame * CFrame.new(random:NextNumber(-0.5, 0.5) * card.Size.X, random:NextNumber(-0.5, 0.5) * card.Size.Y, 0)
		shard.CFrame = at
		shard.Parent = workspace
		local away = (at.Position - card.Position) + card.CFrame.LookVector * random:NextNumber(-3, 3)
		local seconds = random:NextNumber(0.4, 0.7)
		TweenService:Create(shard, TweenInfo.new(seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			CFrame = at
				* CFrame.new(away * 0.6 + Vector3.new(0, random:NextNumber(-2, 1), 0))
				* CFrame.Angles(random:NextNumber(-3, 3), random:NextNumber(-3, 3), random:NextNumber(-3, 3)),
			Size = size * 0.3,
			Transparency = 1,
		}):Play()
		Debris:AddItem(shard, seconds + 0.1)
	end
	local flash = piece("Flash", card.Size * Vector3.new(1, 1, 2), Palette.Bone, Enum.Material.Neon)
	flash.CastShadow = false
	flash.CFrame = card.CFrame
	flash.Transparency = 0.3
	flash.Parent = workspace
	TweenService:Create(flash, TweenInfo.new(0.2), { Transparency = 1, Size = card.Size * Vector3.new(1.15, 1.15, 2) }):Play()
	Debris:AddItem(flash, 0.3)
	entry.model:Destroy()
end

local function sink(entry: Shown)
	local started = os.clock()
	local connection: RBXScriptConnection
	connection = RunService.RenderStepped:Connect(function()
		local share = math.min((os.clock() - started) / SINK_SECONDS, 1)
		local risen = 1 - share * share
		local frame = placed(entry, risen, 0)
		entry.card.CFrame = frame
		for _, edge in entry.rim do
			edge.CFrame = frame * CFrame.new(edge:GetAttribute("Offset") :: Vector3)
			edge.Transparency = share
		end
		if share >= 1 then
			connection:Disconnect()
			entry.model:Destroy()
		end
	end)
end

local function gone(wall: BasePart)
	local entry = shown[wall]
	if not entry then
		return
	end
	shown[wall] = nil
	for _, connection in entry.connections do
		connection:Disconnect()
	end
	if wall:GetAttribute("Broken") or entry.hp <= 0 then
		shatter(entry)
	else
		sink(entry)
	end
end

RunService.RenderStepped:Connect(function()
	local now = os.clock()
	for _, entry in shown do
		local age = now - entry.bornAt
		local share = math.min(age / RISE, 1)
		-- Back easing: up past upright, and settles.
		local c = OVERSHOOT
		local risen = 1 + (c + 1) * (share - 1) ^ 3 + c * (share - 1) ^ 2
		local since = now - entry.hitAt
		local jolt = if since < HIT_SECONDS then HIT_JOLT * math.sin(since / HIT_SECONDS * math.pi) else 0
		local frame = placed(entry, risen, jolt)
		entry.card.CFrame = frame
		local low = entry.hp / entry.maxHp < LOW
		local flicker = low and math.sin(now * 40) > 0.3
		for _, edge in entry.rim do
			edge.CFrame = frame * CFrame.new(edge:GetAttribute("Offset") :: Vector3)
			edge.Transparency = if flicker then 0.7 else 0
		end
		-- A hit flashes it white for a moment.
		entry.card.Material = if since < HIT_SECONDS then Enum.Material.Neon else Enum.Material.SmoothPlastic
		entry.glow.Brightness = if since < HIT_SECONDS then 4 else (if flicker then 0.3 else 1.2)
	end
end)

CollectionService:GetInstanceAddedSignal(TAG):Connect(function(wall)
	if wall:IsA("BasePart") then
		build(wall)
	end
end)
CollectionService:GetInstanceRemovedSignal(TAG):Connect(function(wall)
	if wall:IsA("BasePart") then
		gone(wall)
	end
end)
for _, wall in CollectionService:GetTagged(TAG) do
	if wall:IsA("BasePart") then
		build(wall)
	end
end
