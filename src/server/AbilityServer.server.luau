-- Server side of ability cards: owns cooldowns and runs each card's effect.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local CardCore = ReplicatedStorage:WaitForChild("CardCore")
local Ability = require(CardCore:WaitForChild("Ability"))
local Cards = require(CardCore:WaitForChild("Cards"))
local Config = require(CardCore:WaitForChild("Config"))
local Deck = require(CardCore:WaitForChild("Deck"))
local Tier = require(CardCore:WaitForChild("Tier"))
local GunTargets = require(script.Parent.GunTargets)
local loadouts = require(script.Parent.Loadouts)
local MoveGrace = require(script.Parent.MoveGrace)
local PlayerCards = require(script.Parent.PlayerCards)

local SHIELD_SIZE = 8
local SHIELD_COLOR = Color3.fromRGB(90, 170, 255)

-- Test room only: two decks cover all 4 cards. Phase 4 removes these.
local TEST_DECKS = {
	{ "phase_dash", "overclock", "recon_pulse" },
	{ "aegis_shell", "phase_dash", "overclock" },
}

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
local revealRemote = remote("Reveal")
local dashRemote = remote("Dash")
local pushRemote = remote("Push")
remotes.Parent = ReplicatedStorage

local slotsOf: { [Player]: { Ability.Slot } } = {}
local effectsOf: { [Player]: { [(boolean) -> ()]: boolean } } = {}
local testChoices: { [Player]: { deck: number, tier: number } } = {}

local handlers: { [string]: (Player, GunTargets.Target, Ability.Slot) -> boolean? } = {}

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

handlers.recon_pulse = function(player, target, slot)
	local radius = Cards.stat(slot.cardId, slot.tier, "radius")
	local found = {}
	for _, other in GunTargets.all() do
		local inRange = (other.root.Position - target.root.Position).Magnitude <= radius
		if inRange and isEnemy(player, other) and GunTargets.isAlive(other) then
			table.insert(found, other.model)
		end
	end
	revealRemote:FireClient(player, found, Cards.stat(slot.cardId, slot.tier, "revealTime"))
	if player.Team then
		for _, teammate in player.Team:GetPlayers() do
			if teammate ~= player then
				revealRemote:FireClient(teammate, found, Ability.teamRevealSeconds(slot.tier))
			end
		end
	end
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
	local stop = timed(player, Cards.stat(slot.cardId, slot.tier, "duration"), function()
		bubble:Destroy()
		target.shield = nil
		target.model:SetAttribute("ShieldHp", nil)
	end)
	target.shield = {
		hp = shieldHp,
		onBreak = function()
			stop(false)
			pushEnemies(player, target.root.Position, slot.tier)
		end,
	}
	return true
end

local function onUse(player: Player, raw: any)
	local index = Ability.parseSlot(raw)
	local target = GunTargets.forPlayer(player)
	local slots = slotsOf[player]
	if not index or not target or not slots or not GunTargets.isAlive(target) then
		return
	end
	local now = workspace:GetServerTimeNow()
	local slot = Ability.ready(slots, index, now)
	if slot and handlers[slot.cardId](player, target, slot) ~= false then
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
	slotsOf[player] = nil
	testChoices[player] = nil
end)
