-- The burst when a pack's cards turn over: two rings and a spray of wrapper shards.
-- Rarer cards burst harder. Distances are shares of the screen's height.
local Variant = require("./Variant")

local FULL_TURN = 2 * math.pi
local SHARDS = 120 -- at a power of 1
local REACH = 0.9 -- how far the fastest shard gets at a power of 1
local DRAG = 3.2 -- higher stops a shard sooner
local SLOWEST = 0.3 -- of a shard's top speed
local GRAVITY = 0.12
local LIFE = { 0.8, 1.4 } -- seconds
local SLIVER_SHARE = 0.4
local CHIP_SIZE = { 0.008, 0.016 }
local SLIVER_WIDTH = { 0.004, 0.006 }
local SLIVER_LENGTH = { 0.02, 0.036 }
local SPIN = 9 -- radians a second
local RING_REACH = 0.95 -- at a power of 1
local SMALLEST_RING = 0.5

local TIER_POWER = { Field = 0.45, BlackSite = 0.7, Prototype = 0.85 }
local VARIANT_POWER = { Base = 0, Chromatic = 0.1, Redacted = 0.15 }
local ZERO_DAY_POWER = 1.25

local PullParticles = {
	RING_TIME = 0.6, -- seconds
	RING_GAP = 0.12, -- seconds between the two rings
}

function PullParticles.power(card: any): number
	if card.variant == Variant.ZeroDay then
		return ZERO_DAY_POWER
	end
	return TIER_POWER[card.tier] + VARIANT_POWER[card.variant]
end

function PullParticles.ringReach(power: number): number
	return math.max(RING_REACH * power, SMALLEST_RING)
end

-- number(low, high) gives a random number.
function PullParticles.spawn(power: number, number: (number, number) -> number): { any }
	local topSpeed = REACH * power * DRAG
	local particles = {}
	for _ = 1, math.round(SHARDS * power) do
		local angle = number(0, FULL_TURN)
		local speed = number(SLOWEST, 1) * topSpeed
		local sliver = number(0, 1) < SLIVER_SHARE
		local chip = number(CHIP_SIZE[1], CHIP_SIZE[2])
		table.insert(particles, {
			vx = math.cos(angle) * speed,
			vy = math.sin(angle) * speed,
			life = number(LIFE[1], LIFE[2]),
			width = if sliver then number(SLIVER_WIDTH[1], SLIVER_WIDTH[2]) else chip,
			length = if sliver then number(SLIVER_LENGTH[1], SLIVER_LENGTH[2]) else chip,
			angle = number(0, FULL_TURN),
			spin = number(-SPIN, SPIN),
			first = number(0, 1) < 0.5, -- which of the pack's two colours it takes
		})
	end
	return particles
end

-- Where a shard is relative to the burst's centre. It slows to a stop as it flies.
function PullParticles.position(particle: any, elapsed: number): (number, number)
	local travelled = (1 - math.exp(-DRAG * elapsed)) / DRAG
	return particle.vx * travelled, particle.vy * travelled + GRAVITY * elapsed * elapsed / 2
end

-- 0 is solid and 1 is gone.
function PullParticles.fade(particle: any, elapsed: number): number
	return math.clamp(elapsed / particle.life, 0, 1)
end

return PullParticles
