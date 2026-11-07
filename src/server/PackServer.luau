-- Pack remotes on the server: rolling, opening, rebirths, and the auto roll and Auto Open loop.
-- The rules live in ReplicatedStorage.CardCore. This holds what doesn't belong in a save.
local GroupService = game:GetService("GroupService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CardCore = ReplicatedStorage:WaitForChild("CardCore")
local Config = require(CardCore.Config)
local Packs = require(CardCore.Packs)
local Rebirth = require(CardCore.Rebirth)
local Requests = require(CardCore.Requests)
local Zones = require(ReplicatedStorage:WaitForChild("Guns"):WaitForChild("Zones"))
local PlayerCards = require(script.Parent.PlayerCards)

local AUTO_STEP = 0.25 -- seconds

local sessions: { [Player]: any } = {}

local packEvent = Instance.new("RemoteEvent")
packEvent.Name = "PackEvent"
packEvent.Parent = PlayerCards.remotes

local PackServer = {}

local function session(player: Player): any
	local state = sessions[player]
	if not state then
		state = { lastRollAt = nil, lastOpenAt = nil, favorite = false, inGroup = false }
		sessions[player] = state
	end
	return state
end

function PackServer.announce(player: Player, event: any)
	packEvent:FireClient(player, event)
end

local function refreshUnlock(player: Player)
	local state = session(player)
	local unlocked = state.favorite or state.inGroup
	player:SetAttribute("AutoRollUnlocked", unlocked)
	if not unlocked then
		player:SetAttribute("AutoRollOn", false)
	end
end

-- Asks for the player's groups fresh, so joining counts without a rejoin.
local function checkGroup(player: Player)
	local ok, groups = pcall(function()
		return GroupService:GetGroupsAsync(player.UserId)
	end)
	if not ok then
		return
	end
	local member = false
	for _, group in groups do
		member = member or group.Id == Config.GroupId
	end
	session(player).inGroup = member
	refreshUnlock(player)
end

local function roll(player: Player, data: any, rng: () -> number): (boolean, string)
	local state = session(player)
	local now = os.clock()
	if not Packs.canRoll(state.lastRollAt, now) then
		return false, "TooSoon"
	end
	local ok, result = Packs.roll(data, rng)
	if not ok then
		return false, result
	end
	state.lastRollAt = now
	PlayerCards.changed(player)
	PackServer.announce(player, { kind = "Rolled", pack = result })
	return true, result
end

local function autoOpen(player: Player, data: any, rng: () -> number)
	local state = session(player)
	local now = os.clock()
	local pack = Packs.nextToOpen(data)
	if not pack or (state.lastOpenAt and now - state.lastOpenAt < Packs.OPEN_SECONDS) then
		return
	end
	state.lastOpenAt = now
	local _, cards = Packs.open(data, pack, rng)
	PlayerCards.changed(player)
	PackServer.announce(player, { kind = "Opened", pack = pack, cards = cards, auto = true })
end

-- Both only run in the Outpost, so nothing rolls or opens during a match.
local function autoLoop(rng: () -> number)
	while true do
		task.wait(AUTO_STEP)
		for _, player in PlayerCards.loaded() do
			local data = PlayerCards.get(player)
			if data and Zones.of(player) == Zones.Outpost then
				if player:GetAttribute("AutoRollOn") then
					roll(player, data, rng)
				end
				if player:GetAttribute("AutoOpenOwned") then
					autoOpen(player, data, rng)
				end
			end
		end
	end
end

-- Call before PlayerCards.start, so the first player's load isn't missed.
function PackServer.start(remote: (string, (Player, any, any) -> any) -> (), rng: () -> number)
	remote("Roll", function(player, data)
		local ok, result = roll(player, data, rng)
		return if ok then { ok = true, result = result } else { ok = false, code = result }
	end)

	remote("OpenPack", function(player, data, raw)
		local pack = Requests.parsePack(raw)
		if not pack then
			return { ok = false, code = "BadRequest" }
		end
		local ok, cards = Packs.open(data, pack, rng)
		if not ok then
			return { ok = false, code = cards }
		end
		PlayerCards.changed(player)
		PackServer.announce(player, { kind = "Opened", pack = pack, cards = cards, auto = false })
		return { ok = true }
	end)

	remote("Rebirth", function(player, data)
		local ok, code = Rebirth.perform(data)
		if not ok then
			return { ok = false, code = code }
		end
		PlayerCards.changed(player)
		PlayerCards.save(player)
		return { ok = true }
	end)

	remote("SetAutoRoll", function(player, _, raw)
		if not player:GetAttribute("AutoRollUnlocked") then
			return { ok = false, code = "Locked" }
		end
		player:SetAttribute("AutoRollOn", raw == true)
		return { ok = true }
	end)

	-- The server can't see a favorite, so this takes the client's word. The spec accepts that.
	remote("ClaimFavorite", function(player)
		session(player).favorite = true
		refreshUnlock(player)
		return { ok = true }
	end)

	remote("CheckGroup", function(player)
		checkGroup(player)
		return { ok = true }
	end)

	PlayerCards.profileLoaded:Connect(function(player: Player)
		task.spawn(checkGroup, player)
	end)
	Players.PlayerRemoving:Connect(function(player: Player)
		sessions[player] = nil
	end)
	task.spawn(autoLoop, rng)
end

return PackServer
