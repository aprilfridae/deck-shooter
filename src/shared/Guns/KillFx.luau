-- The numbers behind a kill's effects: the body glitching away into drifting pixels (KillDerez.client.luau), and
-- the killer's screen punch that grows with their streak (KillConfirm.luau). Pure, so it can be tested. See
-- docs/specs/guns.md, "Kill effects".
local KillFx = {}

-- The glitch-away, in seconds from the death. The body freezes where it died. It flashes white for a moment, then
-- flickers and tears while its parts go one by one, from the top down with some chance in it. Each part blinks for
-- a moment, then collapses flat and wide like an old screen switching off, and leaves as a puff of glitching
-- pixels and fine dust that drift off away from the shot. River found the first cut slow and blocky and then asked
-- for it faster again (2026-11-15), so it's quick.
KillFx.SHORT = 0.06 -- the white flash
KillFx.FLICKER = 0.03 -- one step of the glitch
KillFx.FIRST_GONE = 0.1 -- the first part goes
KillFx.DISSOLVE = 0.55 -- and the last
KillFx.HEAD_GONE = 0.04 -- a headshot's head goes at once
KillFx.WARN = 0.12 -- a part blinks for this long before it goes
KillFx.COLLAPSE = 0.05 -- and spends the last of it collapsing, without blinking
KillFx.BLINK_MOST = 0.6 -- the chance it's blinked out on a step, just before it collapses
KillFx.TEAR_CHANCE = 0.35 -- the chance on each step that the body tears sideways at some height
KillFx.TEAR_MOST = 0.45 -- studs a tear shifts the body above it, at most
KillFx.OWN_DELAY = 0.8 -- your own body waits this long, so you see it drop before it goes
KillFx.TRICKLE = 0.35 -- share of a part's pixels that leak out while it blinks; the rest go when it does

-- The textures, drawn in Blender with numpy (white on clear; the emitters colour them) and uploaded to the group
-- with tools/upload-group-assets.py.
KillFx.TEXTURES = {
	pixel = "rbxassetid://107943854572762", -- 4x4 flipbook: a square that tears into bands
	mote = "rbxassetid://113313050705987", -- a small soft square of light
	scanline = "rbxassetid://82361336313539", -- a thin broken line, for the tears
}

-- The killer's screen punch.
KillFx.PUNCH_ATTACK = 0.035 -- seconds to hit its peak
KillFx.PUNCH_DECAY = 14 -- how fast it falls away after that, a second
KillFx.STREAK_STEP = 0.2 -- each kill in a streak makes the punch this much bigger
KillFx.STREAK_TOP = 6 -- and it stops growing at this kill
KillFx.PITCH_TOP = 7 -- the kill sound climbs a semitone a kill, up to this many

-- A steady random number from 0 to 1 for two numbers.
function KillFx.noise(step: number, seed: number): number
	local value = math.sin(step * 12.9898 + seed * 78.233) * 43758.5453
	return value - math.floor(value)
end

-- When a part goes. height is where it sits in the body, 0 at the bottom and 1 at the top; roll is a random number
-- from 0 to 1. The top goes first, loosely.
function KillFx.goneAt(height: number, roll: number): number
	local order = (1 - math.clamp(height, 0, 1)) * 0.75 + math.clamp(roll, 0, 1) * 0.25
	return KillFx.FIRST_GONE + order * (KillFx.DISSOLVE - KillFx.FIRST_GONE)
end

-- Which glitch step the effect is on.
function KillFx.step(age: number): number
	return math.floor(math.max(age, 0) / KillFx.FLICKER)
end

-- Whether part number index is blinked out on this step, with left seconds until it goes. It's always there until
-- its warning starts, blinks more and more through it, and is gone after.
function KillFx.blinkedOut(step: number, index: number, left: number): boolean
	if left <= 0 then
		return true
	elseif left >= KillFx.WARN or left <= KillFx.COLLAPSE then
		return false
	end
	local warned = (KillFx.WARN - left) / (KillFx.WARN - KillFx.COLLAPSE)
	return KillFx.noise(step, index) < warned * KillFx.BLINK_MOST
end

-- How a part is squashed as it goes, with left seconds until it does: its width and its height against its own.
-- It collapses to a flat wide line over its last moment, like an old screen switching off.
function KillFx.squash(left: number): (number, number)
	local p = math.clamp(1 - left / KillFx.COLLAPSE, 0, 1)
	p = p * p
	return 1 + 0.5 * p, 1 - 0.92 * p
end

-- How far part number index is knocked sideways on this step while it blinks: mostly not at all.
function KillFx.jitter(step: number, index: number, left: number): number
	if left <= 0 or left >= KillFx.WARN or KillFx.noise(step, index + 0.5) < 0.75 then
		return 0
	end
	return (KillFx.noise(step, index + 0.25) - 0.5) * 0.6
end

-- A tear on this step: the height (0 to 1 of the body) above which the body is shifted, and by how many studs.
-- nil on a step without one, and through the white flash.
function KillFx.tear(step: number, age: number): (number?, number?)
	if age < KillFx.SHORT or age >= KillFx.DISSOLVE or KillFx.noise(step, 0.123) >= KillFx.TEAR_CHANCE then
		return nil, nil
	end
	local height = 0.2 + KillFx.noise(step, 0.456) * 0.7
	local shift = (KillFx.noise(step, 0.789) * 2 - 1) * KillFx.TEAR_MOST
	return height, shift
end

-- The glow over the body: its fill's transparency and how far it has gone from white to Data Cyan (0 to 1). A
-- solid white flash, then cyan with a white blip every third step, thinning out as the body goes.
function KillFx.glow(age: number): (number, number)
	if age < KillFx.SHORT then
		return 0.05, 0
	elseif age >= KillFx.DISSOLVE then
		return 1, 1
	end
	local fade = math.clamp((age - KillFx.SHORT) / (KillFx.DISSOLVE - KillFx.SHORT), 0, 1)
	local fill = 0.45 + 0.55 * fade
	if KillFx.step(age) % 3 == 0 then
		return fill * 0.7, 0
	end
	return fill, 1
end

-- Whether every part has gone.
function KillFx.done(age: number): boolean
	return age >= KillFx.DISSOLVE
end

-- How many of a part's count pixels are out, with left seconds until it goes.
function KillFx.released(count: number, left: number): number
	if left <= 0 then
		return count
	end
	local warned = math.clamp(1 - left / KillFx.WARN, 0, 1)
	return math.floor(count * KillFx.TRICKLE * warned)
end

-- How big the punch is at age seconds after the kill, from 0 to 1.
function KillFx.punch(age: number): number
	if age < 0 then
		return 0
	elseif age < KillFx.PUNCH_ATTACK then
		return age / KillFx.PUNCH_ATTACK
	end
	local left = math.exp(-(age - KillFx.PUNCH_ATTACK) * KillFx.PUNCH_DECAY)
	return if left < 0.01 then 0 else left
end

-- How much bigger the punch is on the streak-th kill of a life: 1 for the first, growing to a cap.
function KillFx.streakScale(streak: number): number
	return 1 + KillFx.STREAK_STEP * (math.clamp(streak, 1, KillFx.STREAK_TOP) - 1)
end

-- The kill sound's playback speed on the streak-th kill: a semitone higher each kill, up to a cap.
function KillFx.killPitch(streak: number): number
	return 2 ^ (math.clamp(streak - 1, 0, KillFx.PITCH_TOP) / 12)
end

-- How many pixels each part leaves as, given each part's volume and how many the whole body may make. Every part
-- makes at least one.
function KillFx.pixelCounts(volumes: { number }, budget: number): { number }
	local total = 0
	for _, volume in volumes do
		total += volume
	end
	local counts = {}
	for index, volume in volumes do
		counts[index] = if total > 0 then math.max(1, math.floor(volume / total * budget + 0.5)) else 1
	end
	return counts
end

return KillFx
