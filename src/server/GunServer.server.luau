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
local Requests = require(ReplicatedStorage:WaitForChild("CardCore"):WaitForChild("Requests"))
local GunTargets = require(script.Parent.GunTargets)
local PlayerCards = require(script.Parent.PlayerCards)

local RESPAWN_SECONDS = 3
local RECORD_EVERY_SECONDS = 0.05
local MAX_RANGE = 1000
local SPRINTING_SPEED = 20
local MAX_REQUESTS_PER_SECOND = 10
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
local ammoRemote = remote("AmmoChanged")
local loadoutRemote = remote("SetLoadout")
remotes.Parent = ReplicatedStorage

local loadouts: { [Player]: Weapon.Loadout } = {}
local sentAmmo: { [Player]: string } = {}
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

local function stanceOf(target: GunTargets.Target, aiming: boolean)
	local velocity = target.root.AssemblyLinearVelocity
	return {
		aiming = aiming,
		sprinting = Vector3.new(velocity.X, 0, velocity.Z).Magnitude > SPRINTING_SPEED,
		airborne = target.humanoid.FloorMaterial == Enum.Material.Air,
	}
end

local function wallDistance(origin: Vector3, direction: Vector3): number
	local exclude = {}
	for model in GunTargets.all() do
		table.insert(exclude, model)
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = exclude
	params.RespectCanCollide = true
	local hit = workspace:Raycast(origin, direction * MAX_RANGE, params)
	return if hit then hit.Distance else MAX_RANGE
end

-- The nearest living target this ray reaches before a wall.
local function nearestHit(shooter: GunTargets.Target, shot: any, direction: any)
	local origin = Vector3.new(shot.origin.x, shot.origin.y, shot.origin.z)
	local nearest = wallDistance(origin, Vector3.new(direction.x, direction.y, direction.z))
	local found, foundZone = nil, nil
	for _, target in GunTargets.all() do
		if target ~= shooter and GunTargets.isAlive(target) then
			local past = History.at(target.history, shot.firedAt)
			if past then
				local zone, distance = Hitbox.test(shot.origin, direction, past)
				if zone and distance < nearest then
					found, foundZone, nearest = target, zone, distance
				end
			end
		end
	end
	return found, foundZone, nearest
end

local function onFire(player: Player, raw: any)
	local shooter = GunTargets.forPlayer(player)
	local loadout = loadouts[player]
	if not shooter or not loadout or not GunTargets.isAlive(shooter) then
		return
	end
	local shot = ShotRequest.parse(raw, workspace:GetServerTimeNow())
	if not shot then
		return
	end
	local rewound = History.at(shooter.history, shot.firedAt)
	if not rewound or not ShotRequest.originAllowed(shot.origin, rewound) then
		return
	end
	-- Uses the firing time, so network jitter does not refuse a legal shot.
	-- ShotRequest keeps it within the rewind limit, so it cannot beat the rate for long.
	if not Weapon.tryFire(loadout, shot.firedAt) then
		return
	end

	local gun = Weapon.active(loadout).gun
	local angle = Spread.angle(gun, stanceOf(shooter, shot.aiming))
	local totals: { [GunTargets.Target]: number } = {}
	local headshot = false
	for _ = 1, gun.pellets do
		local direction = Spread.apply(shot.direction, angle, rng)
		local target, zone, distance = nearestHit(shooter, shot, direction)
		if target then
			local isHead = zone == "Head"
			totals[target] = (totals[target] or 0) + Damage.hit(gun, distance, isHead)
			headshot = headshot or isHead
		end
	end

	for target, amount in totals do
		if amount > 0 then
			local killed = GunTargets.damage(target, amount)
			hitRemote:FireClient(player, { headshot = headshot, killed = killed })
		end
	end
end

local function onReload(player: Player)
	local loadout = loadouts[player]
	local now = workspace:GetServerTimeNow()
	if loadout and allowRequest(player, now) then
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

local function sendAmmo(player: Player, loadout: Weapon.Loadout, now: number)
	Weapon.update(loadout, now)
	local slot = Weapon.active(loadout)
	local reloading = slot.reloadDoneAt ~= nil
	local summary = `{slot.gunId}:{slot.ammo}:{reloading}`
	if sentAmmo[player] ~= summary then
		sentAmmo[player] = summary
		ammoRemote:FireClient(player, {
			gunId = slot.gunId,
			slot = loadout.active,
			ammo = slot.ammo,
			mag = slot.gun.mag,
			reloading = reloading,
		})
	end
end

local function applyLoadout(player: Player)
	local data = PlayerCards.get(player)
	local class = if data then data.class else DEFAULT_CLASS
	local rifle = if data then data.rifle else DEFAULT_RIFLE
	loadouts[player] = Weapon.newLoadout(class, rifle)
	sentAmmo[player] = nil
	player:SetAttribute("Class", class)
	player:SetAttribute("Rifle", rifle)
end

-- At full health a change can apply straight away. Otherwise it waits for respawn.
local function applyIfUnhurt(player: Player)
	local target = GunTargets.forPlayer(player)
	if target and target.health >= target.humanoid.MaxHealth then
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
	applyIfUnhurt(player)
end

local function onPlayer(player: Player)
	local function onCharacter(character: Model)
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
PlayerCards.profileLoaded:Connect(applyIfUnhurt)

Players.PlayerAdded:Connect(onPlayer)
for _, player in Players:GetPlayers() do
	task.spawn(onPlayer, player)
end
Players.PlayerRemoving:Connect(function(player)
	loadouts[player] = nil
	sentAmmo[player] = nil
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
		sendAmmo(player, loadout, now)
	end
end)
