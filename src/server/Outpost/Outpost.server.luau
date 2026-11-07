-- Builds the Outpost at startup, moves players between it and the test room, and loads each
-- character, since the body depends on the zone: your Roblox avatar here, the game's own elsewhere.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local StarterPlayer = game:GetService("StarterPlayer")

local Zones = require(ReplicatedStorage:WaitForChild("Guns"):WaitForChild("Zones"))
local Map = require(script.Parent.Map)
local MoveGrace = require(script.Parent.Parent.MoveGrace)

local ORIGIN = CFrame.new(4000, 0, 0) -- far from the test room, which sits at the world origin
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

local spawns: { [string]: SpawnLocation } = {
	[Zones.Outpost] = outpost.spawn,
	[Zones.TestRoom] = testSpawn,
}
local lastTravel: { [Player]: number } = {}
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
	local target = standingOn(spawns[zone])
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
	player:SetAttribute("Zone", zone)
	player.RespawnLocation = spawns[zone]
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

-- A new character can land on the wrong spawn if it loaded before RespawnLocation was set.
local function onCharacter(player: Player, character: Model)
	local humanoid = character:WaitForChild("Humanoid", 10) :: Humanoid?
	if humanoid then
		humanoid.Died:Once(function()
			task.wait(Players.RespawnTime)
			if player.Character == character then
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
	if (root.Position - spawns[zone].Position).Magnitude > SPAWN_DRIFT then
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

local waited = 0
RunService.Heartbeat:Connect(function(dt)
	waited += dt
	if waited < CHECK_EVERY_SECONDS then
		return
	end
	waited = 0
	for _, player in Players:GetPlayers() do
		if Zones.of(player) == Zones.Outpost and not moving[player] and isLost(player) then
			task.spawn(moveTo, player, Zones.Outpost)
		end
	end
end)
