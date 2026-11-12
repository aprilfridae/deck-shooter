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
local GunTargets = require(script.Parent.GunTargets)
local loadouts = require(script.Parent.Loadouts)
local MoveGrace = require(script.Parent.MoveGrace)
local PlayerCards = require(script.Parent.PlayerCards)

local SHIELD_SIZE = 8
local SHIELD_COLOR = Palette.DataCyan

-- Test room only: two decks cover all 6 cards. Phase 4 removes these.
local TEST_DECKS = {
	{ "switchback", "kickplate", "siphon" },
	{ "aegis_shell", "phase_dash", "overclock" },
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

-- With no teams, everyone else is an enemy.
local function isEnemy(owner: Player, target: GunTargets.Target): boolean
	if target.player == owner then
		return false
	end
	return not (owner.Team and target.player and target.player.Team == owner.Team)
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
	MoveGrace.give(player, Config.KickplateGraceSeconds)
	pushRemote:FireClient(player, way * speed)
	fxRemote:FireAllClients("blast", hit.Position, hit.Position + hit.Normal)
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
		fxRemote:FireAllClients("bolt", from, from + asVector(aim) * Config.SiphonRange)
		return MISS
	end
	local steal = Cards.stat(slot.cardId, slot.tier, "speedSteal")
	local seconds = Cards.stat(slot.cardId, slot.tier, "duration")
	fxRemote:FireAllClients("bolt", from, enemy.root.Position)
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
end)
