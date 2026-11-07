-- Server entry point: remotes and the income loop. Game rules live in ReplicatedStorage.CardCore.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CardCore = ReplicatedStorage:WaitForChild("CardCore")
local Comments = require(CardCore.Comments)
local Deck = require(CardCore.Deck)
local Dpr = require(CardCore.Dpr)
local Fusion = require(CardCore.Fusion)
local Income = require(CardCore.Income)
local Requests = require(CardCore.Requests)
local Settings = require(CardCore.Settings)
local PackServer = require(script.Parent.PackServer)
local PlayerCards = require(script.Parent.PlayerCards)
local ProfileComments = require(script.Parent.ProfileComments)

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
	return { ok = true, result = PlayerCards.snapshot(player) }
end)

remote("GetProfile", function(_, _, raw)
	local userId = Requests.parseUserId(raw)
	local target = userId and Players:GetPlayerByUserId(userId)
	local data = target and PlayerCards.get(target)
	if not target or not data then
		return { ok = false, code = "NotHere" }
	end
	return {
		ok = true,
		result = {
			userId = target.UserId,
			name = target.Name,
			credits = data.credits,
			dpr = Dpr.compute(data.deck, data.gunLevels),
			stacks = data.stacks,
			commentsOff = data.commentsOff,
		},
	}
end)

remote("GetComments", function(player, _, raw)
	local userId = Requests.parseUserId(raw)
	local target = userId and Players:GetPlayerByUserId(userId)
	if not target then
		return { ok = false, code = "NotHere" }
	end
	local comments = ProfileComments.view(player, target.UserId)
	if not comments then
		return { ok = false, code = "StoreFailed" }
	end
	return { ok = true, result = comments }
end)

remote("PostComment", function(player, _, raw)
	local request = Requests.parseComment(raw)
	if not request then
		return { ok = false, code = "BadRequest" }
	end
	local owner = Players:GetPlayerByUserId(request.owner)
	local ownerData = owner and PlayerCards.get(owner)
	if not ownerData then
		return { ok = false, code = "NotHere" }
	end
	local ok, code = ProfileComments.post(player, request.owner, request.text, ownerData.commentsOff)
	return { ok = ok, code = code }
end)

remote("DeleteComment", function(player, _, raw)
	local request = Requests.parseCommentTarget(raw)
	if not request or request.owner ~= player.UserId then
		return { ok = false, code = "BadRequest" }
	end
	return { ok = ProfileComments.delete(request.owner, request.author), code = "StoreFailed" }
end)

remote("ReportComment", function(player, _, raw)
	local request = Requests.parseCommentTarget(raw)
	if not request then
		return { ok = false, code = "BadRequest" }
	end
	return { ok = ProfileComments.report(player, request.owner, request.author), code = "StoreFailed" }
end)

remote("SetCommentsOff", function(_, data, raw)
	data.commentsOff = raw == true
	return { ok = true }
end)

remote("GetSettings", function(_, data)
	return { ok = true, result = data.settings }
end)

remote("SetSettings", function(_, data, raw)
	data.settings = Settings.clean(raw)
	return { ok = true }
end)

remote("GetSnapshot", function(player)
	return { ok = true, result = PlayerCards.snapshot(player) }
end)

Players.PlayerRemoving:Connect(function(player)
	requestWindows[player] = nil
end)

PackServer.start(remote, rng)
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
