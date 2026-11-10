--!strict
-- The AK's reload (the gun the game calls the M57): how the gun turns in the right hand, and the left hand, the
-- magazines and the bolt.
--
-- It follows a fast real AK reload River gave as a reference, except that the old magazine is ripped out by hand
-- first. The right hand tips the muzzle up and rolls the gun over, top to the right, so the mag well faces the left
-- hand. The left hand comes off the handguard onto the magazine, rocks it forward off its lug, rips it out and flings
-- it away, and carries on down out of view for a new one. It comes back up with the new magazine, hooks its front lug
-- and rocks it home, then goes back to the handguard and holds the gun as it comes down. The right hand comes off the
-- grip to the charging knob on the right side, rips it back and lets it fly, and goes back to the grip.
--
-- Everything is in the model's own axes (+X the gun's right, +Y up, +Z back toward the butt), in metres from the
-- origin of River's AK handoff, which is just above the trigger. "The hold" is that space before the gun's turn.
--
-- The times stretch to the gun's reload time: SOUND of these seconds is one reload.
local AkReload = {}

-- A point from the handoff, whose axes are +X muzzle, +Y the gun's left, +Z up.
local function h(x: number, y: number, z: number): Vector3
	return Vector3.new(-y, z, -x)
end

local LUG = h(0.103, 0, -0.012) -- the magazine's front lug, which it rocks about
local MAG = h(0.09, 0, -0.09) -- the middle of the magazine, where the hand holds it
local KNOB = h(0.066, -0.033, 0.036) -- the charging knob
local GRIP = h(-0.06, 0, -0.05) -- in the right hand, which the gun turns about
local ROCK = 20 -- degrees a magazine is rocked forward when its lug is unhooked
local TRAVEL = 0.07 -- how far back the bolt carrier goes

local LEAVE_FROM, LEAVE_TO = 0.04, 0.19 -- the hand goes from the handguard to the magazine
local RIP_AT = 0.21 -- it starts to rock the magazine off its lug
local OUT_AT = 0.27 -- the lug is free
local FLUNG_AT = 0.33 -- the magazine is ripped clear and let go
local DOWN_AT = 0.42 -- the hand is down out of view, on the new one
local FETCH_AT = 0.45 -- and starts up with it
local HOOK_AT = 0.57 -- the new one's lug is hooked
local ROCK_AT = 0.63 -- it starts to rock home
local IN_AT = 0.68 -- and slams in
local BACK_FROM, BACK_TO = 0.7, 0.86 -- the left hand goes from the magazine back to the handguard
local REACH_FROM, REACH_TO = 0.8, 0.91 -- the right hand goes from the grip to the knob
local PULL_AT = 0.92 -- the handle is pulled
local FREE_AT = 0.99 -- and let go
local HOME_AT = 1.02 -- the bolt is home
local GRIP_FROM, GRIP_TO = 1.01, 1.17 -- the right hand goes back to the grip
local LENGTH = 1.28 -- the gun is back down
local GONE_AT = 0.6 -- the old magazine has fallen out of view
local GRAVITY = 30 -- metres a second a second, in these seconds
local FLING = 1.1 -- how fast the old magazine leaves the hand, metres a second
-- Between the grip and the knob the right hand swings out from the gun's right side, so it clears the receiver.
-- In the gun's space.
local CLEAR = Vector3.new(0.09, 0.02, 0)

-- A hand's palm on something: the point `along` up its fingers from the wrist and `out` from its palm goes at
-- `at`, with its fingers running one way and its palm facing another. The same idea as CardFlourish's grips. A left
-- hand unless right is set.
local function grip(at: Vector3, along: number, out: number, fingers: Vector3, palm: Vector3, right: boolean?): CFrame
	local y = fingers.Unit
	local facing = (palm - y * palm:Dot(y)).Unit
	local x = if right then facing else -facing
	return CFrame.fromMatrix(at - y * along - facing * out, x, y, x:Cross(y))
end

-- On a magazine: palm on its left side, fingers forward and up round its front. It holds the lower half, which
-- curves forward, with its wrist below: higher up, the hand sat in the right hand's fingers at the trigger.
local MAG_HOLD = h(0.107, 0, -0.125)
local ON_MAG = grip(MAG_HOLD, 0.085, 0.035, Vector3.new(0.2, 0.6, -0.8), Vector3.new(1, 0, 0))
-- The right hand on the knob: well out from the gun's right side and below the knob, reaching in with only its
-- fingertips on the knob's end, palm facing back to pull. The hand is big next to the gun, so anything closer puts
-- its palm through the receiver.
local KNOB_END = KNOB + Vector3.new(0.014, 0, 0)
local ON_KNOB = grip(KNOB_END, 0.14, 0.012, Vector3.new(-0.62, 0.74, -0.25), Vector3.new(0, 0, 1), true)
-- A magazine in the hand down out of view, in the hold.
local FETCHED = CFrame.new(-0.2, -0.36, 0.02) * CFrame.Angles(0, 0, math.rad(50))

local function smooth(u: number): number
	u = math.clamp(u, 0, 1)
	return u * u * (3 - 2 * u)
end

local function rocked(degrees: number): CFrame
	return CFrame.new(LUG) * CFrame.Angles(math.rad(degrees), 0, 0) * CFrame.new(-LUG)
end
-- The old magazine ripped clear of the well: straight out of it and a little ahead, tipped further.
local RIPPED = CFrame.new(0, -0.11, -0.03) * rocked(ROCK + 10)

-- The gun's turn: seconds, degrees of roll (negative tips its top to the right), pitch (muzzle up) and yaw (muzzle
-- left), and metres pulled back and lifted. It rides one smooth curve through these, so it never stops dead at one and
-- every move carries into the next. For weight, the big swings carry a little past where they're going and settle
-- back, and each yank and knock shoves the gun and it rebounds past where it was.
local GUN_KEYS = {
	{ 0, 0, 0, 0, 0, 0 },
	{ 0.05, 2, -3, 0, 0, -0.012 }, -- the left hand lets go and the muzzle sags
	{ 0.19, -70, 48, 11, 0.03, 0.01 }, -- swung up and over, carrying past
	{ 0.25, -65, 45, 10, 0.03, 0 }, -- and settling back, mag well to the left hand
	{ 0.31, -74, 41, 12, 0.03, -0.016 }, -- the rip drags it over and down after the magazine
	{ 0.38, -63, 47, 10, 0.03, 0.006 }, -- and it springs back past as the magazine comes free
	{ 0.46, -65, 45, 10, 0.03, 0 },
	{ 0.6, -65, 45, 10, 0.03, 0 },
	{ 0.675, -66, 44, 10, 0.03, 0 },
	{ 0.71, -57, 38, 9, 0.04, 0.014 }, -- the slam drives it up and back
	{ 0.78, -66, 46, 10, 0.03, -0.004 }, -- and it rebounds past
	{ 0.9, 14, 18, 3, 0.02, 0 }, -- down in the left hand, tipped a little the other way so the knob faces the right hand
	{ FREE_AT, 16, 20, 2, 0.034, 0.004 }, -- dragged back by the pull
	{ 1.035, 12, 13, 2, 0.004, -0.006 }, -- thrown forward, muzzle dipping, as the bolt flies home
	{ 1.1, 8, 10, 1, 0.01, 0 },
	{ 1.19, -2, -3, 0, -0.004, -0.008 }, -- it comes down heavy, dipping past ready
	{ 1.23, 0.5, 0.5, 0, 0, 0.002 },
	{ 1.26, 0, 0, 0, 0, 0 },
}
-- How fast a value is changing at a key: the slope between its neighbours, and still at either end.
local function slope(index: number, value: number): number
	local keys = GUN_KEYS
	if index == 1 or index == #keys then
		return 0
	end
	return (keys[index + 1][value] - keys[index - 1][value]) / (keys[index + 1][1] - keys[index - 1][1])
end
local function gunAt(t: number): CFrame
	local keys = GUN_KEYS
	local now = { 0, 0, 0, 0, 0 }
	if t > 0 and t < keys[#keys][1] then
		for index = 2, #keys do
			local from, to = keys[index - 1], keys[index]
			if t < to[1] then
				local span = to[1] - from[1]
				local u = (t - from[1]) / span
				local u2, u3 = u * u, u * u * u
				for value = 2, 6 do
					now[value - 1] = from[value] * (2 * u3 - 3 * u2 + 1)
						+ slope(index - 1, value) * span * (u3 - 2 * u2 + u)
						+ to[value] * (-2 * u3 + 3 * u2)
						+ slope(index, value) * span * (u3 - u2)
				end
				break
			end
		end
	end
	return CFrame.new(GRIP + Vector3.new(0, now[5], now[4]))
		* CFrame.Angles(math.rad(now[2]), math.rad(now[3]), math.rad(now[1]))
		* CFrame.new(-GRIP)
end

export type Pose = {
	gun: CFrame, -- how the gun has turned in the hold
	mag: CFrame, -- how the magazine has moved from its place in the gun
	spare: CFrame?, -- the same for a second magazine, while there are two
	bolt: number, -- how far back the bolt carrier is, in metres
	palm: CFrame, -- where the left palm is, in the hold
	weight: number, -- how much of the hand is here, not where it rests on the handguard: 0 to 1
	right: CFrame, -- where the right palm is, in the hold
	rightWeight: number, -- how much of that hand is here, not on the grip: 0 to 1
	rightSwing: Vector3, -- how far out of the straight line between the two it swings, in the hold
}

-- The reload t seconds in, exactly as keyed: the gun's turn, then in the gun's space the old magazine, the new one
-- and the left palm, then the bolt, the left hand's weight, and the right palm (in the gun's space), its weight and
-- its swing (in the gun's space too).
local function keyed(t: number): (CFrame, CFrame, CFrame, CFrame, number, number, CFrame, number, Vector3)
	local gun = gunAt(t)

	-- The old magazine: rocked off its lug, ripped out of the well and let go. Then it's on its own: it flies on the
	-- way it was being pulled and falls straight down in the hold whatever the gun does after, tumbling.
	local old = CFrame.identity
	if t >= FLUNG_AT then
		local fall = t - FLUNG_AT
		local flung = gunAt(FLUNG_AT)
		local thrown = flung.Rotation * (Vector3.new(0, -1, -0.25).Unit * FLING)
		local drift = thrown * fall + Vector3.new(0, -GRAVITY * fall * fall / 2, 0)
		local tumble = CFrame.new(MAG) * CFrame.Angles(math.rad(260 * fall), 0, math.rad(140 * fall)) * CFrame.new(-MAG)
		old = gun:Inverse() * CFrame.new(drift) * flung * RIPPED * tumble
	elseif t >= OUT_AT then
		local u = (t - OUT_AT) / (FLUNG_AT - OUT_AT)
		old = rocked(ROCK):Lerp(RIPPED, u * (0.6 + 0.4 * u)) -- still speeding up as it's let go
	elseif t > RIP_AT then
		local u = (t - RIP_AT) / (OUT_AT - RIP_AT)
		old = rocked(ROCK * u * u) -- a yank
	end

	-- The new one: down out of view in the hand, then up to hook its lug, and rocked home.
	local fetched = gun:Inverse() * FETCHED
	local new = CFrame.identity
	if t < FETCH_AT then
		new = fetched
	elseif t < HOOK_AT then
		local u = (t - FETCH_AT) / (HOOK_AT - FETCH_AT)
		new = fetched:Lerp(rocked(ROCK), u * u * (3 - 2 * u))
	elseif t < ROCK_AT then
		new = rocked(ROCK)
	elseif t < IN_AT then
		local u = (t - ROCK_AT) / (IN_AT - ROCK_AT)
		new = rocked(ROCK * (1 - u * u)) -- the slam speeds up into the stop
	end

	local bolt = 0
	if t > PULL_AT and t < HOME_AT then
		bolt = if t < FREE_AT
			then TRAVEL * (1 - (1 - (t - PULL_AT) / (FREE_AT - PULL_AT)) ^ 2)
			else TRAVEL * (1 - (t - FREE_AT) / (HOME_AT - FREE_AT)) ^ 2
	end
	-- The hand goes back with the handle and stays back when it lets go.
	local pulled = if t < FREE_AT then bolt else TRAVEL
	local onNew = new * ON_MAG
	local palm = onNew
	if t < FLUNG_AT then
		palm = old * ON_MAG
	elseif t < DOWN_AT then
		-- Having let go, it carries on down the way it was going to the new one.
		palm = (RIPPED * ON_MAG):Lerp(onNew, smooth((t - FLUNG_AT) / (DOWN_AT - FLUNG_AT)))
	end
	local weight = 0
	if t > LEAVE_FROM and t < BACK_TO then
		weight = if t < BACK_FROM
			then smooth((t - LEAVE_FROM) / (LEAVE_TO - LEAVE_FROM))
			else 1 - smooth((t - BACK_FROM) / (BACK_TO - BACK_FROM))
	end

	local right = CFrame.new(0, 0, pulled) * ON_KNOB
	local rightWeight, rightSwing = 0, Vector3.zero
	if t > REACH_FROM and t < GRIP_TO then
		local u = if t < GRIP_FROM
			then (t - REACH_FROM) / (REACH_TO - REACH_FROM)
			else 1 - (t - GRIP_FROM) / (GRIP_TO - GRIP_FROM)
		rightWeight = smooth(u)
		rightSwing = CLEAR * math.sin(math.clamp(u, 0, 1) * math.pi)
	end
	return gun, old, new, palm, bolt, weight, right, rightWeight, rightSwing
end

-- Each moment is blended with the moments just before and after it, which rounds every corner where one move meets
-- the next: nothing starts or stops in an instant. The blend narrows to nothing at the two ends, so it starts and
-- ends exactly at rest.
local TAPS = { { -1, 1 }, { -0.5, 2 }, { 0, 3 }, { 0.5, 2 }, { 1, 1 } } -- how far along the window, and how much it counts
local WINDOW = 0.03 -- seconds either side

-- The reload t seconds in.
function AkReload.at(t: number): Pose
	local window = math.clamp(math.min(t, LENGTH - t), 0, WINDOW)
	local gun, old, new, palm = CFrame.identity, CFrame.identity, CFrame.identity, CFrame.identity
	local right, weight, rightWeight, rightSwing, total = CFrame.identity, 0, 0, Vector3.zero, 0
	for _, tap in TAPS do
		local tapGun, tapOld, tapNew, tapPalm, _, tapWeight, tapRight, tapRightWeight, tapSwing =
			keyed(t + tap[1] * window)
		total += tap[2]
		local share = tap[2] / total
		gun, old = gun:Lerp(tapGun, share), old:Lerp(tapOld, share)
		new, palm = new:Lerp(tapNew, share), palm:Lerp(tapPalm, share)
		right = right:Lerp(tapRight, share)
		weight += (tapWeight - weight) * share
		rightWeight += (tapRightWeight - rightWeight) * share
		rightSwing = rightSwing:Lerp(tapSwing, share)
	end
	local _, _, _, _, bolt = keyed(t) -- the bolt's snap is meant to be sharp
	-- The gun's magazine is the old one until it has fallen out of view, with the new one as the spare once the old
	-- one is let go; then the new one is the gun's.
	local mag: CFrame, spare: CFrame? = new, nil
	if t < GONE_AT then
		mag, spare = old, if t >= FLUNG_AT then new else nil
	end
	return {
		gun = gun,
		mag = mag,
		spare = spare,
		bolt = bolt,
		palm = gun * palm,
		weight = weight,
		right = gun * right,
		rightWeight = rightWeight,
		rightSwing = gun.Rotation * rightSwing,
	}
end

AkReload.LENGTH = LENGTH
AkReload.SOUND = 1.26 -- one reload: all of it fits in the gun's reload time
AkReload.TRAVEL = TRAVEL
AkReload.ROCK = ROCK
AkReload.LUG = LUG

return AkReload
