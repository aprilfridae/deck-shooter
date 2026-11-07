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

-- How many cooldown segments are lit, with left seconds of the cooldown to go.
function HudText.filled(left: number, cooldown: number, segments: number): number
	if cooldown <= 0 then
		return segments
	end
	local share = 1 - math.clamp(left / cooldown, 0, 1)
	return math.floor(share * segments)
end

-- The HUD's size for a screen this tall.
function HudText.scale(height: number): number
	return math.clamp(height / BASE_HEIGHT, MIN_SCALE, MAX_SCALE)
end

return HudText
