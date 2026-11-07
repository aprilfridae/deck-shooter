-- A glowing 3D trail behind every player in the Outpost: neon copies of their whole body, hair and
-- accessories included, left where they stood and fading out. The copies are made on this client.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Guns = ReplicatedStorage:WaitForChild("Guns")
local Palette = require(Guns:WaitForChild("Palette"))
local Zones = require(Guns:WaitForChild("Zones"))

local BODY_GROUP = "BodyMesh" -- from CharacterBody.server.luau; it never touches the world
local COPIES = 24 -- for your own body
local OTHERS_SHARE = 0.5 -- other players get this share of the copies, twice as far apart in time
local STAMP_EVERY = 0.012 -- seconds; every frame at 60 fps, so the copies run together
local LIFETIME = 0.35 -- seconds
local FADE_EVERY = 1 / 30 -- seconds
local MIN_MOVE = 0.15 -- studs a player must move for a new copy
local START_FADE = 0.95 -- how see-through a copy is when it's left, kept high as they stack up
local RANGE = 90 -- studs from the camera; players further off leave no trail
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
	player: Player,
	folder: Folder,
	root: BasePart,
	sources: { BasePart },
	copies: { Copy },
	size: number,
	gap: number, -- seconds between copies
	nextCopy: number,
	nextStamp: number,
	stampedAt: Vector3?,
}

local trails: { [Player]: Trail } = {}

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

local function stop(player: Player)
	local trail = trails[player]
	if trail then
		trail.folder:Destroy()
		trails[player] = nil
	end
end

local function onCharacter(player: Player, character: Model)
	stop(player)
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
	folder.Name = `OutpostTrail_{player.UserId}`
	folder.Parent = Workspace.CurrentCamera
	local mine = player == Players.LocalPlayer
	local trail: Trail = {
		player = player,
		folder = folder,
		root = root,
		sources = sources,
		copies = {},
		size = if mine then COPIES else math.ceil(COPIES * OTHERS_SHARE),
		gap = if mine then STAMP_EVERY else STAMP_EVERY / OTHERS_SHARE,
		nextCopy = 1,
		nextStamp = 0,
		stampedAt = nil,
	}
	trails[player] = trail
	-- One at a time, so a player joining doesn't stall the frame.
	for _ = 1, trail.size do
		if player.Character ~= character or trails[player] ~= trail then
			return
		end
		table.insert(trail.copies, makeCopy(character, sources))
		task.wait()
	end
end

local function watch(player: Player)
	player.CharacterAdded:Connect(function(character)
		onCharacter(player, character)
	end)
	player.CharacterRemoving:Connect(function()
		stop(player)
	end)
	if player.Character then
		task.spawn(onCharacter, player, player.Character)
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

local function stamp(trail: Trail, now: number)
	local copy = trail.copies[trail.nextCopy]
	if not copy then
		return
	end
	trail.nextCopy = trail.nextCopy % trail.size + 1
	trail.nextStamp = now + trail.gap
	copy.bornAt = now
	for index, part in copy.parts do
		local source = trail.sources[index]
		if source.Parent then
			part.CFrame = source.CFrame
		end
	end
	dressAge(copy, 0)
	copy.model.Parent = trail.folder
	trail.stampedAt = trail.root.Position
end

local function fade(copy: Copy, now: number)
	local age = (now - copy.bornAt) / LIFETIME
	if age >= 1 then
		copy.model.Parent = nil
		return
	end
	dressAge(copy, age)
end

for _, player in Players:GetPlayers() do
	watch(player)
end
Players.PlayerAdded:Connect(watch)
Players.PlayerRemoving:Connect(stop)

local nextFade = 0
RunService.RenderStepped:Connect(function()
	local now = os.clock()
	local fading = now >= nextFade
	if fading then
		nextFade = now + FADE_EVERY
	end
	local eye = Workspace.CurrentCamera.CFrame.Position
	for player, trail in trails do
		if now >= trail.nextStamp and Zones.of(player) == Zones.Outpost and (trail.root.Position - eye).Magnitude <= RANGE then
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
	end
end)
