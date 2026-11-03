-- Server entry point: remotes and the income loop. Game rules live in ReplicatedStorage.CardCore.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CardCore = ReplicatedStorage:WaitForChild("CardCore")
local Deck = require(CardCore.Deck)
local Fusion = require(CardCore.Fusion)
local Income = require(CardCore.Income)
local Requests = require(CardCore.Requests)
local PlayerCards = require(script.Parent.PlayerCards)

local MAX_REQUESTS_PER_SECOND = 5
local SNAPSHOT_EVERY_SECONDS = 5

local random = Random.new()
local function rng(): number
	return random:NextNumber()
end

local requestWindows: { [Player]: { startedAt: number, count: number } } = {}

local function allowRequest(player: Player): boolean
	local now = os.clock()
	local window = requestWindows[player]
	if not window or now - window.startedAt >= 1 then
		requestWindows[player] = { startedAt = now, count = 1 }
		return true
	end
	window.count += 1
	return window.count <= MAX_REQUESTS_PER_SECOND
end

-- Wraps a request handler with the rate limit and the loaded-data check.
local function remote(name: string, handler: (Player, any, any) -> any)
	local fn = Instance.new("RemoteFunction")
	fn.Name = name
	fn.OnServerInvoke = function(player: Player, raw: any)
		if not allowRequest(player) then
			return { ok = false, code = "RateLimited" }
		end
		local data = PlayerCards.get(player)
		if not data then
			return { ok = false, code = "NotLoaded" }
		end
		return handler(player, data, raw)
	end
	fn.Parent = PlayerCards.remotes
end

remote("Fuse", function(player, data, raw)
	local request = Requests.parseFuse(raw)
	if not request then
		return { ok = false, code = "BadRequest" }
	end
	local ok, outcome = Fusion.fuse(data, request, rng)
	if not ok then
		return { ok = false, code = outcome }
	end
	PlayerCards.changed(player)
	return { ok = true, result = outcome }
end)

remote("SetDeck", function(player, data, raw)
	local slots = Requests.parseDeck(raw)
	if not slots then
		return { ok = false, code = "BadRequest" }
	end
	local ok, code = Deck.set(data, slots)
	if not ok then
		return { ok = false, code = code }
	end
	PlayerCards.changed(player)
	return { ok = true }
end)

remote("GetSnapshot", function(player)
	return { ok = true, result = PlayerCards.snapshot(player) }
end)

Players.PlayerRemoving:Connect(function(player)
	requestWindows[player] = nil
end)

PlayerCards.start()

task.spawn(function()
	local sinceSnapshot = 0
	while true do
		local dt = task.wait(1)
		sinceSnapshot += dt
		local pushSnapshot = sinceSnapshot >= SNAPSHOT_EVERY_SECONDS
		if pushSnapshot then
			sinceSnapshot = 0
		end
		for _, player in PlayerCards.loaded() do
			local data = PlayerCards.get(player)
			if data then
				Income.accrue(data, dt)
				if pushSnapshot then
					PlayerCards.changed(player)
				end
			end
		end
	end
end)
