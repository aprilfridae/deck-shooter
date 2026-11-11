-- Reloads for the third-person body that first person has no ready-made motion for in the gun's own space: the
-- Energy Pistol and the Longscope. (The M57's is AkReload, shared with first person.) Each gives the same kind of
-- pose AkReload does, and RemotePoses plays it on the body the same way.
--
-- Everything here is in the held gun's handle space, in studs: +X the gun's right, +Y its top, -Z its muzzle.
-- Times are seconds of each gun's reload sound, as first person's reloads are keyed (GunView's RELOADS).
--
-- A pose's parts:
--   gun    how the gun has turned in the hold; the hands go round with it
--   spin   a further turn of the gun that the hands don't follow (the Longscope's flip)
--   mag    how the magazine (or the Longscope's lever) has moved from its place on the gun
--   bolt   how far back the slide or bolt is
--   palm, weight         where the left palm is in the hold, and how much of the hand is there, not where the pose has it
--   leftShift, rightShift  how far each hand is from where it would be, in the hold
local BodyReloads = {}

export type Fit = { middle: Vector3, ratio: number } -- the model's middle from the handle; handle studs per stored stud

local function smooth(u: number): number
	u = math.clamp(u, 0, 1)
	return u * u * (3 - 2 * u)
end

local function between(t: number, from: number, to: number): number
	return math.clamp((t - from) / (to - from), 0, 1)
end

local function about(point: Vector3, turn: CFrame): CFrame
	return CFrame.new(point) * turn * CFrame.new(-point)
end

-- A palm on something, as AkReload's: the point `along` up its fingers from the wrist and `out` from its palm goes
-- at `at`, fingers running one way and the palm facing another. A left hand unless right is set.
local function grip(at: Vector3, along: number, out: number, fingers: Vector3, palm: Vector3, right: boolean?): CFrame
	local y = fingers.Unit
	local facing = (palm - y * palm:Dot(y)).Unit
	local x = if right then facing else -facing
	return CFrame.fromMatrix(at - y * along - facing * out, x, y, x:Cross(y))
end

-- Where a set of { time, value } keys has got to, easing from each to the next.
local function keyedNumber(keys: { { number } }, t: number): number
	if t <= keys[1][1] then
		return keys[1][2]
	end
	for index = 2, #keys do
		if t < keys[index][1] then
			local from, to = keys[index - 1], keys[index]
			return from[2] + (to[2] - from[2]) * smooth((t - from[1]) / (to[1] - from[1]))
		end
	end
	return keys[#keys][2]
end

local function keyedFrame(keys: { { any } }, t: number): CFrame
	if t <= keys[1][1] then
		return keys[1][2]
	end
	for index = 2, #keys do
		if t < keys[index][1] then
			local from, to = keys[index - 1], keys[index]
			return from[2]:Lerp(to[2], smooth((t - from[1]) / (to[1] - from[1])))
		end
	end
	return keys[#keys][2]
end

-- The Energy Pistol ---------------------------------------------------------------------------------------------
-- Third person holds it out flat on its side. To reload, the right hand brings it in and turns it upright with the
-- muzzle up; the old cell drops out of the grip; the left hand, which hangs at the side, comes up with a new cell
-- and slams it in (0.58s, the sound's hit), goes over the top to rack the slide (0.68 to 0.74s), and drops away
-- again as the gun goes back out flat.
do
	local SIDEWAYS = CFrame.Angles(0, 0, math.rad(90)) -- the hold: the gun's top turned to the body's left
	local GRIP = Vector3.new(0, 0.3, 0.2) -- in the right hand, which the gun turns about
	local WELL = Vector3.new(0, 0.02, 0.21) -- the bottom of the grip, where a cell goes in
	local SLIDE_TOP = Vector3.new(0, 0.72, -0.25)
	local TRAVEL = 0.22 -- how far back the slide racks
	local LENGTH = 0.964

	-- A turn as it looks from outside (roll back toward upright, muzzle up, and a shift right, up and back),
	-- worked into the gun's own space, where the sideways hold has swapped the axes round.
	local function turn(roll: number, pitch: number, right: number, up: number, back: number): CFrame
		local seen = CFrame.new(right, up, back) * CFrame.Angles(math.rad(pitch), 0, math.rad(roll))
		return about(GRIP, SIDEWAYS:Inverse() * seen * SIDEWAYS)
	end

	local GUN = {
		{ 0, CFrame.identity },
		{ 0.14, turn(-68, 26, -0.1, 0.1, 0.45) }, -- brought in, upright, muzzle up
		{ 0.3, turn(-76, 30, -0.12, 0.02, 0.5) }, -- sagging as the old cell goes
		{ 0.5, turn(-78, 24, -0.12, -0.04, 0.5) }, -- winding down before the slam
		{ 0.58, turn(-70, 42, -0.1, 0.2, 0.58) }, -- SLAM: driven up and back
		{ 0.63, turn(-76, 26, -0.12, 0, 0.5) }, -- and drops past
		{ 0.69, turn(-72, 18, -0.1, 0.02, 0.62) }, -- the rack yanks it back, muzzle dipping
		{ 0.75, turn(-74, 36, -0.1, 0.08, 0.44) }, -- the slide flies home and throws it forward
		{ 0.84, turn(-30, 8, -0.04, 0, 0.2) }, -- rolling back out flat
		{ LENGTH, CFrame.identity },
	}
	local ON_CELL = grip(WELL + Vector3.new(0, -0.2, 0), 0.1, 0.03, Vector3.new(1, 0.1, -0.5), Vector3.new(0, 1, 0))
	local ON_SLIDE = grip(SLIDE_TOP, 0.09, 0.03, Vector3.new(1, -0.25, 0.1), Vector3.new(0, -1, 0))

	local function at(t: number)
		local gun = keyedFrame(GUN, t)
		-- The old cell slides out of the grip and is gone; the new one comes up from below and slams home.
		local cell = CFrame.identity
		if t >= 0.12 and t < 0.36 then
			local u = between(t, 0.12, 0.36)
			cell = CFrame.new(0, -1.3 * u * u, 0.1 * u)
		elseif t >= 0.36 and t < 0.58 then
			local u = between(t, 0.36, 0.58)
			local left = 1 - u * u * u -- speeding up into the stop
			cell = CFrame.new(-0.25 * left, -1.1 * left, 0.2 * left)
		end
		local bolt = 0
		if t > 0.67 and t < 0.75 then
			bolt = if t < 0.71 then TRAVEL * (1 - (1 - between(t, 0.67, 0.71)) ^ 2) else TRAVEL * (1 - between(t, 0.71, 0.75)) ^ 2
		end
		-- The left hand: up with the new cell, across to the slide, back with it, and away.
		local onCell = (if t < 0.36 then CFrame.new(-0.25, -1.1, 0.2) else cell) * ON_CELL
		local onSlide = CFrame.new(0, 0, if t < 0.71 then bolt else TRAVEL) * ON_SLIDE
		local palm = onCell:Lerp(onSlide, smooth(between(t, 0.6, 0.67)))
		local weight = smooth(between(t, 0.18, 0.4)) * (1 - smooth(between(t, 0.73, 0.92)))
		return { gun = gun, mag = cell, bolt = bolt, palm = gun * palm, weight = weight, rightWeight = 0 }
	end

	BodyReloads["Energy Pistol"] = { at = at, LENGTH = LENGTH, SOUND = LENGTH }
end

-- The Longscope -------------------------------------------------------------------------------------------------
-- First person's reload (GunView's RELOADS.Longscope), on the body. It runs from the shot: the kick throws the
-- barrel up and the gun carries on round, once backwards about the trigger, while the left hand is knocked off,
-- gets under it and catches it (0.62s). Then the right hand throws the lever open on the sound's click (1.03s) and
-- slams it shut on the clunk (1.32s). The lever and bolt are the model's Lever_ and Bolt_ parts.
do
	local LEAD = 0.12 -- the reload starts this long after the shot the keys start at
	local LENGTH = 1.77
	local SCALE = 0.9 -- first person's gun is drawn a little bigger than the body's
	-- The lever, as GunView's LEVERS has it: in the stored model's studs from its middle.
	local LEVER = { pivot = Vector3.new(0, -1.82, 9.1), swing = math.rad(55), slide = 6.08 }

	local function tilt(roll: number, yaw: number, pitch: number, x: number, y: number, z: number): CFrame
		return CFrame.new(x * SCALE, y * SCALE, z * SCALE) * CFrame.Angles(math.rad(pitch), math.rad(yaw), math.rad(roll))
	end
	-- Seconds, the gun's turn and shift, and where the left hand is from its grip.
	local KEYS = {
		{ 0, CFrame.identity, Vector3.zero },
		{ 0.15, tilt(-9, 0, 0, 0, 0.34, 0.6), Vector3.new(0, 0.03, -0.4) }, -- the shot heaves it back and up
		{ 0.2, tilt(-7, 0, 0, 0, 0.33, 0.45), Vector3.new(0, -0.11, -0.05) }, -- the hand gets under it
		{ 0.28, tilt(-4, 0, 0, 0, 0.34, 0.2), Vector3.new(0.02, 0.12, -0.18) }, -- shoves it up and stops
		{ 0.44, tilt(-2, 0, 0, 0, 0.53, 0.05), Vector3.new(0.02, -0.06, -0.03) }, -- it flips up above the hand
		{ 0.56, tilt(1, -1, 1, 0.01, 0.47, 0.02), Vector3.new(0.01, -0.03, 0) }, -- and comes back down
		{ 0.62, tilt(4, -2, 2, 0.02, 0.41, 0.02), Vector3.zero }, -- landing in the hand
		{ 0.68, tilt(8, -3, -5, -0.01, 0.27, 0.02), Vector3.new(0, -0.03, 0) }, -- both hands drop with the weight
		{ 0.79, tilt(10, -4, 2, -0.03, 0.1, 0.03), Vector3.zero },
		{ 0.92, tilt(11, -4, 2.5, -0.03, 0.05, 0.03), Vector3.zero }, -- a small wind-up
		{ 1.03, tilt(9.5, -3, 4.5, -0.02, -0.04, -0.05), Vector3.zero }, -- CLICK: the lever hits its stop
		{ 1.1, tilt(10, -3, 2, -0.02, -0.02, -0.035), Vector3.zero },
		{ 1.2, tilt(10.5, -4, 2, -0.03, -0.025, -0.03), Vector3.zero }, -- held open
		{ 1.32, tilt(6, -2, -3, -0.01, 0.045, 0.065), Vector3.zero }, -- CLUNK: slammed shut
		{ 1.42, tilt(3, -1, -0.5, 0, 0.015, 0.03), Vector3.zero },
		{ 1.55, tilt(-1, 0.3, -0.5, 0.002, -0.006, 0.015), Vector3.zero },
		{ LENGTH, CFrame.identity, Vector3.zero },
	}
	local SPIN = { { 0, 0 }, { 0.15, 0.25 }, { 0.26, 0.55 }, { 0.62, 1 } } -- how much of the one turn is done
	local LEVER_OPEN = { { 0.92, 0 }, { 1.03, 1 }, { 1.2, 1 }, { 1.32, 0 } }

	local function spun(t: number): number
		if t >= 0.62 then
			return 1
		end
		for index = 2, #SPIN do
			if t < SPIN[index][1] then
				local from, to = SPIN[index - 1], SPIN[index]
				return from[2] + (to[2] - from[2]) * (t - from[1]) / (to[1] - from[1])
			end
		end
		return 1
	end

	local function at(t: number, fit: Fit?)
		local middle = if fit then fit.middle else Vector3.zero
		local ratio = if fit then fit.ratio else 0.0375
		local pivot = middle + LEVER.pivot * ratio
		local trigger = pivot + Vector3.new(0, 0.12, 0.25)

		local gun, shift = CFrame.identity, Vector3.zero
		for index = 2, #KEYS do
			if t < KEYS[index][1] then
				local from, to = KEYS[index - 1], KEYS[index]
				local u = smooth((t - from[1]) / (to[1] - from[1]))
				gun, shift = from[2]:Lerp(to[2], u), from[3]:Lerp(to[3], u)
				break
			end
		end
		-- The spin, rounded off a little where its speed changes.
		local turned = (spun(t - 0.02) + 2 * spun(t) + spun(t + 0.02)) / 4
		if t <= 0 or t >= 0.64 then
			turned = if t <= 0 then 0 else 1
		end
		local spin = about(trigger, CFrame.Angles(turned * 2 * math.pi, 0, 0))

		local open = keyedNumber(LEVER_OPEN, t)
		open *= open -- each move speeds up into its stop
		local swung = about(pivot, CFrame.Angles(LEVER.swing * open, 0, 0))
		-- The right hand is in the lever's loop, behind and below the pivot, and goes with it.
		local inLoop = pivot + Vector3.new(0, -0.3, 0.35)
		return {
			gun = gun,
			spin = spin,
			mag = swung,
			bolt = LEVER.slide * ratio * open,
			weight = 0,
			rightWeight = 0,
			leftShift = shift * SCALE,
			rightShift = swung * inLoop - inLoop,
		}
	end

	BodyReloads.Longscope = { at = at, LENGTH = LENGTH, SOUND = 1.714, lead = LEAD }
end

return BodyReloads
