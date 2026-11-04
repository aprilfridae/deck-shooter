-- Checks every character's movement against the server speed limits.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local SpeedLimit = require(ReplicatedStorage:WaitForChild("Movement"):WaitForChild("SpeedLimit"))

local SAMPLE_EVERY_SECONDS = 0.1
local SPAWN_GRACE_SECONDS = 1 -- the root part may not be at the spawn yet
local PULLBACK_GRACE_SECONDS = 0.25 -- old client positions may still arrive

type Guard = {
	character: Model,
	root: BasePart,
	humanoid: Humanoid,
	track: SpeedLimit.Track,
	settledAt: number,
	pausedUntil: number,
}

local guards: { [Player]: Guard } = {}

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
	guard.pausedUntil = now + PULLBACK_GRACE_SECONDS
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
