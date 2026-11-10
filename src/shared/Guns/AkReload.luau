--!strict
-- The AK's reload (the gun the game calls the M57): how the gun turns in the right hand, and the left hand, the
-- magazines and the bolt. Timed to reload-assault-v4.wav: the old mag is knocked out at 0.42s, the new one slams in at
-- 0.64s, and the charging handle is pulled at 0.86s and let go at 0.93s.
--
-- It follows a fast real AK reload River gave as a reference. The left hand drops off the handguard to fetch a new
-- magazine while the right hand tips the muzzle up and rolls the gun over, top to the right, so the mag well faces
-- the left hand. The hand comes up with the new magazine and knocks the old one out with it, hooks the new one's
-- front lug and rocks it home. With the gun still rolled over, the hand swings round under it to the charging knob
-- on the right side, rips it back and lets it fly, and the gun comes back down as the hand goes to the handguard.
--
-- The times were set to the old 0.985s reload sound and now stretch to the gun's reload time: SOUND of these
-- seconds is one reload.
--
-- Everything is in the model's own axes (+X the gun's right, +Y up, +Z back toward the butt), in metres from the
-- origin of River's AK handoff, which is just above the trigger. "The hold" is that space before the gun's turn.
local AkReload = {}

-- A point from the handoff, whose axes are +X muzzle, +Y the gun's left, +Z up.
local function h(x: number, y: number, z: number): Vector3
	return Vector3.new(-y, z, -x)
end

local LUG = h(0.103, 0, -0.012) -- the magazine's front lug, which it rocks about
local MAG = h(0.09, 0, -0.09) -- the middle of the magazine, where the hand holds it
local KNOB = h(0.066, -0.033, 0.036) -- the charging knob
local GRIP = h(-0.06, 0, -0.05) -- in the right hand, which the gun turns about
local ROCK = 20 -- degrees a magazine is rocked forward when its lug hooks
local TRAVEL = 0.07 -- how far back the bolt carrier goes

local OUT_AT = 0.42 -- the old mag is knocked out
local HOOK_AT = 0.52 -- the new one's lug is hooked
local ROCK_AT = 0.58 -- it starts to rock home
local IN_AT = 0.64 -- and slams in
local PULL_AT = 0.86 -- the handle is pulled
local FREE_AT = 0.93 -- and let go
local HOME_AT = 0.96 -- the bolt is home
local LEAVE_FROM, LEAVE_TO = 0.04, 0.2 -- the hand comes off the handguard
local FETCH_AT = 0.24 -- it has the new magazine, down out of view, and starts up
local CROSS_FROM, CROSS_TO = 0.66, 0.84 -- from the magazine to the knob, under the gun
local BACK_FROM, BACK_TO = 0.95, 1.14 -- and back to the handguard, round under the gun
local LENGTH = 1.22 -- the gun is back down
local GONE_AT = 0.72 -- the old magazine has fallen out of view
local GRAVITY = 30 -- metres a second a second, in these seconds (they're stretched to the gun's reload time)
local KNOCK = 0.7 -- how fast the old magazine leaves the well, metres a second
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
-- The new magazine as it strikes the old one: below and ahead of the well, tipped well forward.
local STRIKE = CFrame.new(0, -0.05, -0.04) * rocked(ROCK + 14)

-- The gun's turn: seconds, degrees of roll (negative tips its top to the right), pitch (muzzle up) and yaw (muzzle
-- left), and metres pulled back and lifted. It rides one smooth curve through these, so it never stops dead at one and
-- every move carries into the next. For weight, the big swings carry a little past where they're going and settle
-- back, and each knock shoves the gun and it rebounds past where it was.
local GUN_KEYS = {
	{ 0, 0, 0, 0, 0, 0 },
	{ 0.06, 2, -3, 0, 0, -0.012 }, -- the left hand lets go and the muzzle sags
	{ 0.26, -70, 48, 11, 0.03, 0.01 }, -- swung up and over, carrying past
	{ 0.34, -65, 45, 10, 0.03, 0 }, -- and settling back, mag well to the left hand
	{ 0.41, -66, 45, 10, 0.03, 0 },
	{ 0.45, -75, 41, 12, 0.036, -0.012 }, -- the knock shoves it over and down
	{ 0.51, -64, 46, 10, 0.03, 0.004 }, -- and it comes back past
	{ 0.58, -65, 45, 10, 0.03, 0 },
	{ 0.635, -66, 44, 10, 0.03, 0 },
	{ 0.67, -57, 38, 9, 0.04, 0.014 }, -- the slam drives it up and back
	{ 0.74, -66, 46, 10, 0.03, -0.004 }, -- and it rebounds past
	{ 0.84, -56, 31, 6, 0.03, 0 }, -- still rolled over for the charge, coming down
	{ FREE_AT, -52, 34, 5, 0.047, 0.004 }, -- dragged back by the pull
	{ 0.975, -49, 25, 4, 0.004, -0.006 }, -- thrown forward, muzzle dipping, as the bolt flies home
	{ 1.03, -47, 28, 4, 0.02, 0 },
	{ 1.13, 4, -4, -1, -0.006, -0.012 }, -- it comes down heavy, dipping past ready
	{ 1.18, -1, 1, 0, 0, 0.003 },
	{ 1.2, 0, 0, 0, 0, 0 },
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

-- The reload t seconds in, exactly as keyed: the gun's turn, the new magazine in the gun's space, the old one in
-- the hold once it's falling, the bolt, the palm from the new magazine, the hand's weight and its swing in the
-- gun's space.
local function keyed(t: number): (CFrame, CFrame, CFrame?, number, CFrame, number, Vector3)
	local gun = gunAt(t)

	-- The new magazine, from the hand's fetch to its place in the gun (in the gun's space).
	local fetched = gun:Inverse() * FETCHED
	local new = CFrame.identity
	if t < FETCH_AT then
		new = fetched
	elseif t < OUT_AT then
		-- It speeds up into the old magazine and carries on through it, slowing only as its lug hooks: one swing,
		-- with the hit in the middle of it.
		local u = (t - FETCH_AT) / (OUT_AT - FETCH_AT)
		new = fetched:Lerp(STRIKE, u * u * (2 - u))
	elseif t < HOOK_AT then
		local u = (t - OUT_AT) / (HOOK_AT - OUT_AT)
		new = STRIKE:Lerp(rocked(ROCK), 1 - (1 - u) ^ 2)
	elseif t < ROCK_AT then
		new = rocked(ROCK)
	elseif t < IN_AT then
		local u = (t - ROCK_AT) / (IN_AT - ROCK_AT)
		new = rocked(ROCK * (1 - u * u)) -- the slam speeds up into the stop
	end
	-- The old one sits in the gun until it's knocked out. Then it's on its own: it leaves the well the way the well
	-- was facing, and falls straight down in the hold whatever the gun does after, tumbling as it goes.
	local old: CFrame? = nil
	if t >= OUT_AT and t < GONE_AT then
		local fall = t - OUT_AT
		local knocked = gunAt(OUT_AT)
		local thrown = knocked.Rotation * (Vector3.new(0, -1, -0.3).Unit * KNOCK)
		local drift = thrown * fall + Vector3.new(0, -GRAVITY * fall * fall / 2, 0)
		local tumble = CFrame.new(MAG) * CFrame.Angles(math.rad(260 * fall), 0, math.rad(140 * fall)) * CFrame.new(-MAG)
		old = CFrame.new(drift) * knocked * rocked(math.min(ROCK, 700 * fall)) * tumble
	end

	local bolt = 0
	if t > PULL_AT and t < HOME_AT then
		bolt = if t < FREE_AT
			then TRAVEL * (1 - (1 - (t - PULL_AT) / (FREE_AT - PULL_AT)) ^ 2)
			else TRAVEL * (1 - (t - FREE_AT) / (HOME_AT - FREE_AT)) ^ 2
	end
	-- The hand goes back with the handle and stays back when it lets go.
	local pulled = if t < FREE_AT then bolt else TRAVEL
	local onMag = new * ON_MAG
	local onKnob = CFrame.new(0, 0, pulled) * ON_KNOB
	local palm = onMag
	if t >= CROSS_TO then
		palm = onKnob
	elseif t > CROSS_FROM then
		local u = smooth((t - CROSS_FROM) / (CROSS_TO - CROSS_FROM))
		palm = onMag:Lerp(onKnob, u) + ROUND * math.sin(u * math.pi)
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
	return gun, new, old, bolt, new:Inverse() * palm, weight, swing
end

-- Each moment is blended with the moments just before and after it, which rounds every corner where one move meets
-- the next: nothing starts or stops in an instant. The blend narrows to nothing at the two ends, so it starts and
-- ends exactly at rest.
local TAPS = { { -1, 1 }, { -0.5, 2 }, { 0, 3 }, { 0.5, 2 }, { 1, 1 } } -- how far along the window, and how much it counts
local WINDOW = 0.035 -- seconds either side

-- The reload t seconds in.
function AkReload.at(t: number): Pose
	local window = math.clamp(math.min(t, LENGTH - t), 0, WINDOW)
	local gun, new, rel, weight, swing = CFrame.identity, CFrame.identity, CFrame.identity, 0, Vector3.zero
	local total = 0
	for _, tap in TAPS do
		local tapGun, tapNew, _, _, tapRel, tapWeight, tapSwing = keyed(t + tap[1] * window)
		total += tap[2]
		local share = tap[2] / total
		gun, new, rel = gun:Lerp(tapGun, share), new:Lerp(tapNew, share), rel:Lerp(tapRel, share)
		weight += (tapWeight - weight) * share
		swing = swing:Lerp(tapSwing, share)
	end
	-- The bolt's snap and the old magazine's fall aren't blended: one is meant to be sharp, the other is already
	-- smooth.
	local _, _, fallen, bolt = keyed(t)
	local old = if fallen then gun:Inverse() * fallen else nil
	-- Until the knock the magazine in the gun is the old one and the spare is the new one in the hand; then the new
	-- one is the gun's, and the spare is the old one falling.
	local mag, spare = new, old
	if t < OUT_AT then
		mag, spare = CFrame.identity, if t >= LEAVE_TO then new else nil
	end
	return {
		gun = gun,
		mag = mag,
		spare = spare,
		bolt = bolt,
		palm = gun * new * rel,
		weight = weight,
		swing = gun.Rotation * swing,
	}
end

AkReload.LENGTH = LENGTH
AkReload.SOUND = 1.2 -- the times above are for a reload this long, so all of it fits in the gun's reload time
AkReload.TRAVEL = TRAVEL
AkReload.ROCK = ROCK
AkReload.LUG = LUG

return AkReload
