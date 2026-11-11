-- Reloads for the third-person body for the guns whose first-person reload isn't already keyed in the gun's own
-- space: the Energy Pistol and the Longscope. (The M57's is AkReload, shared with first person.) Each gives the same kind of
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
--   body   how the torso leans (back, to its left, tipping left), where a reload says; otherwise it takes a share of the gun's turn
--   pull   how far the whole gun is drawn in toward the body, in the body's own space (+X its right, +Z behind it)
-- A reload marked natural keeps each elbow on the side its pose has it, eases the hands and gun over a few frames,
-- and won't bend the left wrist past a limit.
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
-- First person's reload, taken from its own frames (ArmClips' reload clip) and put on the body, plus the turn
-- GunView layers over that clip for weight. The first version here was made up (the gun turned upright, a cell
-- dropped out) and River had it thrown out: "dissect the first person one".
--
-- What the clip does, read off its frames: the pistol stays flat on its side throughout. For the first half
-- second it rises and drifts in a little with the muzzle tipping up about 14 degrees, the left hand held up
-- beside it. At 0.52 to 0.56s the gun is slammed down and out, rolling further over with the muzzle dipping, as
-- the left hand whips across onto it: the slap that seats the cell (the sound's hit at 0.58s). The hand stays on
-- it to 0.64s, drags back and up off it by 0.72s (the rack), and gun and hand are back where they began by
-- 0.84s. Nothing on the gun moves: no cell leaves it and the slide stays shut.
--
-- On the body the left hand hangs at the side between reloads, so it comes up to where the clip has it over the
-- wind-up and drops away again at the end.
do
	local ArmClip = require("./ArmClip")
	local ArmClips = require("./ArmClips")
	local SoldierPose = require("./SoldierPose")

	local clips = ArmClips["Energy Pistol"]
	local clip = clips.reload
	local FIRST = clip.frames[1].gun -- the gun in the hold, in the clip's space
	local SOUND = 0.964 -- the reload itself: the clip's length and the sound's
	-- The motion carries on past the reload and settles. Ending with the reload, everything had 0.15s to get home
	-- (the left arm swinging two studs down to the side in that) and the last of it was cut off, so it jumped back
	-- to the base pose (River, 2026-11-11).
	local LENGTH = 1.4
	-- The clip's gun space to the held gun's. First person draws the pistol about 1.59 studs long and the body's
	-- is about 1.31; and the two keep their origins in different places on it, found by putting the right palm,
	-- which holds the grip in both, in the same spot.
	local SCALE = 0.82
	local ORIGIN = Vector3.new(0.018, 0.271, -0.099) -- the clip's gun origin, from the held gun's handle
	local GRIP = Vector3.new(0.125, 0.17, 0.27) -- the right palm, which the layered turn is about
	local HAND_TRAVEL = 0.25 -- the share of the gun's travel the right hand makes; the rest is left to the wrist's turn

	-- One smooth curve through a set of keys ({ seconds, values... }), as AkReload's gun rides: it passes through
	-- each key still moving, at the slope between its neighbours, and is at rest only at the two ends. Easing from
	-- key to key instead stops dead at every one, which is what made this reload look steppy.
	local function flowing(keys: { { number } }, t: number): { number }
		local count = #keys[1] - 1
		local last = keys[#keys]
		if t <= keys[1][1] or t >= last[1] then
			return table.move(if t <= keys[1][1] then keys[1] else last, 2, count + 1, 1, {})
		end
		local function slope(index: number, value: number): number
			if index == 1 or index == #keys then
				return 0
			end
			return (keys[index + 1][value] - keys[index - 1][value]) / (keys[index + 1][1] - keys[index - 1][1])
		end
		local now = {}
		for index = 2, #keys do
			local from, to = keys[index - 1], keys[index]
			if t < to[1] then
				local span = to[1] - from[1]
				local u = (t - from[1]) / span
				local u2, u3 = u * u, u * u * u
				for value = 2, count + 1 do
					now[value - 1] = from[value] * (2 * u3 - 3 * u2 + 1)
						+ slope(index - 1, value) * span * (u3 - 2 * u2 + u)
						+ to[value] * (-2 * u3 + 3 * u2)
						+ slope(index, value) * span * (u3 - u2)
				end
				break
			end
		end
		return now
	end

	-- The body through the reload, for swagger: seconds, then degrees the torso leans back, turns to its left and
	-- tips to its left. It settles back and opens toward the left hand as that comes up; swings to its right and
	-- leans in for the slap, left shoulder leading, which is what reaches the left hand to the gun; then rocks
	-- back well past upright, sways through once more and comes to rest after the reload is over.
	-- The gun stays where it is in the air while the torso moves (RemotePoses, for natural reloads).
	local BODY = {
		{ 0, 0, 0, 0 },
		{ 0.2, 3, 3, -2 },
		{ 0.42, 5, 6, -3 }, -- wound up, opened a little to the left
		{ 0.57, -10, -22, 4 }, -- the slap
		{ 0.68, -7, -15, 3 },
		{ 0.86, 5, 7, -3 }, -- rocking back past upright
		{ 1.05, -1.5, -2.5, 1 }, -- swaying through
		{ 1.22, 0.6, 0.8, -0.3 },
		{ LENGTH, 0, 0, 0 },
	}
	-- How far the gun comes in for the reload: to the body's right, up and back. Held at arm's length it is about
	-- 3.5 studs from the left shoulder and an arm is 2.3, so something has to give. At first the gun was drawn
	-- right in (1.3, then 1.5 back), which folded the gun arm and looked like hugging it to the chest; River: "make
	-- the left hand come to the right hand, not the other way around". So the body does the reaching (BODY), and
	-- this smaller pull is mostly taken up by the right shoulder going back as the torso turns.
	local PULL = Vector3.new(-0.1, -0.1, 0.7)

	-- GunView's layer over the clip (RELOADS["Energy Pistol"]): seconds, then degrees of roll, yaw and pitch and
	-- studs across, up and back, as the camera sees them.
	local LAYER = {
		{ 0, 0, 0, 0, 0, 0, 0 },
		{ 0.12, 6, -3, 5, 0, 0.02, 0.01 }, -- lifts as the cell is let go
		{ 0.3, 10, -5, -4, -0.02, -0.05, 0 }, -- and sags, lighter in the hand
		{ 0.5, 13, -6, -7, -0.02, -0.08, 0.01 }, -- winds down before the slam
		{ 0.58, 7, -3, 13, -0.01, 0.1, 0.06 }, -- SLAM: driven up and back
		{ 0.63, 11, -5, -6, -0.02, -0.07, 0 }, -- and drops past
		{ 0.68, 4, -2, -10, 0, -0.04, 0.08 }, -- the rack yanks it back, muzzle dipping
		{ 0.74, 2, -1, 9, 0, 0.05, -0.06 }, -- the slide flies home and throws it forward
		{ 0.84, -2, 1, -3, 0, -0.02, 0.01 }, -- it rocks back past ready
		{ SOUND, 0, 0, 0, 0, 0, 0 },
	}
	local function layered(t: number): CFrame
		local now = flowing(LAYER, t)
		local seen = CFrame.new(now[4], now[5], now[6]) * CFrame.Angles(math.rad(now[3]), math.rad(now[2]), math.rad(now[1]))
		-- As the camera sees it, worked into the gun's own space, which the sideways hold has turned round.
		return about(GRIP, FIRST.Rotation:Inverse() * seen * FIRST.Rotation)
	end

	-- The clip at one moment: how it has turned the gun in the hold, and where it has the left palm on the gun.
	local function clipAt(t: number): (CFrame, CFrame)
		local frame = ArmClip.sampleAt(clip, math.clamp(t, 0, SOUND)) or clip.frames[#clip.frames]
		local moved = FIRST:ToObjectSpace(frame.gun)
		local whole = CFrame.new(ORIGIN) * (CFrame.new(moved.Position) * moved.Rotation) * CFrame.new(-ORIGIN) * layered(t)
		local fromGun = frame.gun:ToObjectSpace(SoldierPose.clipPalms(clips.meshOffset, frame.bones).Left)
		return whole, CFrame.new(ORIGIN + fromGun.Position * SCALE) * fromGun.Rotation
	end
	-- Each moment is blended with the moments just before and after it, as AkReload does. The clip is 25 frames a
	-- second with straight lines between them, and its slap covers a stud in one frame; this rounds those corners.
	local TAPS = { { -1, 1 }, { -0.5, 2 }, { 0, 3 }, { 0.5, 2 }, { 1, 1 } }
	local WINDOW = 0.045 -- seconds either side

	local function at(t: number)
		local window = math.clamp(math.min(t, LENGTH - t), 0, WINDOW)
		local whole, palm, total = CFrame.identity, CFrame.identity, 0
		for _, tap in TAPS do
			local tapWhole, tapPalm = clipAt(t + tap[1] * window)
			total += tap[2]
			whole, palm = whole:Lerp(tapWhole, tap[2] / total), palm:Lerp(tapPalm, tap[2] / total)
		end
		-- The clip ends a few degrees off where it began; that is eased out after the reload.
		whole = whole:Lerp(CFrame.identity, smooth(between(t, 0.84, 1.04)))
		-- On the body the gun's turn is made at the wrist. Played whole, it carried the hand about and the entire
		-- arm shook with it, where River wanted "a short wrist shake": so the gun turns about the palm, and the
		-- hand itself travels only a share of the way.
		local carried = whole * GRIP - GRIP
		local gun = CFrame.new(carried * HAND_TRAVEL) * about(GRIP, whole.Rotation)
		-- The left hand comes up from the side over the wind-up, and goes back down slowly after the reload.
		local weight = smooth(between(t, 0.06, 0.36)) * (1 - smooth(between(t, 0.82, 1.24)))
		local pull = PULL * (smooth(between(t, 0.28, 0.54)) * (1 - smooth(between(t, 0.68, 1.02))))
		local body = flowing(BODY, t)
		return {
			gun = gun,
			mag = CFrame.identity,
			bolt = 0,
			palm = gun * palm,
			weight = weight,
			rightWeight = 0,
			pull = pull,
			body = { pitch = math.rad(body[1]), yaw = math.rad(body[2]), roll = math.rad(body[3]) },
			freeLeft = true, -- between reloads the left hand hangs at the side, not on the gun
		}
	end

	BodyReloads["Energy Pistol"] = { at = at, LENGTH = LENGTH, SOUND = SOUND, natural = true }
end

-- The Longscope -------------------------------------------------------------------------------------------------
-- The lever, timed to the sound as first person's is (GunView's RELOADS.Longscope): from the shot, the gun is
-- heaved back and up by the kick and settles; the right hand throws the lever open on the sound's click (1.03s)
-- and slams it shut on the clunk (1.32s), and each shoves the gun. The lever and bolt are the model's Lever_
-- and Bolt_ parts. First person also flips the gun over once about the trigger before the lever; that was here
-- at first and River had it taken out of third person: "get rid of the flip, and just have the lever action".
do
	local LEAD = 0.12 -- the reload starts this long after the shot the keys start at
	local LENGTH = 1.77
	local SCALE = 0.9 -- first person's gun is drawn a little bigger than the body's
	-- The lever, as GunView's LEVERS has it: in the stored model's studs from its middle.
	local LEVER = { pivot = Vector3.new(0, -1.82, 9.1), swing = math.rad(55), slide = 6.08 }

	local function tilt(roll: number, yaw: number, pitch: number, x: number, y: number, z: number): CFrame
		return CFrame.new(x * SCALE, y * SCALE, z * SCALE) * CFrame.Angles(math.rad(pitch), math.rad(yaw), math.rad(roll))
	end
	-- Seconds, and the gun's turn and shift. The lever keys are first person's own.
	local KEYS = {
		{ 0, CFrame.identity },
		{ 0.15, tilt(-6, 0, 7, 0, 0.1, 0.32) }, -- the shot heaves it back and up
		{ 0.4, tilt(3, -1, -2, 0, -0.03, 0.06) }, -- it drops back past ready
		{ 0.7, tilt(8, -3, 1, -0.02, 0.06, 0.03) }, -- and is canted over for the lever
		{ 0.92, tilt(11, -4, 2.5, -0.03, 0.05, 0.03) }, -- a small wind-up
		{ 1.03, tilt(9.5, -3, 4.5, -0.02, -0.04, -0.05) }, -- CLICK: the lever hits its stop
		{ 1.1, tilt(10, -3, 2, -0.02, -0.02, -0.035) },
		{ 1.2, tilt(10.5, -4, 2, -0.03, -0.025, -0.03) }, -- held open
		{ 1.32, tilt(6, -2, -3, -0.01, 0.045, 0.065) }, -- CLUNK: slammed shut
		{ 1.42, tilt(3, -1, -0.5, 0, 0.015, 0.03) },
		{ 1.55, tilt(-1, 0.3, -0.5, 0.002, -0.006, 0.015) },
		{ LENGTH, CFrame.identity },
	}
	local LEVER_OPEN = { { 0.92, 0 }, { 1.03, 1 }, { 1.2, 1 }, { 1.32, 0 } }

	local function at(t: number, fit: Fit?)
		local middle = if fit then fit.middle else Vector3.zero
		local ratio = if fit then fit.ratio else 0.0375
		local pivot = middle + LEVER.pivot * ratio
		local open = keyedNumber(LEVER_OPEN, t)
		open *= open -- each move speeds up into its stop
		local swung = about(pivot, CFrame.Angles(LEVER.swing * open, 0, 0))
		-- The right hand is in the lever's loop, behind and below the pivot, and goes with it.
		local inLoop = pivot + Vector3.new(0, -0.3, 0.35)
		return {
			gun = keyedFrame(KEYS, t),
			mag = swung,
			bolt = LEVER.slide * ratio * open,
			weight = 0,
			rightWeight = 0,
			rightShift = swung * inLoop - inLoop,
		}
	end

	BodyReloads.Longscope = { at = at, LENGTH = LENGTH, SOUND = 1.714, lead = LEAD, natural = true }
end

return BodyReloads
