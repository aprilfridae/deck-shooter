-- The player's cards on the client, kept up to date from the server.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RETRY = 1 -- seconds
local GIVE_UP = 15 -- seconds to wait for the server before a request fails

local changedEvent = Instance.new("BindableEvent")
local packEvent = Instance.new("BindableEvent")
local current: any? = nil
local deckWaiting = false -- a new deck hasn't reached the abilities yet

local CardData = {
	changed = changedEvent.Event,
	packEvent = packEvent.Event, -- a pack rolled or opened
}

-- Looked up when needed, so requiring this module never waits for the server.
local function remotes(): Instance
	return ReplicatedStorage:WaitForChild("CardCoreRemotes")
end

local function store(snapshot: any)
	current = snapshot
	changedEvent:Fire()
end

function CardData.get(): any?
	return current
end

function CardData.deckWaiting(): boolean
	return deckWaiting
end

-- Sends a remote and returns its reply. Waits for the server, so call it off the main path.
function CardData.ask(name: string, request: any?): any
	local ok, reply = pcall(function()
		local folder = ReplicatedStorage:WaitForChild("CardCoreRemotes", GIVE_UP)
		return folder:WaitForChild(name, GIVE_UP):InvokeServer(request)
	end)
	return if ok then reply else { ok = false, code = "NoReply" }
end

function CardData.setDeck(deck: { any }): any
	local reply = CardData.ask("SetDeck", deck)
	if reply.ok then
		deckWaiting = true
		store(reply.result)
	end
	return reply
end

Players.LocalPlayer.CharacterAdded:Connect(function()
	if deckWaiting then
		deckWaiting = false
		changedEvent:Fire()
	end
end)

task.spawn(function()
	remotes():WaitForChild("PackEvent").OnClientEvent:Connect(function(event: any)
		packEvent:Fire(event)
	end)
	remotes():WaitForChild("Snapshot").OnClientEvent:Connect(store)
	while not current do
		local reply = CardData.ask("GetSnapshot")
		if reply.ok and reply.result then
			store(reply.result)
		else
			task.wait(RETRY)
		end
	end
end)

return CardData
