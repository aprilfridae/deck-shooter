-- How the cards move. Everything repeats, so each takes the time since the card appeared.
local CardMotion = {
	SHINE_TIME = 2.6, -- seconds
	PING_TIME = 2,
}

local SHINE_SHARE = 0.55 -- of its time the shine spends crossing the card
local PING_FROM = 7 -- card units
local PING_TO = 30
local PING_START = 0.1 -- transparency

local BREATHE_SHRINK = 0.22
local BREATHE_FADE = 0.45
local SWEEP_TIME = 5
local SWEEP_SHARE = 0.4 -- of its time the red band spends crossing the card
local FLICKER_TIME = 3.2
local EMBER_RISE = 900
local EMBER_FADE_IN = 0.15 -- of its life
local MARK_SHOWN = 0.6 -- of each blink
local MEASURE_TIME = 5
local GRID_TIME = 4
local TWINKLE_SIZE = 154 -- the small sparkle's own size
local FOIL_TIME = 6
local RAINBOW_TIME = 2.6
local GLOW_TIME = 1.6
local GLOW_DIM = 0.25
local LOOP_SLACK = 1e-4 -- gradient points closer than this to an end are dropped

local function share(elapsed: number, time: number): number
	return (elapsed % time) / time
end

-- The shine's gradient offset, from -1 to 1. It waits off the card between sweeps.
function CardMotion.shineOffset(elapsed: number): number
	return math.min(share(elapsed, CardMotion.SHINE_TIME) / SHINE_SHARE, 1) * 2 - 1
end

-- The ring's radius in card units, and its transparency.
function CardMotion.ping(elapsed: number): (number, number)
	local progress = share(elapsed, CardMotion.PING_TIME)
	return PING_FROM + (PING_TO - PING_FROM) * progress, PING_START + (1 - PING_START) * progress
end

-- The rest is the new card face (docs/specs/card-face-redesign.md). Positions and sizes are in the units of
-- River's drawing, 1280 by 2048. Particles are worked out from their index alone, so every card of a rarity
-- looks alive without anything random to keep track of. The timings are the mockups' and are River's to tune.

-- A slow shrink and fade and back: scale and transparency. `offset` starts it that many seconds in.
function CardMotion.breathe(elapsed: number, period: number, offset: number): (number, number)
	local dip = (1 - math.cos(share(elapsed + offset, period) * 2 * math.pi)) / 2
	return 1 - BREATHE_SHRINK * dip, BREATHE_FADE * dip
end

-- Where a dot is on its ring, as the cosine and sine of its angle. It starts at the ring's left end.
function CardMotion.orbit(elapsed: number, period: number, direction: number): (number, number)
	local angle = math.pi + direction * 2 * math.pi * elapsed / period
	return math.cos(angle), math.sin(angle)
end

-- Redline's red band: its gradient offset, from -1 to 1, waiting off the card between sweeps.
function CardMotion.sweepDown(elapsed: number): number
	return math.min(share(elapsed, SWEEP_TIME) / SWEEP_SHARE, 1) * 2 - 1
end

-- Redline's acronym, flickering like a bad light: its transparency.
function CardMotion.flicker(elapsed: number): number
	local progress = share(elapsed, FLICKER_TIME)
	if progress >= 0.45 and progress < 0.48 then
		return 0.3
	elseif progress >= 0.7 and progress < 0.73 then
		return 0.15
	end
	return 0
end

-- One of Redline's embers: x, y, size and transparency.
function CardMotion.ember(index: number, elapsed: number): (number, number, number, number)
	local progress = share(elapsed + index * 0.41, 2.6 + (index % 4) * 0.7)
	local clear = if progress < EMBER_FADE_IN then 1 - progress / EMBER_FADE_IN else (progress - EMBER_FADE_IN) / (1 - EMBER_FADE_IN)
	return 45 + (index * 173) % 1180, 1780 + (index * 97) % 240 - EMBER_RISE * progress, 8 + (index % 3) * 6, clear
end

-- One of Prototype's plus marks: x, y and whether it's showing.
function CardMotion.mark(index: number, elapsed: number): (number, number, boolean)
	local progress = share(elapsed + index * 0.33, 1.4 + (index % 5) * 0.5)
	return 90 + (index * 311) % 1100, 120 + (index * 587) % 1560, progress < MARK_SHOWN
end

-- Prototype's measuring line: how much of it is drawn, and its transparency.
function CardMotion.measure(elapsed: number): (number, number)
	local progress = share(elapsed, MEASURE_TIME)
	local clear = math.clamp((progress - 0.8) / 0.15, 0, 1)
	return math.min(progress / 0.35, 1), clear
end

-- How far Prototype's grid has slid, as a share of one tile.
function CardMotion.gridShift(elapsed: number): number
	return share(elapsed, GRID_TIME)
end

-- One of Zero-Day's twinkles: x, y and size.
function CardMotion.twinkle(index: number, elapsed: number): (number, number, number)
	local progress = share(elapsed + index * 0.53, 2.2 + (index % 4) * 0.6)
	local size = TWINKLE_SIZE * (0.28 + (index % 3) * 0.14) * math.sin(math.pi * progress)
	return 110 + (index * 397) % 1060, 180 + (index * 613) % 1500, math.max(size, 0)
end

-- How far the foil colours on Zero-Day's sparkles have slid, from 0 to 1.
function CardMotion.foilShift(elapsed: number): number
	return share(elapsed, FOIL_TIME)
end

-- How far the rainbow on a low serial has slid, from 0 to 1.
function CardMotion.rainbowShift(elapsed: number): number
	return share(elapsed, RAINBOW_TIME)
end

-- A ring of `count` evenly spaced colours, turned by `phase` (0 to 1 is once round), as the points of a gradient:
-- each has its time along the gradient and the two colours it sits between. Sliding a gradient's offset instead
-- clamps at its ends, which reads as a wipe; turning the colours themselves has no seam.
function CardMotion.loop(count: number, phase: number): { { time: number, from: number, to: number, mix: number } }
	local points = {}
	local start = (phase % 1) * count
	local function at(time: number, position: number)
		local whole = math.floor(position + LOOP_SLACK)
		local from = whole % count + 1
		table.insert(points, { time = time, from = from, to = from % count + 1, mix = math.clamp(position - whole, 0, 1) })
	end
	at(0, start)
	for step = math.floor(start) + 1, math.ceil(start + count) - 1 do
		local time = (step - start) / count
		if time > LOOP_SLACK and time < 1 - LOOP_SLACK then
			at(time, step)
		end
	end
	at(1, start + count)
	return points
end

-- The transparency of a low serial's glow.
function CardMotion.glow(elapsed: number): number
	return GLOW_DIM * (1 + math.cos(share(elapsed, GLOW_TIME) * 2 * math.pi)) / 2
end

return CardMotion
