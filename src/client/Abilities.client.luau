-- Client side of ability cards: sends key presses and shows what the server reveals.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Input = require(script.Parent.Input)

local remotes = ReplicatedStorage:WaitForChild("AbilityRemotes")
local useRemote = remotes:WaitForChild("Use") :: RemoteEvent
local testDeckRemote = remotes:WaitForChild("TestDeck") :: RemoteEvent
local revealRemote = remotes:WaitForChild("Reveal") :: RemoteEvent

local REVEAL_COLOR = Color3.fromRGB(255, 70, 60)

local player = Players.LocalPlayer
local previous: { [string]: boolean } = {}

revealRemote.OnClientEvent:Connect(function(models: { Model }, seconds: number)
	for _, model in models do
		local highlight = Instance.new("Highlight")
		highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
		highlight.FillColor = REVEAL_COLOR
		highlight.OutlineColor = REVEAL_COLOR
		highlight.Parent = model
		task.delay(seconds, highlight.Destroy, highlight)
	end
end)

RunService.Heartbeat:Connect(function()
	local keys = Input.readAbility()
	if not player:GetAttribute("Climbing") then
		for index = 1, 3 do
			local key = `slot{index}`
			if keys[key] and not previous[key] then
				useRemote:FireServer(index)
			end
		end
	end
	if keys.testDeck and not previous.testDeck then
		testDeckRemote:FireServer("deck")
	end
	if keys.testTier and not previous.testTier then
		testDeckRemote:FireServer("tier")
	end
	previous = keys
end)
