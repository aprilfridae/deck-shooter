-- Makes the Outpost's lights flicker subtly while you're there (Flicker has the shape of it). Each light and its
-- glowing bulb dim together. Runs a few times a second, not every frame, and not at all elsewhere.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Guns = ReplicatedStorage:WaitForChild("Guns")
local Flicker = require(Guns:WaitForChild("Flicker"))
local Zones = require(Guns:WaitForChild("Zones"))

local UPDATE_EVERY = 1 / 20
local BULB_FADE = 0.5 -- how much of a dip shows on the bulb itself

type Lamp = { light: Light, full: number, bulb: BasePart?, bulbFull: number, seed: number }

local player = Players.LocalPlayer
local lamps: { Lamp } = {}

local function gather(folder: Instance)
	table.clear(lamps)
	for _, item in folder:GetDescendants() do
		if item:IsA("Light") then
			local parent = item.Parent
			local bulb = if parent and parent:IsA("BasePart") and parent.Material == Enum.Material.Neon then parent else nil
			table.insert(lamps, {
				light = item,
				full = item.Brightness,
				bulb = bulb,
				bulbFull = if bulb then bulb.Transparency else 0,
				seed = #lamps + 1,
			})
		end
	end
end

local outpost = workspace:WaitForChild("Outpost", 60)
if not outpost then
	return
end
gather(outpost)

local waited = 0
RunService.Heartbeat:Connect(function(dt)
	waited += dt
	if waited < UPDATE_EVERY then
		return
	end
	waited = 0
	if Zones.of(player) ~= Zones.Outpost then
		return
	end
	local now = os.clock()
	for _, lamp in lamps do
		local share = Flicker.at(lamp.seed, now)
		lamp.light.Brightness = lamp.full * share
		if lamp.bulb then
			lamp.bulb.Transparency = lamp.bulbFull + (1 - lamp.bulbFull) * (1 - share) * BULB_FADE
		end
	end
end)
