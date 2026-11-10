--!strict
-- The AK's reload (the gun the game calls the M57), for the left hand, the magazine and the bolt. The gun and the
-- right hand still come from the old M57 clip. Timed to reload-assault-v4.wav: the mag clicks out at 0.42s, the new
-- one slams in at 0.64s, and the charging handle is pulled at 0.86s and let go at 0.93s.
--
-- The left hand leaves the handguard, takes the magazine, rocks it forward off its lug and drops it away; brings
-- it back up as the new one, hooks the lug and rocks it home; then reaches under the gun to the charging knob on the
-- right side, rips it back, lets it fly home and goes back to the handguard.
--
-- Everything here is in the model's own axes (+X the gun's right, +Y up, +Z back toward the butt), in metres from
-- the origin of River's AK handoff, which is just above the trigger.
local AkReload = {}

-- A point from the handoff, whose axes are +X muzzle, +Y the gun's left, +Z up.
local function h(x: number, y: number, z: number): Vector3
	return Vector3.new(-y, z, -x)
end

local LUG = h(0.103, 0, -0.012) -- the magazine's front lug, which it rocks about
local MAG = h(0.09, 0, -0.09) -- the middle of the magazine, where the hand takes it
local KNOB = h(0.066, -0.033, 0.036) -- the charging knob
local ROCK = 20 -- degrees the magazine rocks forward to unhook
local AWAY = Vector3.new(-0.07, -0.3, -0.03) -- where the magazine goes from there: down and to the left, out of view
local TRAVEL = 0.07 -- how far back the bolt carrier goes

local OUT_AT = 0.42 -- the mag clicks out
local IN_AT = 0.64 -- the new one slams in
local PULL_AT = 0.86 -- the handle is pulled
local FREE_AT = 0.93 -- and let go
local HOME_AT = 0.96 -- the bolt is home
local REACH_FROM, REACH_TO = 0.1, 0.28 -- the hand goes from the handguard to the magazine
local CROSS_FROM, CROSS_TO = 0.66, 0.82 -- and from the magazine to the knob, dipping under the gun
local BACK_FROM = 0.95 -- and back to the handguard
local LENGTH = 1.15 -- when it's there

-- A hand's palm on something: the point `along` up its fingers from the wrist and `out` from its palm goes at `at`,
-- with its fingers running one way and its palm facing another. The same idea as CardFlourish's grips.
local function grip(at: Vector3, along: number, out: number, fingers: Vector3, palm: Vector3): CFrame
	local y = fingers.Unit
	local facing = (palm - y * palm:Dot(y)).Unit
	local x = -facing -- a left hand
	return CFrame.fromMatrix(at - y * along - facing * out, x, y, x:Cross(y))
end

-- On the magazine: palm on its left side, fingers forward round its front.
local ON_MAG = grip(MAG, 0.085, 0.035, Vector3.new(0.2, 0.3, -1), Vector3.new(1, 0, 0))
-- On the knob: come up from under the gun, fingers hooked over it, palm facing back to pull.
local ON_KNOB = grip(KNOB, 0.15, 0.01, Vector3.new(0.8, 0.6, 0), Vector3.new(0, 0, 1))

local function smooth(u: number): number
	u = math.clamp(u, 0, 1)
	return u * u * (3 - 2 * u)
end

-- How far the magazine is rocked, in degrees, and how far away it is, 0 to 1.
local MAG_KEYS = {
	{ 0.3, 0, 0 },
	{ OUT_AT, ROCK, 0 }, -- rocked off its lug
	{ 0.5, ROCK + 6, 1 }, -- and gone
	{ 0.54, ROCK + 6, 1 },
	{ 0.59, ROCK, 0 }, -- the new one, lug hooked
	{ IN_AT, 0, 0 }, -- slammed home
}
local function magAt(t: number): (number, number)
	if t <= MAG_KEYS[1][1] or t >= IN_AT then
		return 0, 0
	end
	for index = 2, #MAG_KEYS do
		local from, to = MAG_KEYS[index - 1], MAG_KEYS[index]
		if t < to[1] then
			local u = (t - from[1]) / (to[1] - from[1])
			u = if index == #MAG_KEYS then u * u else smooth(u) -- the slam speeds up into the stop
			return from[2] + (to[2] - from[2]) * u, from[3] + (to[3] - from[3]) * u
		end
	end
	return 0, 0
end

export type Pose = {
	mag: CFrame, -- how the magazine has moved from its place in the gun
	bolt: number, -- how far back the bolt carrier is, in metres
	palm: CFrame, -- where the left palm is
	weight: number, -- how much of the hand is here, not where it rests on the handguard: 0 to 1
}

-- The reload t seconds in.
function AkReload.at(t: number): Pose
	local rock, away = magAt(t)
	local mag = CFrame.new(AWAY * away) * CFrame.new(LUG) * CFrame.Angles(math.rad(rock), 0, 0) * CFrame.new(-LUG)

	local bolt = 0
	if t > PULL_AT and t < HOME_AT then
		bolt = if t < FREE_AT
			then TRAVEL * (1 - (1 - (t - PULL_AT) / (FREE_AT - PULL_AT)) ^ 2)
			else TRAVEL * (1 - (t - FREE_AT) / (HOME_AT - FREE_AT)) ^ 2
	end
	-- The hand goes back with the handle and stays back when it lets go.
	local pulled = if t < FREE_AT then bolt else TRAVEL
	local onMag = mag * ON_MAG
	local onKnob = CFrame.new(0, 0, pulled) * ON_KNOB
	local palm = onMag
	if t >= CROSS_TO then
		palm = onKnob
	elseif t > CROSS_FROM then
		local u = smooth((t - CROSS_FROM) / (CROSS_TO - CROSS_FROM))
		palm = onMag:Lerp(onKnob, u) + Vector3.new(0, -0.05 * math.sin(u * math.pi), 0)
	end

	local weight = 0
	if t > REACH_FROM and t < LENGTH then
		weight = if t < BACK_FROM
			then smooth((t - REACH_FROM) / (REACH_TO - REACH_FROM))
			else 1 - smooth((t - BACK_FROM) / (LENGTH - BACK_FROM))
	end
	return { mag = mag, bolt = bolt, palm = palm, weight = weight }
end

AkReload.LENGTH = LENGTH
AkReload.SOUND = 0.985 -- the reload time the times above are for
AkReload.TRAVEL = TRAVEL
AkReload.ROCK = ROCK
AkReload.LUG = LUG

return AkReload
