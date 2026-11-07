-- How the cards move. Everything repeats, so each takes the time since the card appeared.
local PanelMotion = require("./PanelMotion")

local CardMotion = {
	SHINE_TIME = 2.6, -- seconds
	PULSE_TIME = 1.8,
	PING_TIME = 2,
	SCRAMBLE_TIME = 2.4,
}

local SHINE_SHARE = 0.55 -- of its time the shine spends crossing the card
local PULSE_GROWTH = 0.14
local PULSE_START = 0.3 -- transparency
local PING_FROM = 7 -- card units
local PING_TO = 30
local PING_START = 0.1 -- transparency
local SCRAMBLE_FOR = 0.8 -- seconds of each repeat

local function share(elapsed: number, time: number): number
	return (elapsed % time) / time
end

-- The shine's gradient offset, from -1 to 1. It waits off the card between sweeps.
function CardMotion.shineOffset(elapsed: number): number
	return math.min(share(elapsed, CardMotion.SHINE_TIME) / SHINE_SHARE, 1) * 2 - 1
end

-- The outline's scale and transparency.
function CardMotion.pulse(elapsed: number): (number, number)
	local progress = share(elapsed, CardMotion.PULSE_TIME)
	return 1 + PULSE_GROWTH * progress, PULSE_START + (1 - PULSE_START) * progress
end

-- The ring's radius in card units, and its transparency.
function CardMotion.ping(elapsed: number): (number, number)
	local progress = share(elapsed, CardMotion.PING_TIME)
	return PING_FROM + (PING_TO - PING_FROM) * progress, PING_START + (1 - PING_START) * progress
end

-- The serial as it stands: noise that settles digit by digit, then the serial itself.
function CardMotion.scramble(serial: string, elapsed: number): string
	local time = elapsed % CardMotion.SCRAMBLE_TIME
	if time >= SCRAMBLE_FOR then
		return serial
	end
	local frame = math.floor(time * PanelMotion.DECODE_FPS + 1e-6)
	local settled = math.floor(time / SCRAMBLE_FOR * (#serial + 1))
	local shown = string.sub(serial, 1, settled)
	for index = settled + 1, #serial do
		shown ..= PanelMotion.noise(index, frame)
	end
	return shown
end

return CardMotion
