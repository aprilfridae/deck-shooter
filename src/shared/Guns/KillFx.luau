-- The numbers behind a kill's effects: the body shorting out and being scanned away into cubes of light (the
-- derez, KillDerez.client.luau), and the killer's screen punch that grows with their streak (KillConfirm.luau).
-- Pure, so it can be tested. See docs/specs/guns.md, "Kill effects".
local KillFx = {}

-- The derez, in seconds from the death.
KillFx.SHORT = 0.2 -- the body shorts out: it flashes white and flickers before the scan starts
KillFx.FLICKER = 0.035 -- one step of that flicker
KillFx.SCAN = 0.32 -- the scan runs from the top of the body to the bottom, taking it away as it goes
KillFx.RING_FADE = 0.2 -- the scan's ring fades out after it reaches the floor
KillFx.OWN_DELAY = 1 -- your own body waits this long, so you see it drop before it goes
KillFx.HIDDEN_SHARE = 0.3 -- of the body's parts, how many blink out on each flicker step

-- The cubes the body breaks into.
KillFx.SHARD_LIFE = { 0.45, 0.9 } -- seconds
KillFx.SHARD_SIZE = { 0.14, 0.32 } -- studs across
KillFx.SHARD_COOL = 0.35 -- share of its life a cube takes to cool from white to Data Cyan

-- The killer's screen punch.
KillFx.PUNCH_ATTACK = 0.035 -- seconds to hit its peak
KillFx.PUNCH_DECAY = 14 -- how fast it falls away after that, a second
KillFx.PUNCH_FOV = 4 -- degrees the view narrows at the peak of a first kill
KillFx.STREAK_STEP = 0.2 -- each kill in a streak makes the punch this much bigger
KillFx.STREAK_TOP = 6 -- and it stops growing at this kill
KillFx.PITCH_TOP = 7 -- the kill sound climbs a semitone a kill, up to this many

-- A steady random number from 0 to 1 for a whole number and a seed.
local function noise(step: number, seed: number): number
	local value = math.sin(step * 12.9898 + seed * 78.233) * 43758.5453
	return value - math.floor(value)
end

-- How far the scan has run down the body after age seconds: 0 until it starts, 1 once it has passed the feet. It
-- starts slowly, runs through the middle and slows into the feet.
function KillFx.scan(age: number): number
	local t = math.clamp((age - KillFx.SHORT) / KillFx.SCAN, 0, 1)
	return t * t * (3 - 2 * t)
end

-- Whether the derez is over: the scan has passed and its ring has faded.
function KillFx.done(age: number): boolean
	return age >= KillFx.SHORT + KillFx.SCAN + KillFx.RING_FADE
end

-- Which flicker step the short is on, or nil once the scan has started.
function KillFx.flickerStep(age: number): number?
	if age < 0 or age >= KillFx.SHORT then
		return nil
	end
	return math.floor(age / KillFx.FLICKER)
end

-- Whether part number index blinks out on this flicker step. The first step shows the whole body, white.
function KillFx.blinkedOut(step: number, index: number): boolean
	return step > 0 and noise(step, index) < KillFx.HIDDEN_SHARE
end

-- The glow over the body: its fill's transparency and how far it has gone from white to Data Cyan (0 to 1). It
-- flashes white, flickers between white and cyan through the short, and fades as the scan takes the body.
function KillFx.glow(age: number): (number, number)
	local step = KillFx.flickerStep(age)
	if step then
		return if step % 2 == 0 then 0.05 else 0.35, if step % 2 == 0 then 0 else 1
	end
	return 0.3 + 0.7 * KillFx.scan(age), 1
end

-- The scan ring's transparency: solid as it runs, fading once it has reached the floor.
function KillFx.ring(age: number): number
	local past = age - KillFx.SHORT - KillFx.SCAN
	if past <= 0 then
		return 0
	end
	return math.min(past / KillFx.RING_FADE, 1)
end

-- A cube share of the way through its life: its size against its first size, how far it has cooled from white to
-- Data Cyan (0 to 1), and its transparency.
function KillFx.shard(share: number): (number, number, number)
	share = math.clamp(share, 0, 1)
	return 1 - share * share, math.min(share / KillFx.SHARD_COOL, 1), share ^ 3
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

-- How many cubes each part breaks into, given each part's volume and how many cubes the whole body may make.
-- Every part makes at least one.
function KillFx.shardCounts(volumes: { number }, budget: number): { number }
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
