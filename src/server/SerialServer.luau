-- Gives pulled cards their serials (docs/specs/serials.md). A pulled card is usable at once; every few seconds
-- this asks the shared counter once for all the numbers this server's players are waiting on and writes them into
-- their saves. Asking on every pull would break Roblox's data store limits.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CardCore = ReplicatedStorage:WaitForChild("CardCore")
local Inventory = require(CardCore.Inventory)
local SerialBatch = require(CardCore.SerialBatch)
local PlayerCards = require(script.Parent.PlayerCards)
local SerialCounter = require(script.Parent.SerialCounter)

local ROUND_SECONDS = 5

-- Each player's pulls that haven't been told their serials yet, for the pull reveal.
local queues: { [Player]: any } = {}

local SerialServer = {}

-- Call after a pack is opened one at a time, so the reveal can show each card's own serial when it arrives.
function SerialServer.pulled(player: Player, openId: number, cards: { any })
	local queue = queues[player]
	if not queue then
		queue = SerialBatch.queue()
		queues[player] = queue
	end
	for slot, card in cards do
		queue:push(Inventory.key(card.cardId, card.tier, card.variant), openId, slot)
	end
end

local function round(announce: (Player, any) -> ())
	local players, wants, pulls = {}, {}, {}
	for _, player in PlayerCards.loaded() do
		local data = PlayerCards.get(player)
		local want = data and SerialBatch.wanted(data)
		if want and next(want) then
			table.insert(players, player)
			table.insert(wants, want)
			-- Pulls made while the counter is being asked belong to the next round, with their copies.
			pulls[player] = queues[player]
			queues[player] = nil
		end
	end
	if #players == 0 then
		return
	end

	local firsts = SerialCounter.reserve(SerialBatch.total(wants)) -- yields
	if not firsts then
		-- Nothing was taken and no save has changed. The copies are still waiting, so the next round asks again.
		-- The reveals that were waiting show no number; the cards get theirs later all the same.
		return
	end

	local nextFirst = table.clone(firsts)
	for index, player in players do
		-- A player can leave, fuse or sell while the counter is asked. Whatever they no longer hold is skipped:
		-- a number may go unused, but it is never given twice.
		local data = PlayerCards.get(player)
		local told: { [number]: { any } } = {}
		for key, share in wants[index] do
			local first = nextFirst[key]
			nextFirst[key] = first + share
			if data then
				local used, from, to = SerialBatch.apply(data, key, first, share)
				if used > 0 and pulls[player] then
					for _, given in pulls[player]:assign(key, from :: number, to :: number) do
						told[given.openId] = told[given.openId] or {}
						table.insert(told[given.openId], { slot = given.slot, serial = given.serial })
					end
				end
			end
		end
		if data then
			PlayerCards.changed(player)
			for openId, serials in told do
				announce(player, { kind = "Serials", openId = openId, serials = serials })
			end
		end
	end
end

-- `announce` sends a pack event to a player (PackServer.announce).
function SerialServer.start(announce: (Player, any) -> ())
	Players.PlayerRemoving:Connect(function(player: Player)
		queues[player] = nil
	end)
	task.spawn(function()
		while true do
			task.wait(ROUND_SECONDS)
			-- One round at a time, and a failed round must not stop the next.
			local ok, problem = pcall(round, announce)
			if not ok then
				warn(`[CardCore] serial round failed: {problem}`)
			end
		end
	end)
end

return SerialServer
