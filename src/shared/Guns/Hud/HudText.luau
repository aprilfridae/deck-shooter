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
local GLITCH = { true, false, true, true, false, false, false, false, true, false, true, true }
function HudText.glitch(share: number): (boolean, number, boolean)
	if share >= 1 or share < 0 then
		return true, 0, share >= 1
	end
	local step = math.floor(share * #GLITCH)
	local jump = (math.sin((step + 1) * 12.9898) * 43758.5453) % 2 - 1
	return GLITCH[step + 1], if jump == 0 then 0.5 else jump, share >= 0.5
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
