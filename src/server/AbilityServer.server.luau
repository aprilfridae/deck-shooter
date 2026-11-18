-- Server side of ability cards: owns cooldowns and runs each card's effect.
local Palette = require(game:GetService("ReplicatedStorage"):WaitForChild("Guns"):WaitForChild("Palette"))
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local CardCore = ReplicatedStorage:WaitForChild("CardCore")
local Ability = require(CardCore:WaitForChild("Ability"))
local CardAim = require(CardCore:WaitForChild("CardAim"))
local Cards = require(CardCore:WaitForChild("Cards"))
local Config = require(CardCore:WaitForChild("Config"))
local Deck = require(CardCore:WaitForChild("Deck"))
local Tier = require(CardCore:WaitForChild("Tier"))
local Zones = require(ReplicatedStorage:WaitForChild("Guns"):WaitForChild("Zones"))
local CardFlourish = require(ReplicatedStorage:WaitForChild("Guns"):WaitForChild("CardFlourish"))
local CardWalls = require(script.Parent.CardWalls)
local Decoys = require(script.Parent.Decoys)
local GunTargets = require(script.Parent.GunTargets)
local loadouts = require(script.Parent.Loadouts)
local MoveGrace = require(script.Parent.MoveGrace)
local PlayerCards = require(script.Parent.PlayerCards)

local SHIELD_SIZE = 8
local SHIELD_COLOR = Palette.DataCyan

-- Test room only: these decks cover all 10 cards. Phase 4 removes them.
local TEST_DECKS = {
	{ "switchback", "kickplate", "siphon" },
	{ "aegis_shell", "phase_dash", "overclock" },
	{ "flashpoint", "bulwark", "split" },
	{ "rewind", "flashpoint", "bulwark" },
}
local EYE = Vector3.new(0, 1.5, 0) -- from a body's middle up to its eyes
local USE_GAP = 0.1 -- seconds: the least time between one player's card uses
local MISS = "miss" -- what a handler returns when an aimed card hit nobody

local remotes = Instance.new("Folder")
remotes.Name = "AbilityRemotes"
local function remote(name: string): RemoteEvent
	local event = Instance.new("RemoteEvent")
	event.Name = name
	event.Parent = remotes
	return event
end
local useRemote = remote("Use")
local testDeckRemote = remote("TestDeck")
local fxRemote = remote("Fx") -- to everyone: a thrown card, bolt or blast to draw, with where it starts and ends (a card also says if it hit, and its tier)
local dashRemote = remote("Dash")
local pushRemote = remote("Push")
remotes.Parent = ReplicatedStorage

local slotsOf: { [Player]: { Ability.Slot } } = {}
local effectsOf: { [Player]: { [(boolean) -> ()]: boolean } } = {}
local testChoices: { [Player]: { deck: number, tier: number } } = {}

-- A handler returns false if the card couldn't be used (it isn't spent), MISS if it was aimed and hit nobody (it
-- comes back sooner), and anything else if it worked. `aim` is the unit direction the player was looking.
local handlers: { [string]: (Player, GunTargets.Target, Ability.Slot, CardAim.Point?) -> any } = {}

-- With no teams, everyone else is an enemy. A double counts as the player whose double it is.
local function isEnemy(owner: Player, target: GunTargets.Target): boolean
	local whose = target.player or target.owner
	if whose == owner then
		return false
	end
	return not (owner.Team and whose and whose.Team == owner.Team)
end

-- Runs finish(true) after the time, or finish(false) if the player's cards reset first.
local function timed(player: Player, seconds: number, finish: (boolean) -> ()): (boolean) -> ()
	local function stop(expired: boolean)
		local running = effectsOf[player]
		if running and running[stop] then
			running[stop] = nil
			finish(expired)
		end
	end
	effectsOf[player][stop] = true
	task.delay(seconds, stop, true)
	return stop
end

local function publish(player: Player)
	local slots = slotsOf[player] or {}
	for index = 1, Deck.SIZE do
		local slot = slots[index]
		player:SetAttribute(`Ability{index}Id`, slot and slot.cardId)
		player:SetAttribute(`Ability{index}Tier`, slot and slot.tier)
		player:SetAttribute(`Ability{index}ReadyAt`, slot and math.max(slot.readyAt, 0))
		player:SetAttribute(`Ability{index}Cooldown`, slot and Cards.cooldown(slot.cardId, slot.tier))
	end
end

local function endEffects(player: Player)
	local running = effectsOf[player]
	if running then
		for stop in running do
			stop(false)
		end
	end
end

local function deckFor(player: Player): { any }?
	local choice = testChoices[player]
	if not choice then
		local data = PlayerCards.get(player)
		return data and data.deck
	end
	local deck = {}
	for i, cardId in TEST_DECKS[choice.deck] do
		deck[i] = { cardId = cardId, tier = Tier.order[choice.tier] }
	end
	return deck
end

-- Every card comes back ready. Runs on each spawn until Phase 4 adds rounds.
local function resetCards(player: Player)
	endEffects(player)
	effectsOf[player] = {}
	slotsOf[player] = Ability.new(deckFor(player))
	publish(player)
end

handlers.phase_dash = function(player, target, slot)
	MoveGrace.give(player, Config.DashGraceSeconds)
	dashRemote:FireClient(player, Cards.stat(slot.cardId, slot.tier, "distance"))

	local original: { [Instance]: number } = {}
	for _, part in target.model:GetDescendants() do
		if (part:IsA("BasePart") or part:IsA("Decal")) and part.Transparency < 1 then
			original[part] = part.Transparency
			part.Transparency = Config.CamoTransparency
		end
	end
	timed(player, Ability.camoSeconds(slot.tier), function()
		for part, transparency in original do
			(part :: any).Transparency = transparency
		end
	end)
	return true
end

handlers.overclock = function(player, _, slot)
	local loadout = loadouts[player]
	if not loadout then
		return false
	end
	local bonus = Cards.stat(slot.cardId, slot.tier, "fireRateBonus")
	loadout.fireRateBonus = bonus
	player:SetAttribute("FireRateBonus", bonus)
	timed(player, Cards.stat(slot.cardId, slot.tier, "duration"), function()
		loadout.fireRateBonus = 0
		player:SetAttribute("FireRateBonus", nil)
	end)
	return true
end

-- Where an aimed card's line starts: about eye height, worked out here and never taken from the client.
local function eye(target: GunTargets.Target): Vector3
	return target.root.Position + EYE
end

local function asPoint(v: Vector3): CardAim.Point
	return { x = v.X, y = v.Y, z = v.Z }
end

local function asVector(point: CardAim.Point): Vector3
	return Vector3.new(point.x, point.y, point.z)
end

local function without(model: Model): RaycastParams
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { model }
	params.RespectCanCollide = true -- triggers and decoration don't block a card or count as ground
	return params
end

-- The enemy an aimed card hits, if any: the nearest one close to the line, in reach, with nothing solid between.
local function aimedEnemy(player: Player, target: GunTargets.Target, aim: CardAim.Point, reach: number): GunTargets.Target?
	local enemies: { GunTargets.Target } = {}
	local points: { CardAim.Point } = {}
	for _, other in GunTargets.all() do
		-- Someone standing where fighting isn't allowed can't be swapped out of it or slowed.
		local fighting = other.player == nil or Zones.allowsCombat(Zones.of(other.player))
		if fighting and isEnemy(player, other) and GunTargets.isAlive(other) then
			table.insert(enemies, other)
			table.insert(points, asPoint(other.root.Position))
		end
	end
	local from = eye(target)
	local found = CardAim.pick(asPoint(from), aim, reach, Config.AimWidth, points)
	local enemy = found and enemies[found]
	if not enemy then
		return nil
	end
	local blocked = workspace:Raycast(from, enemy.root.Position - from, without(target.model))
	if blocked and not blocked.Instance:IsDescendantOf(enemy.model) then
		return nil
	end
	return enemy
end

-- The card is thrown: you and the enemy it reaches swap places when it lands.
handlers.switchback = function(player, target, slot, aim)
	if not aim then
		return false
	end
	local reach = Cards.stat(slot.cardId, slot.tier, "range")
	local from = eye(target)
	local hand = target.root.Position -- the card is thrown from the chest, not out of the eyes
	local enemy = aimedEnemy(player, target, aim, reach)
	if not enemy then
		-- The card flies until it meets a wall or runs out.
		local wall = workspace:Raycast(from, asVector(aim) * reach, without(target.model))
		local ends = if wall then wall.Position else from + asVector(aim) * reach
		fxRemote:FireAllClients("card", hand, ends, false, slot.tier, player.UserId)
		return MISS
	end
	local landing = enemy.root.Position
	fxRemote:FireAllClients("card", hand, landing, true, slot.tier, player.UserId)
	-- The swap happens when the card lands: after the hand's wind-up and the flight. Either may have died by then.
	task.delay(CardAim.THROW_WINDUP + CardAim.flight((landing - hand).Magnitude), function()
		if not (GunTargets.isAlive(target) and GunTargets.isAlive(enemy)) then
			return
		end
		if not (target.root.Parent and enemy.root.Parent) then
			return
		end
		local mine, theirs = target.root.CFrame, enemy.root.CFrame
		MoveGrace.give(player, Config.SwitchbackGraceSeconds)
		if enemy.player then
			MoveGrace.give(enemy.player, Config.SwitchbackGraceSeconds)
		end
		-- Each keeps the way they were facing.
		target.root.CFrame = mine.Rotation + theirs.Position
		enemy.root.CFrame = theirs.Rotation + mine.Position
	end)
	return true
end

-- A blast on the ground you aim at throws you away from it.
handlers.kickplate = function(player, target, slot, aim)
	if not aim then
		return false
	end
	local hit = workspace:Raycast(eye(target), asVector(aim) * Config.KickplateReach, without(target.model))
	if not hit then
		return false -- nothing close enough to blast: the card isn't spent
	end
	for model in GunTargets.all() do
		if hit.Instance:IsDescendantOf(model) then
			return false -- a body isn't ground
		end
	end
	local way = asVector(CardAim.blastDirection(asPoint(hit.Position), asPoint(target.root.Position)))
	local speed = CardAim.launchSpeed(Cards.stat(slot.cardId, slot.tier, "height"), workspace.Gravity)
	-- The guard stays on and allows this launch's speed, rather than looking away for 3 seconds, which let a cheat
	-- go anywhere in that time.
	MoveGrace.allow(player, Config.KickplateGraceSeconds, way * speed)
	pushRemote:FireClient(player, way * speed)
	fxRemote:FireAllClients("blast", hit.Position, hit.Position + hit.Normal, false, slot.tier, player.UserId)
	return true
end

-- Speed changes from Siphon. A player's own boost and every slow on them multiply into one SpeedScale attribute,
-- which their Movement script reads.
local boosts: { [Player]: number } = {}
local slows: { [Player]: { [Player]: number } } = {}
-- A bot or the dummy has no Movement script, so its Humanoid is slowed directly: its own speed is kept here with
-- every slow on it, or two players' Siphons ending out of order would leave it slow for good.
local botSlows: { [Humanoid]: { base: number, by: { [Player]: number } } } = {}

local function publishBotSpeed(humanoid: Humanoid)
	local held = botSlows[humanoid]
	if not held then
		return
	end
	local worst = 0
	for _, slow in held.by do
		worst = math.max(worst, slow)
	end
	if humanoid.Parent then
		humanoid.WalkSpeed = held.base * (1 - worst)
	end
	if worst == 0 or not humanoid.Parent then
		botSlows[humanoid] = nil
	end
end

local function publishSpeed(player: Player)
	local scale = 1 + (boosts[player] or 0)
	local worst = 0
	for _, slow in slows[player] or {} do
		worst = math.max(worst, slow)
	end
	scale *= 1 - worst
	player:SetAttribute("SpeedScale", if scale == 1 then nil else scale)
end

-- A bolt that takes speed from the enemy it hits and gives it to you.
handlers.siphon = function(player, target, slot, aim)
	if not aim then
		return false
	end
	local from = eye(target)
	local enemy = aimedEnemy(player, target, aim, Config.SiphonRange)
	if not enemy then
		-- A miss stops at the first wall, so the bolt isn't drawn through it.
		local wall = workspace:Raycast(from, asVector(aim) * Config.SiphonRange, without(target.model))
		local ends = if wall then wall.Position else from + asVector(aim) * Config.SiphonRange
		fxRemote:FireAllClients("bolt", from, ends, false, slot.tier, player.UserId)
		return MISS
	end
	local steal = Cards.stat(slot.cardId, slot.tier, "speedSteal")
	local seconds = Cards.stat(slot.cardId, slot.tier, "duration")
	-- The body hit and how long the drain lasts go along, for the tether drawn between the two of you.
	fxRemote:FireAllClients("bolt", from, enemy.root.Position, true, slot.tier, player.UserId, enemy.model, seconds)
	-- No grace from the movement guard: the fastest ordinary move with the biggest boost is still under its
	-- limit, and grace would switch the guard off for seconds at a time.
	boosts[player] = steal
	publishSpeed(player)
	local victim = enemy.player
	local bot = enemy.humanoid
	if victim then
		slows[victim] = slows[victim] or {}
		slows[victim][player] = steal
		publishSpeed(victim)
	else
		local held = botSlows[bot] or { base = bot.WalkSpeed, by = {} }
		botSlows[bot] = held
		held.by[player] = steal
		publishBotSpeed(bot)
	end
	timed(player, seconds, function()
		boosts[player] = nil
		publishSpeed(player)
		if victim then
			if slows[victim] then
				slows[victim][player] = nil
				publishSpeed(victim)
			end
		elseif botSlows[bot] then
			botSlows[bot].by[player] = nil
			publishBotSpeed(bot)
		end
	end)
	return true
end

local function pushEnemies(owner: Player, center: Vector3, tier: string)
	local speed = Ability.pushSpeed(tier)
	for _, other in GunTargets.all() do
		local away = other.root.Position - center
		if away.Magnitude <= Config.PushRadius and isEnemy(owner, other) and GunTargets.isAlive(other) then
			local flat = Vector3.new(away.X, 0, away.Z)
			local direction = if flat.Magnitude > 0.01 then flat.Unit else Vector3.xAxis
			local velocity = direction * speed + Vector3.yAxis * Config.PushRise
			if other.player then
				MoveGrace.give(other.player, Config.MoveGraceSeconds)
				pushRemote:FireClient(other.player, velocity)
			else
				other.humanoid:ChangeState(Enum.HumanoidStateType.Freefall)
				other.root.AssemblyLinearVelocity = velocity
			end
		end
	end
end

local function shieldBubble(target: GunTargets.Target): Part
	local bubble = Instance.new("Part")
	bubble.Name = "AegisShell"
	bubble.Shape = Enum.PartType.Ball
	bubble.Size = Vector3.one * SHIELD_SIZE
	bubble.Material = Enum.Material.ForceField
	bubble.Color = SHIELD_COLOR
	bubble.CanCollide = false
	bubble.CanQuery = false
	bubble.CanTouch = false
	bubble.Massless = true
	bubble.CFrame = target.root.CFrame
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = bubble
	weld.Part1 = target.root
	weld.Parent = bubble
	bubble.Parent = workspace
	return bubble
end

handlers.aegis_shell = function(player, target, slot)
	local bubble = shieldBubble(target)
	local shieldHp = Cards.stat(slot.cardId, slot.tier, "shieldHp")
	target.model:SetAttribute("ShieldHp", shieldHp)
	-- Running out and being broken end it the same way. Dying does not push anyone.
	local stop = timed(player, Cards.stat(slot.cardId, slot.tier, "duration"), function(ended)
		bubble:Destroy()
		target.shield = nil
		target.model:SetAttribute("ShieldHp", nil)
		if ended then
			pushEnemies(player, target.root.Position, slot.tier)
		end
	end)
	target.shield = {
		hp = shieldHp,
		onBreak = function()
			stop(true)
		end,
	}
	return true
end

-- The way someone is looking, flat on the ground. Their body's facing if they look straight up or down.
local function flatWay(target: GunTargets.Target, aim: CardAim.Point): Vector3
	local flat = Vector3.new(aim.x, 0, aim.z)
	if flat.Magnitude < 0.05 then
		flat = Vector3.new(target.root.CFrame.LookVector.X, 0, target.root.CFrame.LookVector.Z)
	end
	return if flat.Magnitude > 0.01 then flat.Unit else Vector3.zAxis
end

-- Rays that only walls stop: no body blocks them.
local function wallsOnly(): RaycastParams
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local bodies = {}
	for model in GunTargets.all() do
		table.insert(bodies, model)
	end
	params.FilterDescendantsInstances = bodies
	params.RespectCanCollide = true
	return params
end

-- Flashpoint: the card is flicked the way you look, and bursts where it meets something or runs out. Every enemy
-- who could see the burst is told how long they're blind for at most; their own client takes off for the way they
-- were facing (CardAim.flashFacing), since only it knows that to the frame. A cheat could ignore the flash, but it
-- couldn't gain anything else.
handlers.flashpoint = function(player, target, slot, aim)
	if not aim then
		return false
	end
	local from = eye(target)
	local way = asVector(aim)
	local stop = workspace:Raycast(from, way * Config.FlashRange, without(target.model))
	-- It bursts just off what it hit, so the light isn't inside a wall.
	local burst = if stop then stop.Position + stop.Normal * 0.75 else from + way * Config.FlashRange
	local hand = target.root.Position
	local seconds = Cards.stat(slot.cardId, slot.tier, "blind")
	fxRemote:FireAllClients("flash", hand, burst, false, slot.tier, player.UserId)
	local flight = CardAim.flashFlight((burst - hand).Magnitude, Config.FlashSpeed, Config.FlashLeast)
	task.delay(CardFlourish.FLICK_RELEASE + flight, function()
		local params = wallsOnly()
		for _, other in GunTargets.all() do
			if other.player and isEnemy(player, other) and GunTargets.isAlive(other) then
				local at = eye(other)
				local reach = CardAim.flashReach((at - burst).Magnitude, Config.FlashRadius, Config.FlashFullWithin, Config.FlashEdge)
				if reach > 0 and not workspace:Raycast(burst, at - burst, params) then
					fxRemote:FireClient(other.player, "blind", burst, burst, false, seconds * reach)
				end
			end
		end
	end)
	return true
end

-- Where a Bulwark stands: on the ground you aim at, if that's in reach and flat enough to stand on, or else on the
-- ground in front of you. Its face looks the way you do. nil if there's no ground for it.
local function wallSpot(target: GunTargets.Target, aim: CardAim.Point): CFrame?
	local params = without(target.model)
	local way = flatWay(target, aim)
	local hit = workspace:Raycast(eye(target), asVector(aim) * Config.WallReach, params)
	local spot: Vector3? = nil
	if hit and hit.Normal.Y >= 0.7 then
		spot = hit.Position
		for model in GunTargets.all() do
			if hit.Instance:IsDescendantOf(model) then
				spot = nil -- a body isn't ground
				break
			end
		end
	end
	if not spot then
		local ahead = target.root.Position + way * Config.WallAhead
		-- Not through a wall in front of you.
		if workspace:Raycast(target.root.Position, ahead - target.root.Position, params) then
			return nil
		end
		local down = workspace:Raycast(ahead, Vector3.new(0, -12, 0), params)
		if not down or down.Normal.Y < 0.7 then
			return nil
		end
		spot = down.Position
	end
	local at = spot :: Vector3
	return CFrame.lookAt(at, at + way)
end

-- Bulwark: a giant card stands up where the card was slapped down, when the hand lands (CardFlourish.SLAM_HIT).
-- Nothing happens if there's no ground for it, and the card isn't spent.
handlers.bulwark = function(player, target, slot, aim)
	if not aim then
		return false
	end
	local spot = wallSpot(target, aim)
	if not spot then
		return false
	end
	local hp = Cards.stat(slot.cardId, slot.tier, "wallHp")
	local seconds = Cards.stat(slot.cardId, slot.tier, "duration")
	local size = Vector3.new(Config.WallWidth, Config.WallHeight, Config.WallThick)
	local wall: BasePart? = nil
	local stop = timed(player, CardFlourish.SLAM_HIT + seconds, function()
		if wall then
			CardWalls.remove(wall)
			wall = nil
		end
	end)
	task.delay(CardFlourish.SLAM_HIT, function()
		local running = effectsOf[player]
		if not running or not running[stop] then
			return -- the player died or their cards reset before it landed
		end
		wall = CardWalls.place(spot, size, hp, slot.tier, player, function()
			stop(true)
		end)
	end)
	return true
end

-- Split: the copy card drops in front of you and your double stands up there, then sprints the way you looked.
handlers.split = function(player, target, slot, aim)
	if not aim then
		return false
	end
	local way = flatWay(target, aim)
	local start = target.root.Position
	local land = start + way * Config.DecoyAhead
	if workspace:Raycast(start, land - start, without(target.model)) then
		land = start -- something's in the way: it stands up where you are
	end
	local hand = target.root.Position
	fxRemote:FireAllClients("decoy", hand, land, false, slot.tier, player.UserId)
	local seconds = Cards.stat(slot.cardId, slot.tier, "duration")
	local gunId = player:GetAttribute("GunId")
	local double: GunTargets.Target? = nil
	local stop = timed(player, CardFlourish.SPLIT_RELEASE + Config.DecoyFall + seconds, function()
		if double then
			Decoys.vanish(double)
		end
	end)
	task.delay(CardFlourish.SPLIT_RELEASE + Config.DecoyFall, function()
		local running = effectsOf[player]
		if not running or not running[stop] or not GunTargets.isAlive(target) then
			return
		end
		double = Decoys.spawn(
			player,
			target.model,
			CFrame.lookAt(land, land + way),
			if type(gunId) == "string" then gunId else nil,
			Config.DecoyHealth,
			function(model)
				fxRemote:FireAllClients("vanish", model:GetPivot().Position, model:GetPivot().Position, false, slot.tier, player.UserId, model)
			end,
			Config.DecoyVanish
		)
	end)
	return true
end

-- Where each player has been lately, for Rewind: their root and health every PATH_EVERY seconds, oldest first.
local PATH_EVERY = 0.1
type PathPoint = { at: number, position: Vector3, health: number, zone: string }
local paths: { [Player]: { PathPoint } } = {}

-- Rewind: you snap back to where you were RewindSeconds ago (only within the zone you're in now), facing the way
-- you face now, at the hand's snap (CardFlourish.REWIND_SNAP), and get back the health you've lost since, up to
-- the card's heal. Not spent if there isn't enough path yet.
handlers.rewind = function(player, target, slot)
	local path = paths[player]
	if not path then
		return false
	end
	local zone = Zones.of(player)
	local same = {}
	for _, point in path do
		if point.zone == zone then
			table.insert(same, point)
		end
	end
	local now = workspace:GetServerTimeNow()
	local index = CardAim.rewindPoint(same, now, Config.RewindSeconds, Config.RewindLeast)
	if not index then
		return false
	end
	local back = same[index]
	-- Standing still with nothing lost, there is nowhere to go back to: the card isn't spent on nothing.
	local moved = (back.position - target.root.Position).Magnitude >= Config.RewindLeastDistance
	if not moved and back.health <= target.health then
		return false
	end
	local heal = Cards.stat(slot.cardId, slot.tier, "heal")
	task.delay(CardFlourish.REWIND_SNAP, function()
		if not GunTargets.isAlive(target) or Zones.of(player) ~= zone then
			return
		end
		local from = target.root.Position
		MoveGrace.give(player, Config.RewindGraceSeconds)
		target.root.CFrame = target.root.CFrame.Rotation + back.position
		target.root.AssemblyLinearVelocity = Vector3.zero
		local lost = back.health - target.health
		if lost > 0 then
			local health = math.min(target.health + math.min(lost, heal), target.humanoid.MaxHealth)
			target.health = health
			target.humanoid.Health = health
			target.model:SetAttribute("Health", health)
		end
		fxRemote:FireAllClients("rewind", from, back.position, false, slot.tier, player.UserId)
	end)
	return true
end

local pathWaited = 0
RunService.Heartbeat:Connect(function(dt)
	pathWaited += dt
	if pathWaited < PATH_EVERY then
		return
	end
	pathWaited = 0
	local now = workspace:GetServerTimeNow()
	for _, player in Players:GetPlayers() do
		local target = GunTargets.forPlayer(player)
		if target and GunTargets.isAlive(target) then
			local path = paths[player] or {}
			paths[player] = path
			table.insert(path, { at = now, position = target.root.Position, health = target.health, zone = Zones.of(player) })
			while path[1] and now - path[1].at > Config.RewindSeconds + 1 do
				table.remove(path, 1)
			end
		end
	end
end)

local lastUse: { [Player]: number } = {}

local function onUse(player: Player, raw: any, rawAim: any)
	-- A card that can't be used isn't spent, so nothing else stops a client sending this in a flood.
	local clock = os.clock()
	if clock - (lastUse[player] or 0) < USE_GAP then
		return
	end
	lastUse[player] = clock
	local index = Ability.parseSlot(raw)
	local target = GunTargets.forPlayer(player)
	local slots = slotsOf[player]
	if not index or not target or not slots or not GunTargets.isAlive(target) or not Zones.allowsCombat(Zones.of(player)) then
		return
	end
	local now = workspace:GetServerTimeNow()
	local slot = Ability.ready(slots, index, now)
	local handler = slot and handlers[slot.cardId]
	if not slot or not handler then
		return -- nothing there, or a card that has since been removed from the game
	end
	local aim = if typeof(rawAim) == "Vector3" then CardAim.direction(rawAim.X, rawAim.Y, rawAim.Z) else nil
	local result = handler(player, target, slot, aim)
	if result == MISS then
		Ability.spendMiss(slot, now)
		publish(player)
	elseif result ~= false then
		Ability.spend(slot, now)
		publish(player)
	end
end

local function onTestDeck(player: Player, action: any)
	if not RunService:IsStudio() then
		return
	end
	local choice = testChoices[player] or { deck = 1, tier = 1 }
	if action == "deck" then
		choice.deck = choice.deck % #TEST_DECKS + 1
	elseif action == "tier" then
		choice.tier = choice.tier % #Tier.order + 1
	else
		return
	end
	testChoices[player] = choice
	resetCards(player)
end

-- Effects end at death, not at the next spawn, so they can't outlive the player.
local function onCharacter(player: Player, character: Model)
	resetCards(player)
	paths[player] = nil -- Rewind never takes you back into your last life
	-- A new life starts at full speed, whoever had slowed the last one.
	slows[player] = nil
	publishSpeed(player)
	local humanoid = character:WaitForChild("Humanoid", 10) :: Humanoid?
	if humanoid then
		humanoid.Died:Once(function()
			endEffects(player)
		end)
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

useRemote.OnServerEvent:Connect(onUse)
testDeckRemote.OnServerEvent:Connect(onTestDeck)
-- The save can finish loading after the first spawn.
PlayerCards.profileLoaded:Connect(resetCards)

Players.PlayerAdded:Connect(onPlayer)
for _, player in Players:GetPlayers() do
	task.spawn(onPlayer, player)
end
Players.PlayerRemoving:Connect(function(player)
	endEffects(player)
	effectsOf[player] = nil
	lastUse[player] = nil
	boosts[player] = nil
	slows[player] = nil
	slotsOf[player] = nil
	testChoices[player] = nil
	paths[player] = nil
end)
