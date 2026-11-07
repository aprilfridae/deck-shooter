-- How the Outpost's stalls glow: when you walk up, the lights waver and ease back on.
local BoothGlow = {
	LIGHT_SHARE = 0.8, -- of a light's full brightness, when fully on
	NEON_SHARE = 1, -- how solid the neon is when fully on
	RANGE = 22, -- studs from a stall's centre that count as walking up
	FADE_NEAR = 24, -- studs where a stall's lights start fading as you walk away
	FADE_FAR = 80, -- studs where they reach the floor, past the far end of the hall
	FADE_FLOOR = 0.4, -- share of a stall's light that stays on however far away you are
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

-- How much of a stall's light is left from this far away, from 1 down to the floor.
function BoothGlow.distanceFade(distance: number): number
	local share = smooth((distance - BoothGlow.FADE_NEAR) / (BoothGlow.FADE_FAR - BoothGlow.FADE_NEAR))
	return 1 - share * (1 - BoothGlow.FADE_FLOOR)
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
