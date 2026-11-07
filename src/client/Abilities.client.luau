-- Client side of ability cards: a card's key pulls it out, a click uses it, and this shows what the server reveals.
local Palette = require(game:GetService("ReplicatedStorage"):WaitForChild("Guns"):WaitForChild("Palette"))
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local CardHand = require(ReplicatedStorage:WaitForChild("CardCore"):WaitForChild("CardHand"))
local Zones = require(ReplicatedStorage:WaitForChild("Guns"):WaitForChild("Zones"))
local CardInHand = require(script.Parent.CardInHand)
local Input = require(script.Parent.Input)

local remotes = ReplicatedStorage:WaitForChild("AbilityRemotes")
local useRemote = remotes:WaitForChild("Use") :: RemoteEvent
local testDeckRemote = remotes:WaitForChild("TestDeck") :: RemoteEvent
local revealRemote = remotes:WaitForChild("Reveal") :: RemoteEvent

local REVEAL_COLOR = Palette.HazardRed

local player = Players.LocalPlayer
local previous: { [string]: boolean } = {}

local function isReady(index: number): boolean
	local readyAt = player:GetAttribute(`Ability{index}ReadyAt`)
	return player:GetAttribute(`Ability{index}Id`) ~= nil
		and readyAt ~= nil
		and readyAt <= workspace:GetServerTimeNow()
end

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
	if not Zones.allowsCombat(Zones.of(player)) then
		CardHand.putAway(CardInHand)
	else
		for index = 1, 3 do
			local key = `slot{index}`
			if keys[key] and not previous[key] then
				CardHand.press(CardInHand, index, isReady(index))
			end
		end
		if keys.use and not previous.use then
			local used = CardHand.click(CardInHand)
			if used then
				useRemote:FireServer(used)
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
