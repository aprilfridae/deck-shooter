-- Client side of ability cards: the first card key pulls the cards out, the aim key turns to the next one, a click
-- uses it, and this draws the thrown card, bolt and blast the server reports.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local CardHand = require(ReplicatedStorage:WaitForChild("CardCore"):WaitForChild("CardHand"))
local AimedCardFx = require(script.Parent.AimedCardFx)
local Zones = require(ReplicatedStorage:WaitForChild("Guns"):WaitForChild("Zones"))
local CardInHand = require(script.Parent.CardInHand)
local CardThrowFx = require(script.Parent.CardThrowFx)
local FlashFx = require(script.Parent.FlashFx)
local Input = require(script.Parent.Input)
local RewindFx = require(script.Parent.RewindFx)
local SplitFx = require(script.Parent.SplitFx)

local remotes = ReplicatedStorage:WaitForChild("AbilityRemotes")
local useRemote = remotes:WaitForChild("Use") :: RemoteEvent
local testDeckRemote = remotes:WaitForChild("TestDeck") :: RemoteEvent
local fxRemote = remotes:WaitForChild("Fx") :: RemoteEvent

local player = Players.LocalPlayer
local previous: { [string]: boolean } = {}

local function isReady(index: number): boolean
	local readyAt = player:GetAttribute(`Ability{index}ReadyAt`)
	return player:GetAttribute(`Ability{index}Id`) ~= nil
		and readyAt ~= nil
		and readyAt <= workspace:GetServerTimeNow()
end

fxRemote.OnClientEvent:Connect(function(kind: any, from: any, to: any, hit: any, tier: any, thrower: any, model: any, seconds: any)
	if typeof(from) ~= "Vector3" or typeof(to) ~= "Vector3" then
		return
	end
	if kind == "bolt" then
		local body = if typeof(model) == "Instance" then model else nil
		AimedCardFx.bolt(from, to, hit == true, if type(thrower) == "number" then thrower else nil, body,
			if type(seconds) == "number" then seconds else nil)
		return
	elseif kind == "blast" then
		AimedCardFx.blast(from, to - from, tier)
		return
	elseif kind == "card" then
		if thrower == player.UserId then
			CardThrowFx.report(to, hit == true, tier) -- your own: drawn from your hand when it lets go
		else
			CardThrowFx.throw(from, to, hit == true, tier)
		end
		return
	elseif kind == "flash" then
		if thrower == player.UserId then
			FlashFx.report(to, tier)
		else
			FlashFx.throw(from, to, tier)
		end
		return
	elseif kind == "blind" then
		if type(tier) == "number" and tier > 0 then
			FlashFx.blind(from, math.min(tier, 5))
		end
		return
	elseif kind == "decoy" then
		if thrower == player.UserId then
			SplitFx.report(to, tier)
		else
			SplitFx.throw(from, to, tier)
		end
		return
	elseif kind == "rewind" then
		local who = if type(thrower) == "number" then Players:GetPlayerByUserId(thrower) else nil
		RewindFx.trail(from, to, who and who.Character, who == player)
		return
	end
	-- "vanish": KillDerez glitches the double away.
end)

RunService.Heartbeat:Connect(function()
	local keys = Input.readAbility()
	if not Zones.canFight(player) then
		CardHand.putAway(CardInHand)
	else
		local ready = { isReady(1), isReady(2), isReady(3) }
		-- Pressing the key of the card already out uses it, like a click.
		local used: number? = nil
		if keys.slot1 and not previous.slot1 then
			used = CardHand.open(CardInHand, ready)
		end
		for index = 2, 3 do -- the other two keys still go straight to their cards
			local key = `slot{index}`
			if keys[key] and not previous[key] then
				used = CardHand.press(CardInHand, index, ready[index]) or used
			end
		end
		if used then
			useRemote:FireServer(used, workspace.CurrentCamera.CFrame.LookVector)
		end
		if keys.cycle and not previous.cycle then
			CardHand.cycle(CardInHand, ready)
		end
		if keys.use and not previous.use then
			local used = CardHand.click(CardInHand)
			if used then
				-- The way you're looking goes with it, for the cards that are aimed.
				useRemote:FireServer(used, workspace.CurrentCamera.CFrame.LookVector)
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
