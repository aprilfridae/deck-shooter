-- Makes the Outpost's lights flicker subtly while you're there (Flicker has the shape of it), and the Hex map's
-- lamps and monitor glow too. A light with a FlickerDepth attribute flickers that many times harder. Each light and its
-- glowing bulb dim together. Runs a few times a second, not every frame, and not at all elsewhere.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Guns = ReplicatedStorage:WaitForChild("Guns")
local Flicker = require(Guns:WaitForChild("Flicker"))
local Zones = require(Guns:WaitForChild("Zones"))

local UPDATE_EVERY = 1 / 20
local BULB_FADE = 0.5 -- how much of a dip shows on the bulb itself

type Lamp = { light: Light, full: number, bulb: BasePart?, bulbFull: number, seed: number, depth: number }

local player = Players.LocalPlayer
local byZone: { [string]: { Lamp } } = {}

local function gather(folder: Instance): { Lamp }
	local lamps = {}
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
				depth = item:GetAttribute("FlickerDepth") or 1,
			})
		end
	end
	return lamps
end

for zone, name in { [Zones.Outpost] = "Outpost", [Zones.Hex] = "Hex" } do
	task.spawn(function()
		local folder = workspace:WaitForChild(name, 60)
		if folder then
			byZone[zone] = gather(folder)
		end
	end)
end

local waited = 0
RunService.Heartbeat:Connect(function(dt)
	waited += dt
	if waited < UPDATE_EVERY then
		return
	end
	waited = 0
	local lamps = byZone[Zones.of(player)]
	if not lamps then
		return
	end
	local now = os.clock()
	for _, lamp in lamps do
		local share = math.max(0, 1 - (1 - Flicker.at(lamp.seed, now)) * lamp.depth)
		lamp.light.Brightness = lamp.full * share
		if lamp.bulb then
			lamp.bulb.Transparency = lamp.bulbFull + (1 - lamp.bulbFull) * (1 - share) * BULB_FADE
		end
	end
end)
