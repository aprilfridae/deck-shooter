-- How the Outpost's stalls glow: dim, and when you walk up the lights waver and ease back on.
local BoothGlow = {
	LIGHT_SHARE = 0.45, -- of a light's full brightness, when fully on
	NEON_SHARE = 0.5, -- how solid the neon is when fully on
	RANGE = 22, -- studs from a stall's centre that count as walking up
	FLICKER = 1, -- seconds of wavering
	TOTAL = 3.6, -- seconds, including coming back on
	REPEAT_LOW = 7, -- seconds between flickers while you stay close
	REPEAT_HIGH = 12,
	TAG = "OutpostFlicker",
}

local FADE_DOWN = 0.4 -- seconds to sink into the wavering
local WAVES = 2.5 -- a whole number and a half, so it ends halfway up a wave
local DEEPEST = 0.85 -- how far it sinks at the bottom of a wave
local SHALLOWEST = 0.4

local function smooth(share: number): number
	local clamped = math.clamp(share, 0, 1)
	return clamped * clamped * (3 - 2 * clamped)
end

local function wavering(elapsed: number): number
	local wave = 0.5 + 0.5 * math.sin(2 * math.pi * WAVES * elapsed / BoothGlow.FLICKER)
	return 1 - smooth(elapsed / FADE_DOWN) * (DEEPEST + (SHALLOWEST - DEEPEST) * wave)
end

-- How bright the glow is this long into a flicker, from a low point up to 1.
function BoothGlow.level(elapsed: number): number
	if elapsed <= 0 or elapsed >= BoothGlow.TOTAL then
		return 1
	elseif elapsed < BoothGlow.FLICKER then
		return wavering(elapsed)
	end
	local low = wavering(BoothGlow.FLICKER)
	return low + (1 - low) * smooth((elapsed - BoothGlow.FLICKER) / (BoothGlow.TOTAL - BoothGlow.FLICKER))
end

return BoothGlow
