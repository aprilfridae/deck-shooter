-- Client side of ability cards: the first card key pulls the cards out, the aim key turns to the next one, a click
-- uses it, and this draws the thrown card, bolt and blast the server reports.
local Palette = require(game:GetService("ReplicatedStorage"):WaitForChild("Guns"):WaitForChild("Palette"))
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local CardHand = require(ReplicatedStorage:WaitForChild("CardCore"):WaitForChild("CardHand"))
local Zones = require(ReplicatedStorage:WaitForChild("Guns"):WaitForChild("Zones"))
local CardInHand = require(script.Parent.CardInHand)
local CardThrowFx = require(script.Parent.CardThrowFx)
local Input = require(script.Parent.Input)

local remotes = ReplicatedStorage:WaitForChild("AbilityRemotes")
local useRemote = remotes:WaitForChild("Use") :: RemoteEvent
local testDeckRemote = remotes:WaitForChild("TestDeck") :: RemoteEvent
local fxRemote = remotes:WaitForChild("Fx") :: RemoteEvent

-- What the aimed cards draw. Simple shapes to start: River adds sounds and proper effects later.
local FX_SECONDS = 0.35
local LINE_WIDTH = 0.25
local BOLT_SIZE = 1.2
local BLAST_START, BLAST_END = 2, 16 -- studs across
local FX_COLORS = { bolt = Palette.HazardRed, blast = Palette.Bone }

local player = Players.LocalPlayer
local previous: { [string]: boolean } = {}

local function isReady(index: number): boolean
	local readyAt = player:GetAttribute(`Ability{index}ReadyAt`)
	return player:GetAttribute(`Ability{index}Id`) ~= nil
		and readyAt ~= nil
		and readyAt <= workspace:GetServerTimeNow()
end

local function glow(color: Color3): Part
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Material = Enum.Material.Neon
	part.Color = color
	return part
end

local function fade(part: Part, goal: { [string]: any })
	goal.Transparency = 1
	TweenService:Create(part, TweenInfo.new(FX_SECONDS, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), goal):Play()
	Debris:AddItem(part, FX_SECONDS + 0.1)
end

fxRemote.OnClientEvent:Connect(function(kind: any, from: any, to: any, hit: any, tier: any)
	if typeof(from) ~= "Vector3" or typeof(to) ~= "Vector3" then
		return
	end
	if kind == "card" then
		CardThrowFx.throw(from, to, hit == true, tier)
		return
	end
	local color = FX_COLORS[kind]
	if not color then
		return
	end
	local length = (to - from).Magnitude
	if kind == "blast" then
		-- A ring lying on the surface, widening. `to` is one stud out along the surface's normal.
		local ring = glow(color)
		ring.Shape = Enum.PartType.Cylinder
		ring.Size = Vector3.new(0.2, BLAST_START, BLAST_START)
		ring.CFrame = CFrame.lookAt(from, to) * CFrame.Angles(0, math.rad(90), 0)
		ring.Transparency = 0.3
		ring.Parent = workspace
		fade(ring, { Size = Vector3.new(0.2, BLAST_END, BLAST_END) })
	elseif length > 0.1 then
		local line = glow(color)
		line.Size = Vector3.new(LINE_WIDTH, LINE_WIDTH, length)
		line.CFrame = CFrame.lookAt(from, to) * CFrame.new(0, 0, -length / 2)
		line.Parent = workspace
		fade(line, { Size = Vector3.new(0.02, 0.02, length) })
		if kind == "bolt" then
			local head = glow(color)
			head.Shape = Enum.PartType.Ball
			head.Size = Vector3.one * BOLT_SIZE
			head.Position = from
			head.Parent = workspace
			fade(head, { Position = to })
		end
	end
end)

RunService.Heartbeat:Connect(function()
	local keys = Input.readAbility()
	if not Zones.allowsCombat(Zones.of(player)) then
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
