-- The particles for each rarity of pack opening. Distances are shares of the screen's height.
local Variant = require("./Variant")

local FULL_TURN = 2 * math.pi
local STEP_RATE = 12 -- frames a second for the styles that move in jumps

local PullParticles = {}

local STYLES = {
	Field = {
		count = 14,
		colours = { "Bone" },
		speed = { 0.03, 0.12 },
		gravity = -0.05,
		life = { 0.8, 1.3 },
		width = 0.005,
		length = 0.005,
		spread = { 0.12, 0.2 },
	},
	BlackSite = {
		count = 30,
		colours = { "HazardRed", "HazardRed", "Bone" },
		speed = { 0.5, 1.3 },
		gravity = 1.1,
		life = { 0.5, 0.9 },
		width = 0.003,
		length = 0.024,
		alongTravel = true,
	},
	Prototype = {
		count = 28,
		colours = { "SignalAcid", "SignalAcid", "Bone" },
		speed = { 0.15, 0.5 },
		gravity = 0,
		life = { 0.6, 1.1 },
		width = 0.01,
		length = 0.01,
		spread = { 0.1, 0.16 },
		stepped = true,
	},
	Chromatic = {
		count = 40,
		colours = { "HazardRed", "SignalAcid", "DataCyan", "Bone" },
		speed = { 0.35, 0.9 },
		gravity = 0.7,
		life = { 1, 1.6 },
		width = 0.007,
		length = 0.014,
		spin = 9,
	},
	Redacted = {
		count = 16,
		colours = { "DeepNavy", "DeepNavy", "Bone" },
		speed = { 0.4, 1 },
		gravity = 0,
		life = { 0.5, 0.9 },
		width = 0.09,
		length = 0.014,
		spread = { 0.05, 0.3 },
		angles = { 0, math.pi },
		stepped = true,
	},
	ZeroDay = {
		count = 60,
		colours = { "DataCyan", "DataCyan", "Bone" },
		speed = { 0.4, 0.9 },
		gravity = 0.2,
		life = { 0.9, 1.5 },
		width = 0.004,
		length = 0.03,
		spread = { 0.45, 0.1 },
		start = -0.45, -- above the middle of the screen, so it rains down past the cards
		angles = { math.pi / 2 },
		stepped = true,
		linger = true,
	},
}

function PullParticles.style(card: any): any
	if card.variant == Variant.ZeroDay then
		return STYLES.ZeroDay
	elseif card.variant == Variant.Chromatic then
		return STYLES.Chromatic
	elseif card.variant == Variant.Redacted then
		return STYLES.Redacted
	end
	return STYLES[card.tier]
end

local function pick(list: { any }, number: (number, number) -> number): any
	return list[math.clamp(math.floor(number(1, #list + 1)), 1, #list)]
end

-- share is how much of the style's full burst to make. number(low, high) gives a random number.
function PullParticles.spawn(style: any, share: number, number: (number, number) -> number): { any }
	local spread = style.spread or { 0, 0 }
	local particles = {}
	for _ = 1, math.max(math.round(style.count * share), 1) do
		local angle = if style.angles then pick(style.angles, number) else number(0, FULL_TURN)
		local speed = number(style.speed[1], style.speed[2])
		table.insert(particles, {
			x = number(-spread[1], spread[1]),
			y = number(-spread[2], spread[2]) + (style.start or 0),
			vx = math.cos(angle) * speed,
			vy = math.sin(angle) * speed,
			life = number(style.life[1], style.life[2]),
			colour = pick(style.colours, number),
			turn = number(-1, 1),
		})
	end
	return particles
end

function PullParticles.position(style: any, particle: any, elapsed: number): (number, number)
	local time = if style.stepped then math.floor(elapsed * STEP_RATE) / STEP_RATE else elapsed
	return particle.x + particle.vx * time, particle.y + particle.vy * time + style.gravity * time * time / 2
end

-- 0 is solid and 1 is gone.
function PullParticles.fade(particle: any, elapsed: number): number
	return math.clamp(elapsed / particle.life, 0, 1)
end

return PullParticles
