-- Checks every character's movement against the server speed limits.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local SpeedLimit = require(ReplicatedStorage:WaitForChild("Movement"):WaitForChild("SpeedLimit"))
local MoveGrace = require(script.Parent.MoveGrace)
local MatchHooks = require(script.Parent.MatchHooks)

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
	-- A launch allowed on top of ordinary movement until allowUntil (MoveGrace.allow).
	allowUntil: number,
	allowSpeed: number,
	allowRise: number,
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

-- How far up or down a player is looking, in degrees, so other players' copies of the body can bend to it.
local lookRemote = Instance.new("RemoteEvent")
lookRemote.Name = "Look"
lookRemote.Parent = remotes
local MAX_LOOKS_PER_SECOND = 15
local lookWindows: { [Player]: { startedAt: number, count: number } } = {}
lookRemote.OnServerEvent:Connect(function(player, pitch)
	if type(pitch) ~= "number" or pitch ~= pitch then
		return
	end
	local now = os.clock()
	local window = lookWindows[player]
	if not window or now - window.startedAt >= 1 then
		window = { startedAt = now, count = 0 }
		lookWindows[player] = window
	end
	window.count += 1
	if window.count > MAX_LOOKS_PER_SECOND or not player.Character then
		return
	end
	player.Character:SetAttribute("LookPitch", math.round(math.clamp(pitch, -89, 89)))
end)
Players.PlayerRemoving:Connect(function(player)
	lookWindows[player] = nil
end)

-- A wall jump, so other players' copies of the body can kick off the wall too. The way is the direction out of
-- the wall. It's only for show: the jump itself is the client's, and the speed limit judges it.
local wallJumpRemote = Instance.new("RemoteEvent")
wallJumpRemote.Name = "WallJump"
wallJumpRemote.Parent = remotes
local MAX_WALL_JUMPS_PER_SECOND = 6
local wallJumpWindows: { [Player]: { startedAt: number, count: number } } = {}
wallJumpRemote.OnServerEvent:Connect(function(player, way)
	if typeof(way) ~= "Vector3" or way ~= way or math.abs(way.Magnitude - 1) > 0.05 then
		return
	end
	local now = os.clock()
	local window = wallJumpWindows[player]
	if not window or now - window.startedAt >= 1 then
		window = { startedAt = now, count = 0 }
		wallJumpWindows[player] = window
	end
	window.count += 1
	if window.count > MAX_WALL_JUMPS_PER_SECOND or not player.Character then
		return
	end
	player.Character:SetAttribute("WallKick", way)
	player.Character:SetAttribute("WallKickAt", workspace:GetServerTimeNow())
end)
Players.PlayerRemoving:Connect(function(player)
	wallJumpWindows[player] = nil
end)

-- The cards in a player's hand, so other players' copies of the body can play the deck flourish: whether a card
-- is out, how many times the held card has been turned to the next, and how many have been used. Only for show.
local cardsRemote = Instance.new("RemoteEvent")
cardsRemote.Name = "Cards"
cardsRemote.Parent = remotes
local MAX_CARDS_PER_SECOND = 15
local cardsWindows: { [Player]: { startedAt: number, count: number } } = {}
cardsRemote.OnServerEvent:Connect(function(player, out, turns, used, usedId)
	if type(out) ~= "boolean" or type(turns) ~= "number" or type(used) ~= "number" or turns ~= turns or used ~= used then
		return
	end
	-- Which card the last one used was, for the move other players see. Only for show; empty if it's anything odd.
	if type(usedId) ~= "string" or #usedId > 32 or not string.match(usedId, "^[%w_]*$") then
		usedId = ""
	end
	local now = os.clock()
	local window = cardsWindows[player]
	if not window or now - window.startedAt >= 1 then
		window = { startedAt = now, count = 0 }
		cardsWindows[player] = window
	end
	window.count += 1
	if window.count > MAX_CARDS_PER_SECOND or not player.Character then
		return
	end
	player.Character:SetAttribute("CardsOut", out)
	player.Character:SetAttribute("CardTurns", math.clamp(math.floor(turns), 0, 1e6))
	player.Character:SetAttribute("CardUsed", math.clamp(math.floor(used), 0, 1e6))
	player.Character:SetAttribute("CardUsedId", usedId)
end)
Players.PlayerRemoving:Connect(function(player)
	cardsWindows[player] = nil
end)

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
		allowUntil = 0,
		allowSpeed = 0,
		allowRise = 0,
	}
end

local function onFail(player: Player, guard: Guard, now: number)
	local track = guard.track
	local removed = SpeedLimit.addStrike(track)
	local valid = track.lastValid
	warn(`[MovementGuard] strike {track.strikes}/5 for {player.UserId}`)
	guard.character:SetAttribute("MoveStrikes", track.strikes)
	if removed and player:GetAttribute("MatchId") then
		-- In a match it costs the match, not the server (matches.md). The count starts over for the next one.
		warn(`[MovementGuard] removed {player.UserId} from their match`)
		track.strikes = 0
		guard.character:SetAttribute("MoveStrikes", 0)
		MatchHooks.cheat(player, "movement")
		return
	elseif removed then
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
	elseif not SpeedLimit.sample(guard.track, position.X, position.Y, position.Z, now,
		if now < guard.allowUntil then guard.allowSpeed else 0,
		if now < guard.allowUntil then guard.allowRise else 0)
	then
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

-- A launch the server knows the size of: checked against its speed, not looked away from. A second launch before the
-- first runs out keeps the larger of each.
MoveGrace.allowed:Connect(function(player, seconds, velocity: Vector3)
	local guard = guards[player]
	if not guard then
		return
	end
	local now = os.clock()
	local untilAt = now + seconds + 2 * player:GetNetworkPing()
	local still = now < guard.allowUntil
	guard.allowSpeed = math.max(if still then guard.allowSpeed else 0, Vector3.new(velocity.X, 0, velocity.Z).Magnitude)
	guard.allowRise = math.max(if still then guard.allowRise else 0, math.max(velocity.Y, 0))
	guard.allowUntil = math.max(guard.allowUntil, untilAt)
end)

-- Strikes count per match: a player joining one starts at none.
MatchHooks.joined:Connect(function(player)
	local guard = guards[player]
	if guard then
		guard.track.strikes = 0
		guard.character:SetAttribute("MoveStrikes", 0)
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
