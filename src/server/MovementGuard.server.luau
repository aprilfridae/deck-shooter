-- Checks every character's movement against the server speed limits.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local SpeedLimit = require(ReplicatedStorage:WaitForChild("Movement"):WaitForChild("SpeedLimit"))
local MoveGrace = require(script.Parent.MoveGrace)

local SAMPLE_EVERY_SECONDS = 0.1
local SPAWN_GRACE_SECONDS = 1 -- the root part may not be at the spawn yet
local PULLBACK_GRACE_SECONDS = 0.25 -- old client positions may still arrive
local PULLBACK_PING_MARGIN = 0.1
local MAX_POSES_PER_SECOND = 10
local POSES = { Normal = true, Crouch = true, Slide = true }

type Guard = {
	character: Model,
	root: BasePart,
	humanoid: Humanoid,
	track: SpeedLimit.Track,
	settledAt: number,
	pausedUntil: number,
}

local guards: { [Player]: Guard } = {}
local poseWindows: { [Player]: { startedAt: number, count: number } } = {}

local remotes = Instance.new("Folder")
remotes.Name = "MovementRemotes"
local poseRemote = Instance.new("RemoteEvent")
poseRemote.Name = "Pose"
poseRemote.Parent = remotes
remotes.Parent = ReplicatedStorage

local function allowPose(player: Player): boolean
	local now = os.clock()
	local window = poseWindows[player]
	if not window or now - window.startedAt >= 1 then
		poseWindows[player] = { startedAt = now, count = 1 }
		return true
	end
	window.count += 1
	return window.count <= MAX_POSES_PER_SECOND
end

poseRemote.OnServerEvent:Connect(function(player, pose)
	if type(pose) ~= "string" or not POSES[pose] or not allowPose(player) then
		return
	end
	if player.Character then
		player.Character:SetAttribute("MovePose", pose)
	end
end)

local function onCharacter(player: Player, character: Model)
	local root = character:WaitForChild("HumanoidRootPart", 10) :: BasePart?
	local humanoid = character:WaitForChild("Humanoid", 10) :: Humanoid?
	if not root or not humanoid or player.Character ~= character then
		return
	end

	local now = os.clock()
	local previous = guards[player]
	local track = SpeedLimit.new(root.Position.X, root.Position.Y, root.Position.Z, now)
	-- Strikes count per match, so a respawn does not clear them.
	track.strikes = if previous then previous.track.strikes else 0
	character:SetAttribute("MoveStrikes", track.strikes)
	guards[player] = {
		character = character,
		root = root,
		humanoid = humanoid,
		track = track,
		settledAt = now + SPAWN_GRACE_SECONDS,
		pausedUntil = 0,
	}
end

local function onFail(player: Player, guard: Guard, now: number)
	local track = guard.track
	local removed = SpeedLimit.addStrike(track)
	local valid = track.lastValid
	warn(`[MovementGuard] strike {track.strikes}/5 for {player.UserId}`)
	guard.character:SetAttribute("MoveStrikes", track.strikes)
	if removed then
		warn(`[MovementGuard] removed {player.UserId}`)
		guards[player] = nil -- the kick can take a moment to land
		player:Kick("Removed for unusual movement.")
		return
	end
	guard.character:PivotTo(CFrame.new(valid.x, valid.y, valid.z) * guard.root.CFrame.Rotation)
	SpeedLimit.reset(track, valid.x, valid.y, valid.z, now)
	-- The client owns its character, so the pull-back needs a round trip to land.
	local roundTrip = 2 * player:GetNetworkPing() + PULLBACK_PING_MARGIN
	guard.pausedUntil = now + math.max(PULLBACK_GRACE_SECONDS, roundTrip)
end

local function check(player: Player, guard: Guard, now: number)
	local position = guard.root.Position
	if guard.humanoid.Health <= 0 or not guard.root:IsDescendantOf(workspace) or now < guard.pausedUntil then
		return
	end
	if now < guard.settledAt then
		SpeedLimit.reset(guard.track, position.X, position.Y, position.Z, now)
	elseif not SpeedLimit.sample(guard.track, position.X, position.Y, position.Z, now) then
		onFail(player, guard, now)
	end
end

-- The move starts a round trip from now, so the grace has to outlast that too.
MoveGrace.given:Connect(function(player, seconds)
	local guard = guards[player]
	if guard then
		local grace = seconds + 2 * player:GetNetworkPing()
		guard.settledAt = math.max(guard.settledAt, os.clock() + grace)
	end
end)

local function onPlayer(player: Player)
	player.CharacterAdded:Connect(function(character)
		onCharacter(player, character)
	end)
	if player.Character then
		task.spawn(onCharacter, player, player.Character)
	end
end

Players.PlayerAdded:Connect(onPlayer)
for _, player in Players:GetPlayers() do
	task.spawn(onPlayer, player)
end
Players.PlayerRemoving:Connect(function(player)
	guards[player] = nil
	poseWindows[player] = nil
end)

local waited = 0
RunService.Heartbeat:Connect(function(dt)
	waited += dt
	if waited < SAMPLE_EVERY_SECONDS then
		return
	end
	waited = 0
	local now = os.clock()
	for player, guard in guards do
		check(player, guard, now)
	end
end)
