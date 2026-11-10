-- Builds the Outpost and the Relay map at startup, moves players between them and the test room,
-- and loads each character, since the body depends on the zone: your Roblox avatar here, the
-- game's own elsewhere.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local StarterPlayer = game:GetService("StarterPlayer")

local Zones = require(ReplicatedStorage:WaitForChild("Guns"):WaitForChild("Zones"))
local Map = require(script.Parent.Map)
local Relay = require(script.Parent.Relay)
local Junction = require(script.Parent.Junction)
local SpawnPick = require(ReplicatedStorage:WaitForChild("Guns"):WaitForChild("SpawnPick"))
local MoveGrace = require(script.Parent.Parent.MoveGrace)

local ORIGIN = CFrame.new(4000, 0, 0) -- far from the test room, which sits at the world origin
local RELAY_ORIGIN = CFrame.new(-4000, 300, 0) -- the Relay map's centre, high enough to fall from
local JUNCTION_ORIGIN = CFrame.new(0, 100, -4000) -- the free-for-all arena's centre
local TRAVEL_GRACE_SECONDS = 1
local TRAVEL_COOLDOWN_SECONDS = 1
local STREAM_TIMEOUT_SECONDS = 2
local LOST_HEIGHT = 1.5 -- a root part this low has fallen out of the building
local MAX_RANGE = 320 -- nothing is built this far out
local CHECK_EVERY_SECONDS = 0.25
local SPAWN_DRIFT = 60 -- a new character this far from its zone's spawn gets moved there

-- Before anyone can load: Roblox would otherwise give everyone StarterCharacter straight away.
Players.CharacterAutoLoads = false
local gameBody = StarterPlayer:FindFirstChild("StarterCharacter")
if gameBody then
	gameBody.Parent = ServerStorage
end

local outpost = Map.build(ORIGIN)
local testRoom = workspace:WaitForChild("TestRoom")
local testSpawn = testRoom:WaitForChild("Spawn") :: SpawnLocation
local testRoomTerminal = Map.buildReturnTerminal(testRoom, testSpawn)
local relay = Relay.build(RELAY_ORIGIN)
local relayTerminal = Relay.buildTerminal(testRoom, testSpawn.Position + Vector3.new(-9, -testSpawn.Size.Y / 2, 0), Vector3.xAxis)
local junction = Junction.build(JUNCTION_ORIGIN)
local junctionTerminal =
	Junction.buildTerminal(testRoom, testSpawn.Position + Vector3.new(9, -testSpawn.Size.Y / 2, 0), -Vector3.xAxis)

local spawns: { [string]: SpawnLocation } = {
	[Zones.Outpost] = outpost.spawn,
	[Zones.TestRoom] = testSpawn,
	[Zones.Relay] = relay.spawns[1],
}
local lastTravel: { [Player]: number } = {}
-- Which Relay tower each player there spawns in: 1 or 2.
local relaySide: { [Player]: number } = {}

-- The tower with fewer players, so two players get one each.
local function emptierRelaySide(): number
	local counts = { 0, 0 }
	for other, side in relaySide do
		if other.Parent == Players then
			counts[side] += 1
		end
	end
	return if counts[2] < counts[1] then 2 else 1
end

-- Which Junction spawn each player there comes in at next. Picked again on every death.
local junctionSpawn: { [Player]: SpawnLocation } = {}
local spawnRandom = Random.new()

-- The Junction spawn furthest from everyone else in the arena.
local function pickJunctionSpawn(player: Player): SpawnLocation
	local others = {}
	for _, other in Players:GetPlayers() do
		local root = other.Character and other.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local humanoid = other.Character and other.Character:FindFirstChildOfClass("Humanoid")
		if other ~= player and root and humanoid and humanoid.Health > 0 and Zones.of(other) == Zones.Junction then
			table.insert(others, root.Position)
		end
	end
	local positions = {}
	for index, spawn in junction.spawns do
		positions[index] = spawn.Position
	end
	return junction.spawns[SpawnPick.farthest(positions, others, function(count)
		return spawnRandom:NextInteger(1, count)
	end)]
end

local function spawnFor(player: Player, zone: string): SpawnLocation
	if zone == Zones.Relay then
		return relay.spawns[relaySide[player] or 1]
	elseif zone == Zones.Junction then
		local spawn = junctionSpawn[player] or pickJunctionSpawn(player)
		junctionSpawn[player] = spawn
		return spawn
	end
	return spawns[zone]
end
local moving: { [Player]: boolean } = {}

-- StarterCharacter applies to whoever loads while it's in StarterPlayer, so loads go one at a time.
local loading = false
local function loadBody(player: Player)
	while loading do
		task.wait()
	end
	if player.Parent ~= Players then
		return
	end
	loading = true
	if gameBody then
		gameBody.Parent = if Zones.usesAvatar(Zones.of(player)) then ServerStorage else StarterPlayer
	end
	local loaded, problem = pcall(player.LoadCharacter, player)
	if gameBody then
		gameBody.Parent = ServerStorage
	end
	loading = false
	if not loaded then
		warn("Could not load a character for", player.Name, problem)
	end
end

local function standingOn(spawn: SpawnLocation): CFrame
	return spawn.CFrame * CFrame.new(0, spawn.Size.Y / 2 + 3, 0)
end

local function moveTo(player: Player, zone: string)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not character or not root or moving[player] then
		return
	end
	moving[player] = true
	local target = standingOn(spawnFor(player, zone))
	-- Loads the far side first if the place streams. Does nothing otherwise.
	pcall(player.RequestStreamAroundAsync, player, target.Position, STREAM_TIMEOUT_SECONDS)
	if player.Character == character then
		MoveGrace.give(player, TRAVEL_GRACE_SECONDS)
		root.AssemblyLinearVelocity = Vector3.zero
		character:PivotTo(target)
	end
	moving[player] = nil
end

local function setZone(player: Player, zone: string)
	if zone ~= Zones.Relay then
		relaySide[player] = nil
	elseif not relaySide[player] then
		relaySide[player] = emptierRelaySide()
	end
	junctionSpawn[player] = if zone == Zones.Junction then pickJunctionSpawn(player) else nil
	player:SetAttribute("Zone", zone)
	player.RespawnLocation = spawnFor(player, zone)
end

local function travel(player: Player, zone: string)
	local now = os.clock()
	if now - (lastTravel[player] or -math.huge) < TRAVEL_COOLDOWN_SECONDS then
		return
	end
	lastTravel[player] = now
	setZone(player, zone)
	MoveGrace.give(player, TRAVEL_GRACE_SECONDS)
	loadBody(player)
end

outpost.testRoomDoor.Triggered:Connect(function(player)
	travel(player, Zones.TestRoom)
end)
testRoomTerminal.Triggered:Connect(function(player)
	travel(player, Zones.Outpost)
end)
relayTerminal.Triggered:Connect(function(player)
	travel(player, Zones.Relay)
end)
for _, prompt in relay.terminals do
	prompt.Triggered:Connect(function(player)
		travel(player, Zones.Outpost)
	end)
end
junctionTerminal.Triggered:Connect(function(player)
	travel(player, Zones.Junction)
end)
for _, prompt in junction.terminals do
	prompt.Triggered:Connect(function(player)
		travel(player, Zones.Outpost)
	end)
end

-- A new character can land on the wrong spawn if it loaded before RespawnLocation was set.
local function onCharacter(player: Player, character: Model)
	local humanoid = character:WaitForChild("Humanoid", 10) :: Humanoid?
	if humanoid then
		humanoid.Died:Once(function()
			task.wait(Players.RespawnTime)
			if player.Character == character then
				-- In the free-for-all, come back wherever is furthest from everyone now.
				if Zones.of(player) == Zones.Junction then
					junctionSpawn[player] = pickJunctionSpawn(player)
					player.RespawnLocation = junctionSpawn[player]
				end
				loadBody(player)
			end
		end)
	end
	local root = character:WaitForChild("HumanoidRootPart", 10) :: BasePart?
	if not root or player.Character ~= character then
		return
	end
	task.wait()
	local zone = Zones.of(player)
	if (root.Position - spawnFor(player, zone).Position).Magnitude > SPAWN_DRIFT then
		moveTo(player, zone)
	end
end

local function onPlayer(player: Player)
	setZone(player, Zones.Outpost)
	player.CharacterAdded:Connect(function(character)
		onCharacter(player, character)
	end)
	if player.Character then
		task.spawn(onCharacter, player, player.Character)
	end
	loadBody(player)
end

Players.PlayerAdded:Connect(onPlayer)
for _, player in Players:GetPlayers() do
	task.spawn(onPlayer, player)
end
Players.PlayerRemoving:Connect(function(player)
	lastTravel[player] = nil
	moving[player] = nil
	relaySide[player] = nil
	junctionSpawn[player] = nil
end)

-- Getting out of the building somehow sends you back to the spawn.
local function isLost(player: Player): boolean
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid or humanoid.Health <= 0 then
		return false
	end
	local offset = ORIGIN:PointToObjectSpace(root.Position)
	return offset.Y < LOST_HEIGHT or Vector2.new(offset.X, offset.Z).Magnitude > MAX_RANGE
end

-- Falling off the Relay map into the fog kills you; you respawn in your tower.
local function fellOffRelay(player: Player)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if root and humanoid and humanoid.Health > 0 and root.Position.Y < RELAY_ORIGIN.Y + Relay.fallDepth then
		humanoid.Health = 0
	end
end

local waited = 0
RunService.Heartbeat:Connect(function(dt)
	waited += dt
	if waited < CHECK_EVERY_SECONDS then
		return
	end
	waited = 0
	for _, player in Players:GetPlayers() do
		local zone = Zones.of(player)
		if zone == Zones.Outpost and not moving[player] and isLost(player) then
			task.spawn(moveTo, player, Zones.Outpost)
		elseif zone == Zones.Relay and not moving[player] then
			fellOffRelay(player)
		end
	end
end)
