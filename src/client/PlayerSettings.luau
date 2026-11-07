-- The player's settings on the client. Changes apply at once, and reach the save at most once a second.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Settings = require(ReplicatedStorage:WaitForChild("CardCore"):WaitForChild("Settings"))

local SEND_EVERY = 1 -- seconds
local LOAD_RETRY = 1 -- seconds

local remotes = ReplicatedStorage:WaitForChild("CardCoreRemotes")
local getRemote = remotes:WaitForChild("GetSettings")
local setRemote = remotes:WaitForChild("SetSettings")

local changedEvent = Instance.new("BindableEvent")

local current = Settings.new()
local touched = false -- the player changed something before the save arrived
local lastSent = -SEND_EVERY
local queued = false

local PlayerSettings = {
	changed = changedEvent.Event,
}

function PlayerSettings.get(): Settings.Settings
	return current
end

function PlayerSettings.set(change: { [string]: any })
	touched = true
	for field, value in change do
		current[field] = value
	end
	changedEvent:Fire()
end

local function push()
	queued = false
	lastSent = os.clock()
	task.spawn(function()
		setRemote:InvokeServer(current)
	end)
end

function PlayerSettings.send()
	if queued then
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
		local reply = getRemote:InvokeServer()
		if reply.ok then
			if not touched then
				current = Settings.clean(reply.result)
				changedEvent:Fire()
			end
			return
		end
		task.wait(LOAD_RETRY)
	end
end)

return PlayerSettings
