-- The player's settings on the client. Changes apply at once, and reach the save at most once a second.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Settings = require(ReplicatedStorage:WaitForChild("CardCore"):WaitForChild("Settings"))

local SEND_EVERY = 1 -- seconds
local LOAD_RETRY = 1 -- seconds

local changedEvent = Instance.new("BindableEvent")

local current = Settings.new()
local loaded = false
local early: { [string]: any } = {} -- changes made before the save arrived
local lastSent = -SEND_EVERY
local queued = false

local PlayerSettings = {
	changed = changedEvent.Event,
}

-- Looked up when needed, so requiring this module never waits for the server.
local function remote(name: string): RemoteFunction
	return ReplicatedStorage:WaitForChild("CardCoreRemotes"):WaitForChild(name)
end

function PlayerSettings.get(): Settings.Settings
	return current
end

function PlayerSettings.set(change: { [string]: any })
	for field, value in change do
		current[field] = value
		if not loaded then
			early[field] = value
		end
	end
	changedEvent:Fire()
end

local function push()
	queued = false
	lastSent = os.clock()
	task.spawn(function()
		local sent, reply = pcall(function()
			return remote("SetSettings"):InvokeServer(current)
		end)
		if not (sent and reply.ok) then
			PlayerSettings.send()
		end
	end)
end

function PlayerSettings.send()
	if queued or not loaded then -- changes made before the save arrives go out when it does
		return
	end
	local wait = lastSent + SEND_EVERY - os.clock()
	if wait <= 0 then
		push()
	else
		queued = true
		task.delay(wait, push)
	end
end

task.spawn(function()
	while true do
		local reply = remote("GetSettings"):InvokeServer()
		if reply.ok then
			loaded = true
			current = Settings.merge(Settings.clean(reply.result), early)
			changedEvent:Fire()
			if next(early) then
				PlayerSettings.send()
			end
			return
		end
		task.wait(LOAD_RETRY)
	end
end)

return PlayerSettings
