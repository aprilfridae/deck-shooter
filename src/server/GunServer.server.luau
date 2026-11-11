-- Server side of shooting: rewinds targets, decides hits and owns ammo.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Guns = ReplicatedStorage:WaitForChild("Guns")
local Damage = require(Guns:WaitForChild("Damage"))
local History = require(Guns:WaitForChild("History"))
local Hitbox = require(Guns:WaitForChild("Hitbox"))
local ShotRequest = require(Guns:WaitForChild("ShotRequest"))
local Spread = require(Guns:WaitForChild("Spread"))
local Weapon = require(Guns:WaitForChild("Weapon"))
local Zones = require(Guns:WaitForChild("Zones"))
local Collision = require(Guns:WaitForChild("Collision"))
local KillRewards = require(Guns:WaitForChild("KillRewards"))
local Requests = require(ReplicatedStorage:WaitForChild("CardCore"):WaitForChild("Requests"))
local CardConfig = require(ReplicatedStorage:WaitForChild("CardCore"):WaitForChild("Config"))
local GunTargets = require(script.Parent.GunTargets)
local loadouts = require(script.Parent.Loadouts)
local PlayerCards = require(script.Parent.PlayerCards)

local RESPAWN_SECONDS = 3
local RECORD_EVERY_SECONDS = 0.05
local MAX_RANGE = 1000
local MAX_REQUESTS_PER_SECOND = 20 -- the Energy Pistol can fire 12 a second
local DEFAULT_CLASS = "Assault"
local DEFAULT_RIFLE = "M4"

Players.RespawnTime = RESPAWN_SECONDS

local remotes = Instance.new("Folder")
remotes.Name = "GunRemotes"
local function remote(name: string): RemoteEvent
	local event = Instance.new("RemoteEvent")
	event.Name = name
	event.Parent = remotes
	return event
end
local fireRemote = remote("Fire")
local reloadRemote = remote("Reload")
local swapRemote = remote("Swap")
local hitRemote = remote("HitConfirm")
local impactRemote = remote("Impacts")
local shotsRemote = remote("Shots")
local rewardRemote = remote("KillReward") -- to the killer: the lines a shot's kills earned and the Credits they add up to
-- What each player's kills have earned lately: their streak, and when each victim last paid them. Not saved.
local records: { [Player]: KillRewards.Record } = {}
local deathRemote = remote("DeathBurst") -- where someone died and who killed them, for the coin burst
local loadoutRemote = remote("SetLoadout")
remotes.Parent = ReplicatedStorage

local requestWindows: { [Player]: { startedAt: number, count: number } } = {}

local random = Random.new()
local function rng(): number
	return random:NextNumber()
end

local function allowRequest(player: Player, now: number): boolean
	local window = requestWindows[player]
	if not window or now - window.startedAt >= 1 then
		requestWindows[player] = { startedAt = now, count = 1 }
		return true
	end
	window.count += 1
	return window.count <= MAX_REQUESTS_PER_SECOND
end

local function firstWall(origin: Vector3, direction: Vector3): RaycastResult?
	local exclude = {}
	for model in GunTargets.all() do
		table.insert(exclude, model)
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = exclude
	params.RespectCanCollide = true
	Collision.forShots(params) -- railings and window panes stop feet, not bullets
	return workspace:Raycast(origin, direction, params)
end

-- A shot must start near the shooter, with no wall between their body and its origin. "Near" grows with how fast
-- they're moving: the server's copy of a player trails them, so at speed or in a fall their camera is well ahead of
-- it, and a fixed 6 studs threw those shots away without a word.
local SPEED_OVER = 0.15 -- seconds of their recorded path their speed is measured over
local lastRefusalWarned = 0
local function originValid(shooter: GunTargets.Target, shot: any, ping: number, now: number): boolean
	local origin = Vector3.new(shot.origin.x, shot.origin.y, shot.origin.z)
	-- Their speed comes from where the server recorded them, not from a velocity their client could make up.
	local latest, before = History.at(shooter.history, now), History.at(shooter.history, now - SPEED_OVER)
	local velocity = Vector3.zero
	if latest and before then
		velocity = Vector3.new(latest.x - before.x, latest.y - before.y, latest.z - before.z) / SPEED_OVER
	end
	local slack = ShotRequest.originSlack(velocity.Magnitude, ping)
	local ahead = velocity * ShotRequest.lead(ping)
	local nearest = math.huge
	local walled = false
	for _, time in { ShotRequest.shooterTime(shot.firedAt, ping, now), now } do
		local past = History.at(shooter.history, time)
		if past then
			nearest = math.min(nearest, ShotRequest.originDistance(shot.origin, past))
		end
		if past and ShotRequest.originAllowed(shot.origin, past, slack) then
			local body = Vector3.new(past.x, past.y, past.z)
			if not firstWall(body, origin - body) then
				return true
			end
			-- Round a corner at speed, the straight line from where they were cuts the corner. So it may also be
			-- reached by way of where their movement was carrying them, if nothing was in the way of that.
			local carried = body + ahead
			if ahead.Magnitude > 0.5 and not firstWall(body, ahead) and not firstWall(carried, origin - carried) then
				return true
			end
			walled = true
		end
	end
	if os.clock() - lastRefusalWarned > 1 then
		lastRefusalWarned = os.clock()
		warn(
			string.format(
				"[Guns] refused a shot from %s: %s (%.1f studs from their body, %.1f allowed, moving %.0f)",
				shooter.model.Name,
				if walled then "a wall between their body and where it started" else "it started too far from their body",
				nearest,
				slack,
				velocity.Magnitude
			)
		)
	end
	return false
end

-- Every living target this ray passes through before a wall, nearest first, and the wall if there is one.
local function hitsAlong(shooter: GunTargets.Target, shot: any, direction: any, viewAt: number, magnet: number?)
	local origin = Vector3.new(shot.origin.x, shot.origin.y, shot.origin.z)
	local wall = firstWall(origin, Vector3.new(direction.x, direction.y, direction.z) * MAX_RANGE)
	local reach = if wall then wall.Distance else MAX_RANGE
	local hits = {}
	for _, target in GunTargets.all() do
		if target ~= shooter and GunTargets.isAlive(target) then
			local past = History.at(target.history, viewAt)
			if past then
				local zone, distance = Hitbox.test(shot.origin, direction, past, target.shape, magnet)
				if zone and distance < reach then
					table.insert(hits, { target = target, zone = zone, distance = distance })
				end
			end
		end
	end
	table.sort(hits, function(a, b)
		return a.distance < b.distance
	end)
	return hits, reach, wall
end

local function onFire(player: Player, raw: any)
	local shooter = GunTargets.forPlayer(player)
	local loadout = loadouts[player]
	if not shooter or not loadout or not GunTargets.isAlive(shooter) or not Zones.allowsCombat(Zones.of(player)) then
		return
	end
	local now = workspace:GetServerTimeNow()
	local shot = ShotRequest.parse(raw, now)
	if not shot then
		return
	end
	local ping = player:GetNetworkPing()
	if not originValid(shooter, shot, ping, now) then
		return
	end
	-- Uses the firing time, so network jitter does not refuse a legal shot.
	-- ShotRequest keeps it within the rewind limit, so it cannot beat the rate for long.
	if not Weapon.tryFire(loadout, shot.firedAt) then
		return
	end

	local gun = Weapon.active(loadout).gun
	local angle = Spread.angle(gun, shot.aiming)
	local viewAt = ShotRequest.viewTime(shot.firedAt, ping, now)
	local totals: { [GunTargets.Target]: number } = {}
	-- A collateral, on guns that have them: a bullet that goes through two or more bodies kills every one of
	-- them, however far apart.
	local collaterals: { [GunTargets.Target]: boolean } = {}
	local headshot = false
	-- For the kill rewards: how many of this shot's bullets hit each target, and whether one hit its head.
	local struck: { [GunTargets.Target]: { bullets: number, head: boolean } } = {}
	local function strike(target: GunTargets.Target, head: boolean)
		local hit = struck[target] or { bullets = 0, head = false }
		hit.bullets += 1
		hit.head = hit.head or head
		struck[target] = hit
	end
	local impacts = {}
	local shots = {}
	local origin = Vector3.new(shot.origin.x, shot.origin.y, shot.origin.z)
	for _ = 1, gun.pellets do
		local direction = Spread.apply(shot.direction, angle, rng)
		local hits, reach, wall = hitsAlong(shooter, shot, direction, viewAt, gun.magnet)
		local line = Vector3.new(direction.x, direction.y, direction.z)
		local first = hits[1]
		if gun.collateral and #hits >= 2 then
			-- It passes through them all, so the tracer runs on to whatever stops it, with blood on each body.
			for _, hit in hits do
				collaterals[hit.target] = true
				strike(hit.target, hit.zone == "Head")
				headshot = headshot or hit.zone == "Head"
				table.insert(shots, {
					to = origin + line * hit.distance,
					direction = line,
					hit = hit.target.model,
					head = hit.zone == "Head",
					through = true,
				})
			end
			if wall then
				table.insert(impacts, { position = wall.Position, normal = wall.Normal })
			end
			table.insert(shots, { to = origin + line * reach, direction = line })
		else
			if first then
				local isHead = first.zone == "Head"
				totals[first.target] = (totals[first.target] or 0) + Damage.hit(gun, first.distance, isHead)
				strike(first.target, isHead)
				headshot = headshot or isHead
			elseif wall then
				table.insert(impacts, { position = wall.Position, normal = wall.Normal })
			end
			table.insert(shots, {
				to = origin + line * (if first then first.distance else reach),
				direction = line,
				hit = if first then first.target.model else nil,
				head = first ~= nil and first.zone == "Head",
			})
		end
	end
	shotsRemote:FireAllClients(player, origin, shots)
	if #impacts > 0 then
		impactRemote:FireAllClients(impacts)
	end

	for target in collaterals do
		totals[target] = math.huge
	end
	local announced = false -- a collateral is told to the shooter once, however many bodies it went through
	local kills: { KillRewards.Kill } = {}
	for target, amount in totals do
		if amount > 0 then
			local fullHealth = target.shield == nil and target.health >= target.humanoid.MaxHealth
			local killed = if collaterals[target] then GunTargets.kill(target) else GunTargets.damage(target, amount)
			if killed then
				deathRemote:FireAllClients(target.root.Position, player) -- the killer, who the coins fly to
				local hit = struck[target]
				table.insert(kills, {
					victim = target.player or target.model,
					-- Players pay, and so will anything else given the PaysKill attribute (River's bots, later).
					-- The test dummy has neither and never pays.
					pays = target.player ~= nil or target.model:GetAttribute("PaysKill") == true,
					head = hit ~= nil and hit.head,
					fullHealth = fullHealth,
					bullets = if hit then hit.bullets else 1,
					distance = (target.root.Position - shooter.root.Position).Magnitude,
				})
				local victim = target.player
				if victim and records[victim] then
					KillRewards.died(records[victim])
				end
			end
			local collateral = collaterals[target] == true and not announced
			announced = announced or collateral
			hitRemote:FireClient(player, { headshot = headshot, killed = killed, collateral = collateral })
		end
	end
	if #kills > 0 then
		-- The server alone decides what the kills are worth and adds it to the killer's saved Credits.
		local record = records[player] or KillRewards.newRecord()
		records[player] = record
		local lines, total = KillRewards.forShot(kills, next(collaterals) ~= nil, record, os.clock())
		local data = PlayerCards.get(player)
		if total > 0 and data then
			data.credits = math.min(data.credits + total, CardConfig.MaxCredits)
			PlayerCards.changed(player)
		end
		rewardRemote:FireClient(player, lines, total)
	end
end

local function onReload(player: Player)
	local loadout = loadouts[player]
	local now = workspace:GetServerTimeNow()
	if loadout and allowRequest(player, now) and Zones.allowsCombat(Zones.of(player)) then
		Weapon.startReload(loadout, now)
	end
end

local function onSwap(player: Player, slot: any)
	local loadout = loadouts[player]
	local now = workspace:GetServerTimeNow()
	if loadout and type(slot) == "string" and allowRequest(player, now) then
		Weapon.swap(loadout, slot, now)
	end
end

-- Attributes, so a client that starts late still gets the current state.
local function showGun(player: Player, loadout: Weapon.Loadout, now: number)
	Weapon.update(loadout, now)
	local slot = Weapon.active(loadout)
	player:SetAttribute("GunId", slot.gunId)
	player:SetAttribute("GunSlot", loadout.active)
	player:SetAttribute("Ammo", slot.ammo)
	player:SetAttribute("Reloading", slot.reloadDoneAt ~= nil)
end

local function applyLoadout(player: Player)
	local data = PlayerCards.get(player)
	local class = if data then data.class else DEFAULT_CLASS
	local rifle = if data then data.rifle else DEFAULT_RIFLE
	loadouts[player] = Weapon.newLoadout(class, rifle)
	player:SetAttribute("Class", class)
	player:SetAttribute("Rifle", rifle)
end

-- Applies straight away at full health with both guns unfired, so it can't refill a
-- magazine or skip the fire rate. Otherwise it waits for respawn.
local function applyIfUnused(player: Player)
	local target = GunTargets.forPlayer(player)
	local loadout = loadouts[player]
	if target and loadout and target.health >= target.humanoid.MaxHealth and Weapon.isUntouched(loadout) then
		applyLoadout(player)
	end
end

local function onSetLoadout(player: Player, raw: any)
	local data = PlayerCards.get(player)
	local request = Requests.parseLoadout(raw)
	if not data or not request or not allowRequest(player, workspace:GetServerTimeNow()) then
		return
	end
	data.class = request.class
	data.rifle = request.rifle
	applyIfUnused(player)
	PlayerCards.changed(player)
end

local function onPlayer(player: Player)
	local function onCharacter(character: Model)
		if records[player] then
			KillRewards.died(records[player]) -- a new life, however the last one ended
		end
		applyLoadout(player)
		GunTargets.add(character, player)
	end
	player.CharacterAdded:Connect(onCharacter)
	if player.Character then
		task.spawn(onCharacter, player.Character)
	end
end

fireRemote.OnServerEvent:Connect(onFire)
reloadRemote.OnServerEvent:Connect(onReload)
swapRemote.OnServerEvent:Connect(onSwap)
loadoutRemote.OnServerEvent:Connect(onSetLoadout)
-- The save can finish loading after the first spawn.
PlayerCards.profileLoaded:Connect(applyIfUnused)

Players.PlayerAdded:Connect(onPlayer)
for _, player in Players:GetPlayers() do
	task.spawn(onPlayer, player)
end
Players.PlayerRemoving:Connect(function(player)
	loadouts[player] = nil
	records[player] = nil
	requestWindows[player] = nil
end)

local waited = 0
RunService.Heartbeat:Connect(function(dt)
	waited += dt
	if waited < RECORD_EVERY_SECONDS then
		return
	end
	waited = 0
	local now = workspace:GetServerTimeNow()
	for _, target in GunTargets.all() do
		local position = target.root.Position
		local pose = target.model:GetAttribute("MovePose") or "Normal"
		History.record(target.history, position.X, position.Y, position.Z, pose, now)
	end
	for player, loadout in loadouts do
		showGun(player, loadout, now)
	end
end)
