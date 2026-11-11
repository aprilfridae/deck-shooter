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

export type Shape = {
	half: number, -- studs the planted foot travels either side of the hip
	stance: number, -- the share of the stride a foot is planted
	length: number, -- studs of ground in one whole stride (both feet)
	lift: number, -- how high the swinging foot rises
	bob: number, -- how far the hips rise and fall
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
	local stance = math.clamp(0.6 - 0.02 * speed, 0.25, 0.6)
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
	local ahead = shape.half * (2 * smooth(through) - 1)
	-- Up quickly off the ground and down more gently.
	local lift = shape.lift * math.sin(math.pi * through ^ 0.75)
	local pitch = if through < 0.5
		then TOE_OFF * (0.5 + 0.5 * math.sin(math.pi * through))
		else TOE_OFF * (1 - smooth((through - 0.5) * 2)) + TOE_LAND * smooth((through - 0.5) * 2)
	return ahead, lift, pitch
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
function LegCycle.leg(phase: number, shape: Shape, forward: number, right: number, height: number, side: number): Leg
	local along, lift, foot = LegCycle.foot(phase, shape)
	local out = math.max((along * right) * side + SPLAY, -INSIDE) -- studs outward from this leg's hip
	local pitch, bend, roll = LegCycle.solve(along * forward, out * side, height - lift)
	return { pitch = pitch, bend = bend, roll = roll, foot = foot * math.max(forward, 0.3) }
end

return LegCycle
