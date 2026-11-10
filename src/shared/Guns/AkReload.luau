--!strict
-- The AK's reload (the gun the game calls the M57): how the gun turns in the right hand, and the left hand, the
-- magazines and the bolt.
--
-- It follows a fast real AK reload River gave as a reference, except that the old magazine is ripped out by hand
-- first. The right hand tips the muzzle up and rolls the gun over, top to the right, so the mag well faces the left
-- hand. The left hand comes off the handguard onto the magazine, rocks it forward off its lug, rips it out and flings
-- it away, and carries on down out of view for a new one. It comes back up with the new magazine, hooks its front lug
-- and rocks it home. With the gun still rolled over, the hand swings round under it to the charging knob on the
-- right side, rips it back and lets it fly, and the gun comes back down as the hand goes to the handguard.
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
local CROSS_FROM, CROSS_TO = 0.7, 0.88 -- from the magazine to the knob, under the gun
local PULL_AT = 0.9 -- the handle is pulled
local FREE_AT = 0.97 -- and let go
local HOME_AT = 1 -- the bolt is home
local BACK_FROM, BACK_TO = 0.99, 1.18 -- and back to the handguard, round under the gun
local LENGTH = 1.26 -- the gun is back down
local GONE_AT = 0.6 -- the old magazine has fallen out of view
local GRAVITY = 30 -- metres a second a second, in these seconds
local FLING = 1.1 -- how fast the old magazine leaves the hand, metres a second
-- On its way back from the knob the hand swings out below the gun's right side, so it goes round the gun and not
-- through it. In the gun's space.
local UNDER = Vector3.new(0.6, -0.8, 0).Unit * 0.13

-- A left hand's palm on something: the point `along` up its fingers from the wrist and `out` from its palm goes at
-- `at`, with its fingers running one way and its palm facing another. The same idea as CardFlourish's grips.
local function grip(at: Vector3, along: number, out: number, fingers: Vector3, palm: Vector3): CFrame
	local y = fingers.Unit
	local facing = (palm - y * palm:Dot(y)).Unit
	local x = -facing
	return CFrame.fromMatrix(at - y * along - facing * out, x, y, x:Cross(y))
end

-- On a magazine: palm on its left side, fingers forward round its front.
local ON_MAG = grip(MAG, 0.085, 0.035, Vector3.new(0.2, 0.3, -1), Vector3.new(1, 0, 0))
-- On the knob. The gun is still rolled over, right side down, so the hand comes up from under it and stays outside
-- its right side: wrist below and clear of the receiver, fingers up the side to hook the knob, palm facing back to
-- pull. (With the wrist on the left and the fingers on the right, the hand went straight through the gun.)
local ON_KNOB = grip(KNOB, 0.15, 0.01, Vector3.new(-0.49, 0.86, 0), Vector3.new(0, 0, 1))
-- Between the magazine and the knob the hand swings out round the bottom of the magazine.
local ROUND = Vector3.new(0.3, -1, 0.3).Unit * 0.14
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
	{ 0.88, -56, 31, 6, 0.03, 0 }, -- still rolled over for the charge, coming down
	{ FREE_AT, -52, 34, 5, 0.047, 0.004 }, -- dragged back by the pull
	{ 1.015, -49, 25, 4, 0.004, -0.006 }, -- thrown forward, muzzle dipping, as the bolt flies home
	{ 1.07, -47, 28, 4, 0.02, 0 },
	{ 1.17, 4, -4, -1, -0.006, -0.012 }, -- it comes down heavy, dipping past ready
	{ 1.22, -1, 1, 0, 0, 0.003 },
	{ 1.24, 0, 0, 0, 0, 0 },
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
	swing: Vector3, -- how far out of the straight line between the two the hand swings, in the hold
}

-- The reload t seconds in, exactly as keyed: the gun's turn, then in the gun's space the old magazine, the new one
-- and the left palm, then the bolt, the hand's weight and its swing (in the gun's space too).
local function keyed(t: number): (CFrame, CFrame, CFrame, CFrame, number, number, Vector3)
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
	local onKnob = CFrame.new(0, 0, pulled) * ON_KNOB
	local palm = onNew
	if t < FLUNG_AT then
		palm = old * ON_MAG
	elseif t < DOWN_AT then
		-- Having let go, it carries on down the way it was going to the new one.
		palm = (RIPPED * ON_MAG):Lerp(onNew, smooth((t - FLUNG_AT) / (DOWN_AT - FLUNG_AT)))
	elseif t >= CROSS_TO then
		palm = onKnob
	elseif t > CROSS_FROM then
		local u = smooth((t - CROSS_FROM) / (CROSS_TO - CROSS_FROM))
		palm = onNew:Lerp(onKnob, u) + ROUND * math.sin(u * math.pi)
	end

	local weight, swing = 0, Vector3.zero
	if t > LEAVE_FROM and t < BACK_TO then
		if t < BACK_FROM then
			weight = smooth((t - LEAVE_FROM) / (LEAVE_TO - LEAVE_FROM))
		else
			local u = (t - BACK_FROM) / (BACK_TO - BACK_FROM)
			weight = 1 - smooth(u)
			swing = UNDER * math.sin(u * math.pi)
		end
	end
	return gun, old, new, palm, bolt, weight, swing
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
	local weight, swing, total = 0, Vector3.zero, 0
	for _, tap in TAPS do
		local tapGun, tapOld, tapNew, tapPalm, _, tapWeight, tapSwing = keyed(t + tap[1] * window)
		total += tap[2]
		local share = tap[2] / total
		gun, old = gun:Lerp(tapGun, share), old:Lerp(tapOld, share)
		new, palm = new:Lerp(tapNew, share), palm:Lerp(tapPalm, share)
		weight += (tapWeight - weight) * share
		swing = swing:Lerp(tapSwing, share)
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
		swing = gun.Rotation * swing,
	}
end

AkReload.LENGTH = LENGTH
AkReload.SOUND = 1.24 -- one reload: all of it fits in the gun's reload time
AkReload.TRAVEL = TRAVEL
AkReload.ROCK = ROCK
AkReload.LUG = LUG

return AkReload
