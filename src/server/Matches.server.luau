-- Elimination matches (docs/specs/matches.md): the queues on the Play page, and each match from the first round to
-- the trip back to the Outpost. The rules themselves are in Guns/MatchRules.luau.
--
-- Each match builds its own copy of its arena far from everything else (Hex or Relay for 1v1, Yard for 2v2 and
-- 3v3), so nobody in free play can walk into it, and removes it at the end. Players keep the map's zone, so its
-- lighting and fog work as in free play; the MatchId attribute is what marks them as in a match.
--
-- What a client sees comes from ReplicatedStorage.Matches.<id>, a folder whose attributes are the match's state:
-- Phase (Countdown, Playing, Between, Over), PhaseEnds (server time), Round, Wins1, Wins2, Arena, TeamSize,
-- RoundWinner (0 for a replayed tie) and Winner. Players carry MatchId and MatchTeam, and MatchFrozen while held
-- at the spawns.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Teams = game:GetService("Teams")

local Guns = ReplicatedStorage:WaitForChild("Guns")
local MatchRules = require(Guns:WaitForChild("MatchRules"))
local Zones = require(Guns:WaitForChild("Zones"))
local Config = require(ReplicatedStorage:WaitForChild("CardCore"):WaitForChild("Config"))
local GunTargets = require(script.Parent.GunTargets)
local PlayerCards = require(script.Parent.PlayerCards)
local MatchHooks = require(script.Parent.MatchHooks)
local MoveGrace = require(script.Parent.MoveGrace)
local Hex = require(script.Parent.Outpost.Hex)
local Places = require(script.Parent.Outpost.Places)
local Relay = require(script.Parent.Outpost.Relay)
local Yard = require(script.Parent.Outpost.Yard)

local SLOT_X = 9000 -- the first match's arena; later ones go further out
local SLOT_SPACING = 1600
local MAX_MATCHES = 6 -- at once; a full queue waits for a free arena
local CHECK_EVERY = 0.2 -- seconds between looks at who is still alive
local LOAD_TIMEOUT = 12 -- seconds to wait for a round's bodies to load
local RESULT_SECONDS = 6 -- the match result stays up this long before everyone goes back
local QUEUE_EVERY = 0.4 -- seconds a player must wait between queue requests
local TEAM_COLORS = { BrickColor.new("Teal"), BrickColor.new("Deep orange") }
local TEAM_NAMES = { "TEAL", "ORANGE" }

-- Where each arena's copies go. Relay and Hex keep their free-play heights, which their checks rely on (falling
-- off Relay is measured from its height).
local ARENAS = {
	Hex = { zone = Zones.Hex, height = 100, build = Hex.build },
	Relay = { zone = Zones.Relay, height = 300, build = Relay.build },
	Yard = { zone = Zones.Yard, height = 50, build = Yard.build },
}

type Member = {
	player: Player?,
	bot: Model?, -- a Studio stand-in for a missing opponent
	team: number,
	place: number, -- which of the team's spawns
	present: boolean, -- still in the match (not left or removed)
}

type Match = {
	id: number,
	queue: { id: string, mode: string, size: number },
	rules: MatchRules.ModeRules,
	arena: string,
	built: any,
	slot: number,
	teams: { Team },
	members: { Member },
	wins: { number },
	scored: number,
	round: number,
	state: Folder,
	over: boolean,
	standIns: boolean, -- a Studio test against stand-in bodies, which pays nothing
}

local remotes = Instance.new("Folder")
remotes.Name = "MatchRemotes"
local queueRemote = Instance.new("RemoteEvent")
queueRemote.Name = "Queue" -- (queueId or false, studioSolo?) client to server
queueRemote.Parent = remotes
remotes.Parent = ReplicatedStorage

local states = Instance.new("Folder")
states.Name = "Matches"
states.Parent = ReplicatedStorage
-- How many are waiting in each queue, as attributes named by queue id.
local queueCounts = Instance.new("Folder")
queueCounts.Name = "MatchQueues"
queueCounts.Parent = ReplicatedStorage

local waiting: { [string]: { Player } } = {}
for _, queue in MatchRules.QUEUES do
	waiting[queue.id] = {}
	queueCounts:SetAttribute(queue.id, 0)
end
local lastRequest: { [Player]: number } = {}
local slots: { [number]: Match } = {}
local byPlayer: { [Player]: Match } = {}
local nextId = 0

local function publishQueue(id: string)
	queueCounts:SetAttribute(id, #waiting[id])
end

local function dequeue(player: Player)
	local id = player:GetAttribute("QueuedFor")
	if type(id) == "string" and waiting[id] then
		local list = waiting[id]
		local at = table.find(list, player)
		if at then
			table.remove(list, at)
		end
		publishQueue(id)
	end
	player:SetAttribute("QueuedFor", nil)
end

local function memberOf(match: Match, player: Player): Member?
	for _, member in match.members do
		if member.player == player then
			return member
		end
	end
	return nil
end

local function setPhase(match: Match, phase: string, seconds: number)
	match.state:SetAttribute("Phase", phase)
	match.state:SetAttribute("PhaseEnds", workspace:GetServerTimeNow() + seconds)
end

-- Holds a member at their spawn (and off their guns and cards) or lets them go.
local function freeze(member: Member, frozen: boolean)
	local model = if member.player then member.player.Character else member.bot
	local root = model and model:FindFirstChild("HumanoidRootPart") :: BasePart?
	if member.player then
		member.player:SetAttribute("MatchFrozen", if frozen then true else nil)
	end
	if root then
		root.Anchored = frozen
	end
end

local function spawnOf(match: Match, member: Member): SpawnLocation
	local list = match.built.spawns[member.team]
	return if typeof(list) == "Instance" then list else list[math.min(member.place, #list)]
end

-- A standing body for the other side when testing alone in Studio. It can be shot and hit by cards; it never
-- shoots back.
local function spawnBot(match: Match, member: Member)
	if member.bot then
		member.bot:Destroy()
		member.bot = nil
	end
	local description = Instance.new("HumanoidDescription")
	local ok, model = pcall(Players.CreateHumanoidModelFromDescription, Players, description, Enum.HumanoidRigType.R15)
	if not ok or not model then
		return
	end
	model.Name = "MatchBot"
	model:PivotTo(spawnOf(match, member).CFrame * CFrame.new(0, 3.5, 0))
	model.Parent = match.built.folder
	local target = GunTargets.add(model, nil)
	if target then
		target.root:SetNetworkOwner(nil)
	end
	member.bot = model
end

local function aliveHealth(member: Member): number?
	if not member.present then
		return nil
	end
	local model = if member.player then member.player.Character else member.bot
	if not model then
		return nil
	end
	local target = GunTargets.all()[model]
	if target and GunTargets.isAlive(target) then
		return target.health
	end
	return nil
end

local function sides(match: Match): (MatchRules.Side, MatchRules.Side)
	local result = { { alive = 0, health = 0, present = 0 }, { alive = 0, health = 0, present = 0 } }
	for _, member in match.members do
		local side = result[member.team]
		if member.present then
			side.present += 1
		end
		local health = aliveHealth(member)
		if health then
			side.alive += 1
			side.health += health
		end
	end
	return result[1], result[2]
end

-- Everyone still in the match back at their spawn with a fresh body: full health, full ammo and every card ready
-- (cards and guns reset on each spawn), held there until the countdown ends.
local function placeAll(match: Match)
	local arena = ARENAS[match.arena]
	local pending = 0
	for _, member in match.members do
		if member.present then
			local player = member.player
			if player then
				pending += 1
				task.spawn(function()
					Places.spawnOverride[player] = spawnOf(match, member)
					if Places.setZone then
						Places.setZone(player, arena.zone)
					end
					MoveGrace.give(player, 1)
					if Places.loadBody then
						Places.loadBody(player)
					end
					pending -= 1
				end)
			else
				spawnBot(match, member)
			end
		end
	end
	local giveUp = os.clock() + LOAD_TIMEOUT
	while pending > 0 and os.clock() < giveUp do
		task.wait(0.1)
	end
	for _, member in match.members do
		if member.present then
			-- The new body's root, once it's there.
			local model = if member.player then member.player.Character else member.bot
			if model then
				model:WaitForChild("HumanoidRootPart", 5)
			end
			freeze(member, true)
		end
	end
end

local function clearPlayer(player: Player)
	byPlayer[player] = nil
	Places.spawnOverride[player] = nil
	Places.holdRespawn[player] = nil
	player:SetAttribute("MatchId", nil)
	player:SetAttribute("MatchTeam", nil)
	player:SetAttribute("MatchFrozen", nil)
	if player.Parent == Players then
		player.Team = nil
	end
end

-- Takes someone out of the match (left, removed by a cheat check) and, if they're still here, home.
local function remove(match: Match, player: Player)
	local member = memberOf(match, player)
	if not member or not member.present then
		return
	end
	member.present = false
	clearPlayer(player)
	if player.Parent == Players and Places.travel then
		Places.travel(player, Zones.Outpost)
	end
end

-- The winners' Catalysts (MatchRules.catalystsFor), saved with their cards.
local function reward(match: Match, winner: number?)
	local catalysts = MatchRules.catalystsFor(match.rules, match.wins, winner, match.standIns)
	match.state:SetAttribute("Catalysts", catalysts)
	if catalysts <= 0 then
		return
	end
	for _, member in match.members do
		local player = member.player
		local data = player and member.present and member.team == winner and PlayerCards.get(player)
		if player and data then
			data.catalysts = math.min(data.catalysts + catalysts, Config.MaxStackCount)
			PlayerCards.changed(player)
		end
	end
end

local function finish(match: Match, winner: number?)
	match.over = true
	match.state:SetAttribute("Winner", winner or 0)
	reward(match, winner)
	setPhase(match, "Over", RESULT_SECONDS)
	for _, member in match.members do
		if member.present then
			freeze(member, true)
		end
	end
	task.wait(RESULT_SECONDS)
	for _, member in match.members do
		local player = member.player
		if player and member.present then
			member.present = false
			clearPlayer(player)
			if player.Parent == Players and Places.travel then
				task.spawn(Places.travel, player, Zones.Outpost)
			end
		end
		if member.bot then
			member.bot:Destroy()
		end
	end
	task.wait(1) -- the last bodies off the map before it goes
	for _, team in match.teams do
		team:Destroy()
	end
	match.built.folder:Destroy()
	match.state:Destroy()
	slots[match.slot] = nil
end

-- One round, from the countdown to its result. Returns the winning team, "Replay", or "Forfeit" with the team that
-- is left.
local function playRound(match: Match): (string | number, number?)
	match.round += 1
	match.state:SetAttribute("Round", match.round)
	match.state:SetAttribute("RoundWinner", nil)
	setPhase(match, "Countdown", match.rules.countdownSeconds + 1)
	placeAll(match)
	setPhase(match, "Countdown", match.rules.countdownSeconds)
	task.wait(match.rules.countdownSeconds)
	for _, member in match.members do
		if member.present then
			freeze(member, false)
		end
	end
	setPhase(match, "Playing", match.rules.roundSeconds)
	local ends = os.clock() + match.rules.roundSeconds
	while true do
		local a, b = sides(match)
		local left = MatchRules.forfeit(a, b)
		if left or (a.present <= 0 and b.present <= 0) then
			return "Forfeit", left
		end
		local result = MatchRules.roundResult(a, b, os.clock() >= ends)
		if result ~= "Playing" then
			return result
		end
		task.wait(CHECK_EVERY)
	end
end

local function run(match: Match)
	while not match.over do
		local result, left = playRound(match)
		if result == "Forfeit" then
			finish(match, left)
			return
		end
		if result == "Replay" then
			match.state:SetAttribute("RoundWinner", 0)
		else
			local team = result :: number
			match.wins[team] += 1
			match.scored += 1
			match.state:SetAttribute("Wins" .. team, match.wins[team])
			match.state:SetAttribute("RoundWinner", team)
		end
		local winner = MatchRules.matchWinner(match.rules, match.wins, match.scored)
		if winner then
			finish(match, winner)
			return
		end
		-- The break: nobody can fight, and it's when a class or rifle change is made (it applies on the next
		-- round's fresh body).
		for _, member in match.members do
			if member.present then
				freeze(member, true)
			end
		end
		setPhase(match, "Between", match.rules.betweenSeconds)
		task.wait(match.rules.betweenSeconds)
	end
end

local function freeSlot(): number?
	for slot = 1, MAX_MATCHES do
		if not slots[slot] then
			return slot
		end
	end
	return nil
end

-- Starts a match for these teams. A team may be short of players only in a Studio solo test, where bots fill it.
local function start(queue: any, one: { Player }, two: { Player }, fillWithBots: boolean): boolean
	local slot = freeSlot()
	if not slot then
		return false
	end
	nextId += 1
	local arenaName = if queue.size == 1 then (if math.random() < 0.5 then "Hex" else "Relay") else "Yard"
	local arena = ARENAS[arenaName]
	local origin = CFrame.new(SLOT_X + (slot - 1) * SLOT_SPACING, arena.height, 0)
	local built = arena.build(origin)
	built.folder.Name = "MatchArena" .. nextId
	-- Free-play maps come with OUTPOST terminals; in a match the way home is finishing it.
	for _, prompt in built.terminals or {} do
		prompt.Enabled = false
	end

	local state = Instance.new("Folder")
	state.Name = tostring(nextId)
	state:SetAttribute("Mode", queue.mode)
	state:SetAttribute("TeamSize", queue.size)
	state:SetAttribute("Arena", arenaName)
	state:SetAttribute("Wins1", 0)
	state:SetAttribute("Wins2", 0)
	state:SetAttribute("WinsNeeded", MatchRules.Elimination.winsNeeded)
	state:SetAttribute("Round", 0)
	state:SetAttribute("RoundSeconds", MatchRules.Elimination.roundSeconds)

	local match: Match = {
		id = nextId,
		queue = queue,
		rules = MatchRules.Elimination,
		arena = arenaName,
		built = built,
		slot = slot,
		teams = {},
		members = {},
		wins = { 0, 0 },
		scored = 0,
		round = 0,
		state = state,
		over = false,
		standIns = fillWithBots,
	}
	slots[slot] = match
	for index = 1, 2 do
		local team = Instance.new("Team")
		team.Name = `{TEAM_NAMES[index]} {nextId}`
		team.TeamColor = TEAM_COLORS[index]
		team.AutoAssignable = false
		team.Parent = Teams
		match.teams[index] = team
	end
	for index, list in { one, two } do
		for place = 1, queue.size do
			local player = list[place]
			local member: Member = { player = player, team = index, place = place, present = true }
			if player then
				dequeue(player)
				byPlayer[player] = match
				Places.holdRespawn[player] = true
				player:SetAttribute("MatchId", nextId)
				player:SetAttribute("MatchTeam", index)
				player.Team = match.teams[index]
				MatchHooks.join(player)
				table.insert(match.members, member)
			elseif fillWithBots then
				table.insert(match.members, member)
			end
		end
	end
	state.Parent = states
	task.spawn(run, match)
	return true
end

local function tryStart(id: string)
	local queue = MatchRules.queue(id)
	local list = waiting[id]
	while queue and list do
		local one, two = MatchRules.split(list, queue.size)
		if not one or not two then
			return
		end
		if not start(queue, one, two, false) then
			return -- every arena is in use; the queue waits for one to finish
		end
	end
end

queueRemote.OnServerEvent:Connect(function(player: Player, id: any, solo: any)
	local now = os.clock()
	if now - (lastRequest[player] or -math.huge) < QUEUE_EVERY then
		return
	end
	lastRequest[player] = now
	if byPlayer[player] or Zones.of(player) ~= Zones.Outpost then
		return
	end
	dequeue(player)
	local queue = MatchRules.queue(id)
	if not queue then
		return -- anything but a known queue just leaves the one you were in
	end
	-- Studio only: start at once, with bots for the other side, to try a match alone.
	if solo == true and RunService:IsStudio() then
		start(queue, { player }, {}, true)
		return
	end
	table.insert(waiting[queue.id], player)
	player:SetAttribute("QueuedFor", queue.id)
	publishQueue(queue.id)
	tryStart(queue.id)
end)

-- A queued player who leaves the Outpost is out of the queue.
local function watchZone(player: Player)
	player:GetAttributeChangedSignal("Zone"):Connect(function()
		if Zones.of(player) ~= Zones.Outpost then
			dequeue(player)
		end
	end)
end
Players.PlayerAdded:Connect(watchZone)
for _, player in Players:GetPlayers() do
	watchZone(player)
end

Players.PlayerRemoving:Connect(function(player)
	dequeue(player)
	lastRequest[player] = nil
	local match = byPlayer[player]
	if match then
		local member = memberOf(match, player)
		if member then
			member.present = false
		end
		byPlayer[player] = nil
	end
end)

MatchHooks.cheated:Connect(function(player, why)
	local match = byPlayer[player]
	if match then
		warn(`[Matches] removed {player.UserId} from match {match.id}: {why}`)
		remove(match, player)
	end
end)

-- An arena is freed when its match ends; a queue that filled while they were all busy starts then.
task.spawn(function()
	Places.ready()
	while true do
		task.wait(1)
		for id in waiting do
			tryStart(id)
		end
	end
end)
