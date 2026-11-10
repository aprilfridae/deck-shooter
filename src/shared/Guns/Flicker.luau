-- A subtle flicker for the Outpost's lights: how bright a light is, as a share of its full brightness, at time t.
-- Each light has its own seed, so they don't pulse together. Most of the time it's a faint shimmer; now and
-- then one dips for a moment, like a tired tube.
local Flicker = {}

Flicker.SHIMMER = 0.05 -- the most the steady shimmer takes off
Flicker.DIP = 0.35 -- the most a dip takes off
local DIP_SLOT = 0.12 -- seconds; a dip lasts one slot
local DIP_CHANCE = 0.012 -- per slot, per light: a few seconds apart in a hall full of lamps

-- A number from 0 to 1 that's the same every time for the same two numbers.
local function hash(a: number, b: number): number
	local x = math.sin(a * 127.1 + b * 311.7) * 43758.5453
	return x - math.floor(x)
end

function Flicker.at(seed: number, t: number): number
	local shimmer = (math.sin(t * 7.3 + seed * 1.7) + math.sin(t * 13.1 + seed * 4.3) + 2) / 4 -- 0 to 1
	local brightness = 1 - Flicker.SHIMMER * shimmer
	local slot = math.floor(t / DIP_SLOT)
	if hash(seed, slot) < DIP_CHANCE then
		-- Down and back up within the slot.
		local through = t / DIP_SLOT - slot
		brightness -= Flicker.DIP * math.sin(through * math.pi) * (0.5 + hash(slot, seed) * 0.5)
	end
	return brightness
end

return Flicker
