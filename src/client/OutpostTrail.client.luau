-- A soft glowing blur behind your own character in the Outpost. Roblox can't blur an object, so it's
-- made of very faint neon copies of your whole body, hair and accessories included, packed close
-- and each nudged a little at random so their edges melt together. Only you see yours.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Guns = ReplicatedStorage:WaitForChild("Guns")
local Palette = require(Guns:WaitForChild("Palette"))
local Zones = require(Guns:WaitForChild("Zones"))

local BODY_GROUP = "BodyMesh" -- from CharacterBody.server.luau; it never touches the world
local COPIES = 24
local STAMP_EVERY = 0.012 -- seconds; every frame at 60 fps, so the copies run together
local LIFETIME = 0.22 -- seconds
local FADE_EVERY = 1 / 30 -- seconds
local SPREAD = 0.12 -- studs each copy is nudged, which softens its edges
local MIN_MOVE = 0.1 -- studs a player must move for a new copy
local START_FADE = 0.975 -- how see-through a copy is when it's left, kept high as they stack up
local SETTLE = 0.5 -- seconds; the rest of the body is still arriving
local APPEARANCE_WAIT = 5 -- seconds
local ID = "OutpostTrailId"

-- Anything that would give a copy its own look, or stop it being posed by its parts.
local STRIPPED = {
	Animator = true,
	BodyColors = true,
	Decal = true,
	Highlight = true,
	HumanoidDescription = true,
	ParticleEmitter = true,
	PointLight = true,
	ShirtGraphic = true,
	Sound = true,
	SurfaceAppearance = true,
	Trail = true,
	WrapLayer = true,
	WrapTarget = true,
}

type Copy = {
	model: Model,
	parts: { BasePart }, -- all of them, lined up with the trail's sources
	shown: { BasePart }, -- the ones that are seen
	bornAt: number,
}

type Trail = {
	folder: Folder,
	root: BasePart,
	sources: { BasePart },
	copies: { Copy },
	nextCopy: number,
	nextStamp: number,
	stampedAt: Vector3?,
}

local player = Players.LocalPlayer
local trail: Trail? = nil
local random = Random.new()

local function dress(ghost: Model)
	for _, item in ghost:GetDescendants() do
		if STRIPPED[item.ClassName] or item:IsA("Clothing") or item:IsA("LuaSourceContainer") then -- Shirt, Pants
			item:Destroy()
		end
	end
	for _, item in ghost:GetDescendants() do
		if item:IsA("MeshPart") then
			item.TextureID = ""
		elseif item:IsA("SpecialMesh") then
			item.TextureId = ""
		end
		if item:IsA("BasePart") then
			item.Anchored = true
			item.CanCollide = false
			item.CanQuery = false
			item.CanTouch = false
			item.CastShadow = false
			item.CollisionGroup = BODY_GROUP
			item.Material = Enum.Material.Neon
		end
	end
	local humanoid = ghost:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	end
end

-- Marks the body's parts, so each one can be found again in the copy.
local function makeCopy(character: Model, sources: { BasePart }): Copy
	for index, part in sources do
		part:SetAttribute(ID, index)
	end
	local archivable = character.Archivable
	character.Archivable = true
	local ghost = character:Clone()
	character.Archivable = archivable
	for _, part in sources do
		part:SetAttribute(ID, nil)
	end

	dress(ghost)
	local parts, shown = {}, {}
	for _, item in ghost:GetDescendants() do
		local index = item:GetAttribute(ID)
		if index and item:IsA("BasePart") then
			parts[index] = item
			if sources[index].Transparency < 1 then
				table.insert(shown, item)
			else
				item.Transparency = 1
			end
		end
	end
	return { model = ghost, parts = parts, shown = shown, bornAt = -math.huge }
end

local function stop()
	if trail then
		trail.folder:Destroy()
		trail = nil
	end
end

local function onCharacter(character: Model)
	stop()
	local root = character:WaitForChild("HumanoidRootPart", APPEARANCE_WAIT) :: BasePart?
	local started = os.clock()
	while not player:HasAppearanceLoaded() and os.clock() - started < APPEARANCE_WAIT do
		task.wait(0.1)
	end
	task.wait(SETTLE)
	if not root or player.Character ~= character then
		return
	end

	local sources = {}
	for _, item in character:GetDescendants() do
		if item:IsA("BasePart") then
			table.insert(sources, item)
		end
	end
	local folder = Instance.new("Folder")
	folder.Name = "OutpostTrail"
	folder.Parent = Workspace.CurrentCamera
	local built: Trail = {
		folder = folder,
		root = root,
		sources = sources,
		copies = {},
		nextCopy = 1,
		nextStamp = 0,
		stampedAt = nil,
	}
	trail = built
	-- One at a time, so spawning doesn't stall the frame.
	for _ = 1, COPIES do
		if trail ~= built then
			return
		end
		table.insert(built.copies, makeCopy(character, sources))
		task.wait()
	end
end

local function dressAge(copy: Copy, age: number)
	local transparency = START_FADE + (1 - START_FADE) * math.sqrt(age) -- drops off early
	local color = Palette.SignalAcid:Lerp(Palette.DataCyan, age)
	for _, part in copy.shown do
		part.Transparency = transparency
		part.Color = color
	end
end

local function stamp(current: Trail, now: number)
	local copy = current.copies[current.nextCopy]
	if not copy then
		return
	end
	current.nextCopy = current.nextCopy % COPIES + 1
	current.nextStamp = now + STAMP_EVERY
	copy.bornAt = now
	local nudge = Vector3.new(random:NextNumber(-1, 1), random:NextNumber(-1, 1), random:NextNumber(-1, 1)) * SPREAD
	for index, part in copy.parts do
		local source = current.sources[index]
		if source.Parent then
			part.CFrame = source.CFrame + nudge
		end
	end
	dressAge(copy, 0)
	copy.model.Parent = current.folder
	current.stampedAt = current.root.Position
end

local function fade(copy: Copy, now: number)
	local age = (now - copy.bornAt) / LIFETIME
	if age >= 1 then
		copy.model.Parent = nil
		return
	end
	dressAge(copy, age)
end

player.CharacterAdded:Connect(onCharacter)
player.CharacterRemoving:Connect(stop)
if player.Character then
	task.spawn(onCharacter, player.Character)
end

local nextFade = 0
RunService.RenderStepped:Connect(function()
	local now = os.clock()
	local fading = now >= nextFade
	if fading then
		nextFade = now + FADE_EVERY
	end
	if not trail then
		return
	end
	if now >= trail.nextStamp and Zones.of(player) == Zones.Outpost then
		local last = trail.stampedAt
		if not last or (trail.root.Position - last).Magnitude >= MIN_MOVE then
			stamp(trail, now)
		end
	end
	if fading then
		for _, copy in trail.copies do
			if copy.model.Parent then
				fade(copy, now)
			end
		end
	end
end)
