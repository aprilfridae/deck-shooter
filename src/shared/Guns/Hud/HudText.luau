-- The words and numbers the HUD shows.
local HudText = {}

local FIRST_KEY = 3
local BASE_HEIGHT = 720
local MIN_SCALE = 0.75
local MAX_SCALE = 2

function HudText.health(value: number?): string
	return tostring(math.ceil(value or 0))
end

function HudText.shield(value: number?): string
	if not value or value <= 0 then
		return ""
	end
	return `+{math.ceil(value)}`
end

function HudText.ammo(value: number?): string
	return if value then tostring(value) else ""
end

function HudText.gunLabel(name: string, mag: number, reloading: boolean): string
	return if reloading then "RELOADING" else `{name}  /  {mag}`
end

-- label is the key the player has bound, if there is one to show.
function HudText.key(slot: number, label: string?): string
	return label or tostring(slot + FIRST_KEY - 1)
end

-- A picked card glitching out of the spread and back in on top. share is how far through it is. Returns whether the
-- card shows, how far it has jumped sideways (-1 to 1), and whether it has gone over the others yet, which it does
-- while it's gone.
export type Glitch = {
	there: boolean, -- whether the card itself shows
	shift: number, -- how far it has jumped sideways, -1 to 1
	over: boolean, -- whether it has gone over the others yet
	split: number, -- how far its coloured ghosts have pulled apart, 0 to 1
	scale: number, -- its size
	flash: number, -- how strongly it's lit, 0 to 1
	step: number, -- which beat of static it's on, or -1 when it's still
}
local GLITCH_STEPS = 18
local GLITCH_OUT = { true, false, true, true, false, true, false, true }
local GLITCH_BLIP = 11 -- the beat it drops out for once more after landing

-- Static: the same -1 to 1 for the same n, and nothing alike for the next.
function HudText.noise(n: number): number
	return (math.sin(n * 12.9898) * 43758.5453) % 2 - 1
end

-- First half: it breaks up, flickering and shaking harder as its ghosts pull apart, then is gone. Second half: it
-- snaps back in on top, a little too big and lit, and settles.
function HudText.glitch(share: number): Glitch
	if share >= 1 or share < 0 then
		return { there = true, shift = 0, over = share >= 1, split = 0, scale = 1, flash = 0, step = -1 }
	end
	local step = math.floor(share * GLITCH_STEPS)
	local jump = HudText.noise(step + 1)
	if share < 0.5 then
		local out = share / 0.5
		return {
			there = out < 0.8 and GLITCH_OUT[step % #GLITCH_OUT + 1],
			shift = jump * (0.4 + 0.6 * out),
			over = false,
			split = out,
			scale = 1 - 0.06 * out,
			flash = 0.4,
			step = step,
		}
	end
	local back = (share - 0.5) / 0.5
	local settle = (1 - back) ^ 3
	return {
		there = step ~= GLITCH_BLIP,
		shift = jump * settle,
		over = true,
		split = settle,
		scale = 1 + 0.2 * settle,
		flash = 0.85 * (1 - back) ^ 2,
		step = step,
	}
end

-- How much of a card's colour is back, from 0 to 1, with left seconds of the cooldown to go.
function HudText.colour(left: number, cooldown: number): number
	if cooldown <= 0 then
		return 1
	end
	return 1 - math.clamp(left / cooldown, 0, 1)
end

-- The HUD's size for a screen this tall.
function HudText.scale(height: number): number
	return math.clamp(height / BASE_HEIGHT, MIN_SCALE, MAX_SCALE)
end

return HudText
