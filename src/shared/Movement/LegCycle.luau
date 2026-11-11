-- The third-person run: where each foot is through a stride, and the hip, knee and ankle angles that put it there.
-- Pure numbers, no Roblox types, so it can be tested. RemotePoses turns the angles into joint transforms.
--
-- River found the old legs wrong: they flipped between four still poses. Here a foot is planted for part of the
-- stride and slides back under the body exactly as fast as the body moves over the ground, so it doesn't skate,
-- then lifts and swings forward. The phase is driven by ground covered, so the legs keep pace with any speed.
--
-- Angles are radians. "Forward" angles are positive the way a positive turn about a joint's X axis swings a
-- hanging leg forward.
local LegCycle = {}

-- The soldier rig's leg, from BodyPoses.Empty.rig: hip to knee, knee to ankle.
LegCycle.thigh = 1.7
LegCycle.shin = 1.64
-- The rig's joints rest slightly bent, before any pose turns them.
LegCycle.restHip = math.rad(8) -- thigh forward
LegCycle.restKnee = math.rad(14) -- knee bent
LegCycle.restAnkle = math.rad(6) -- toes up
-- Hip above ankle with every joint at rest, which is when the feet are on the ground.
LegCycle.restHeight = LegCycle.thigh * math.cos(LegCycle.restHip)
	+ LegCycle.shin * math.cos(LegCycle.restHip - LegCycle.restKnee)

local REACH = (LegCycle.thigh + LegCycle.shin) * 0.985 -- a leg never quite locks straight
local TOE_OFF = math.rad(-32) -- toes down as the foot leaves the ground
local TOE_LAND = math.rad(12) -- toes up as it comes down
local CARRY = 0.3 -- the share of the planted foot's speed the swing starts and ends with

export type Shape = {
	half: number, -- studs the planted foot travels either side of the hip
	stance: number, -- the share of the stride a foot is planted
	length: number, -- studs of ground in one whole stride (both feet)
	lift: number, -- how high the swinging foot rises
	bob: number, -- how far the hips rise and fall
}
-- The swagger: how the hips move over the stride, which the legs then allow for so the feet stay put.
export type Hips = {
	sway: number, -- studs to the body's right: over whichever foot is planted
	twist: number, -- turned to the left (the right hip forward) as the right foot reaches ahead
	roll: number, -- the right hip up: the hip over the swinging leg drops
}
export type Leg = {
	pitch: number, -- the thigh, forward from straight down
	bend: number, -- the knee, 0 straight
	roll: number, -- the whole leg out to the body's right
	foot: number, -- the foot's pitch, toes up positive
}

-- How the stride changes with speed (studs a second): slow is short steps with a foot nearly always down, fast
-- is long steps with both feet off the ground between them.
function LegCycle.shape(speed: number): Shape
	local half = math.clamp(0.6 + 0.07 * speed, 0.6, 1.3)
	-- At sprint a foot is down for a fifth of the stride, which puts the footfalls about 6.5 studs apart.
	local stance = math.clamp(0.6 - 0.0216 * speed, 0.2, 0.6)
	return {
		half = half,
		stance = stance,
		length = 2 * half / stance,
		lift = math.clamp(0.2 + 0.022 * speed, 0.2, 0.65), -- River found the first pass (up to 1.25) lifted too high
		bob = math.clamp(0.01 * speed, 0, 0.12),
	}
end

local function smooth(x: number): number
	return x * x * (3 - 2 * x)
end

-- Where a foot is at this point in its stride (0 to 1, planted first): studs ahead of the hip along the way the
-- body is going, studs off the ground, and its pitch.
function LegCycle.foot(phase: number, shape: Shape): (number, number, number)
	phase %= 1
	if phase < shape.stance then
		local through = phase / shape.stance
		-- Flat while planted, rolling onto the toes at the end.
		local toes = math.clamp((through - 0.6) / 0.4, 0, 1)
		return shape.half * (1 - 2 * through), 0, TOE_OFF * 0.5 * toes * toes
	end
	local through = (phase - shape.stance) / (1 - shape.stance)
	-- The foot leaves the ground still moving back and lands already moving back, so it doesn't stop dead at
	-- either end of the swing (River asked for smoother): a curve from behind to ahead that carries a share of
	-- the planted foot's speed at both ends.
	local carry = -CARRY * 2 * shape.half / shape.stance * (1 - shape.stance)
	local t2, t3 = through * through, through * through * through
	local ahead = (2 * t3 - 3 * t2 + 1) * -shape.half
		+ (t3 - 2 * t2 + through) * carry
		+ (-2 * t3 + 3 * t2) * shape.half
		+ (t3 - t2) * carry
	-- Off the ground and back onto it gently, a little quicker up than down.
	local lift = shape.lift * (0.5 - 0.5 * math.cos(2 * math.pi * through ^ 0.85))
	local pitch = if through < 0.5
		then TOE_OFF * (0.5 + 0.5 * math.sin(math.pi * through))
		else TOE_OFF * (1 - smooth((through - 0.5) * 2)) + TOE_LAND * smooth((through - 0.5) * 2)
	return ahead, lift, pitch
end

local SWAY = 0.16
local TWIST = math.rad(11)
local ROLL = math.rad(5)

-- phase is the right foot's. All of it grows with speed up to a run.
function LegCycle.hips(phase: number, shape: Shape, speed: number): Hips
	local much = math.clamp(speed / 14, 0, 1)
	local planted = math.cos(2 * math.pi * (phase - shape.stance / 2)) -- 1 over the right foot, -1 over the left
	return {
		sway = SWAY * much * planted,
		twist = TWIST * much * math.cos(2 * math.pi * phase),
		roll = ROLL * much * planted,
	}
end

-- Studs of ground between one foot landing and the other, at this speed. The step sounds and the first-person
-- bob keep this time too.
function LegCycle.stepStuds(speed: number): number
	return LegCycle.shape(speed).length / 2
end

-- True when a foot lands as the stride goes from one phase on by this much (under half a stride).
function LegCycle.lands(phase: number, advance: number): boolean
	return math.floor(phase * 2) ~= math.floor((phase + advance) * 2)
end

-- The hips' rise and fall at this point in the stride: lowest with a foot planted under them. phase is the right
-- foot's.
function LegCycle.bob(phase: number, shape: Shape): number
	return -shape.bob * math.cos(4 * math.pi * (phase - shape.stance / 2))
end

-- The angles that put the ankle `ahead` in front of the hip, `side` to its right and `down` below it.
function LegCycle.solve(ahead: number, side: number, down: number): (number, number, number)
	local thigh, shin = LegCycle.thigh, LegCycle.shin
	down = math.max(down, 0.3)
	local roll = math.atan2(side, down)
	local drop = math.sqrt(down * down + side * side) -- how far below the hip, in the leg's own plane
	local distance = math.sqrt(ahead * ahead + drop * drop)
	if distance > REACH then
		ahead *= REACH / distance
		drop *= REACH / distance
		distance = REACH
	end
	distance = math.max(distance, math.abs(thigh - shin) + 0.05)
	local inside = math.acos(math.clamp((thigh * thigh + shin * shin - distance * distance) / (2 * thigh * shin), -1, 1))
	local lead = math.acos(math.clamp((thigh * thigh + distance * distance - shin * shin) / (2 * thigh * distance), -1, 1))
	return math.atan2(ahead, drop) + lead, math.pi - inside, roll
end

-- Keeping the legs out of each other (River saw them clipping): each foot is set a little outside its hip, and
-- when stepping sideways it can come no closer to the other leg than INSIDE studs in from its own hip.
local SPLAY = 0.18
local INSIDE = 0.12

-- One leg, whole. phase is this leg's own; forward and right say which way the body is going relative to the
-- way it faces (a unit vector's two parts); height is hip above the ground. side is 1 for the right leg and -1
-- for the left.
-- hips, when given, is where LegCycle.hips has put the hips: the leg undoes it so the foot stays where it was.
function LegCycle.leg(phase: number, shape: Shape, forward: number, right: number, height: number, side: number, hips: Hips?): Leg
	local along, lift, foot = LegCycle.foot(phase, shape)
	local out = math.max((along * right) * side + SPLAY, -INSIDE) -- studs outward from this leg's hip
	local ahead, across = along * forward, out * side
	local tipped = 0
	if hips then
		across -= hips.sway
		local cos, sin = math.cos(hips.twist), math.sin(hips.twist)
		ahead, across = ahead * cos - across * sin, across * cos + ahead * sin
		tipped = hips.roll
	end
	local pitch, bend, roll = LegCycle.solve(ahead, across, height - lift)
	roll -= tipped
	return { pitch = pitch, bend = bend, roll = roll, foot = foot * math.max(forward, 0.3) }
end

return LegCycle
