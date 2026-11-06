-- The third-person body, in the same stop-motion style as the first-person arms: every joint
-- is held for a frame at frameRate, which matches the arms' run clips (10 to 13.33 fps).
-- Angles are degrees from the rig's rest pose, whose arms angle out and down.
export type Angles = { x: number, y: number, z: number }
type Key = { number } -- time, value

local BodyPose = {}

BodyPose.frameRate = 12

-- The lowest limb sits 1.61 studs up with the slide pose on and no drop, so this stops short of it.
BodyPose.slideDrop = 1.5 -- studs the hips sink
BodyPose.slideLean = 50 -- degrees back from upright
BodyPose.crouchDrop = 1.5

-- Feet first, leaning back, one leg out, one knee up and one hand down behind.
BodyPose.slide = {
	Waist = { x = -18, y = 0, z = 0 },
	Neck = { x = -22, y = 0, z = 0 },
	RightHip = { x = 36, y = 0, z = 0 },
	RightKnee = { x = -12, y = 0, z = 0 },
	RightAnkle = { x = -10, y = 0, z = 0 },
	LeftHip = { x = 60, y = 0, z = -8 },
	LeftKnee = { x = -70, y = 0, z = 0 },
	LeftAnkle = { x = 20, y = 0, z = 0 },
	LeftShoulder = { x = -30, y = 0, z = 45 },
	LeftElbow = { x = 15, y = 0, z = 0 },
	RightShoulder = { x = 35, y = 0, z = -40 },
	RightElbow = { x = 40, y = 0, z = 0 },
} :: { [string]: Angles }

-- Knees bent far enough that lowering the hips doesn't push the feet through the floor.
BodyPose.crouch = {
	Waist = { x = -15, y = 0, z = 0 },
	Neck = { x = 10, y = 0, z = 0 },
	RightHip = { x = 65, y = 0, z = 0 },
	RightKnee = { x = -130, y = 0, z = 0 },
	RightAnkle = { x = 65, y = 0, z = 0 },
	LeftHip = { x = 65, y = 0, z = 0 },
	LeftKnee = { x = -130, y = 0, z = 0 },
	LeftAnkle = { x = 65, y = 0, z = 0 },
} :: { [string]: Angles }

-- Each joint twitches on its own every held frame, by up to this many degrees. These are the
-- arms' numbers, scaled up by jitterScale so they still read from third-person distance.
BodyPose.jitterScale = 3
BodyPose.jitter = {
	Root = 0.6,
	Waist = 0.4,
	Neck = 0.4,
	LeftShoulder = 0.4,
	RightShoulder = 0.4,
	LeftElbow = 0.4,
	RightElbow = 0.4,
	LeftWrist = 1,
	RightWrist = 1,
	LeftHip = 0.4,
	RightHip = 0.4,
	LeftKnee = 0.4,
	RightKnee = 0.4,
	LeftAnkle = 1,
	RightAnkle = 1,
} :: { [string]: number }
BodyPose.idleJitter = 0.35 -- share left while standing, as on the arms

-- The weight goes past the pose, then settles back.
local SLIDE_IN: { Key } = { { 0, 0 }, { 0.05, 0.55 }, { 0.1, 1.12 }, { 0.17, 0.94 }, { 0.25, 1 } }
local SLIDE_OUT: { Key } = { { 0, 1 }, { 0.06, 0.7 }, { 0.14, 0.2 }, { 0.2, 0 } }
local LAND_DIP: { Key } = { { 0, 0 }, { 0.08, 0.35 }, { 0.17, 0.15 }, { 0.3, 0 } }
local RUN_LEAN_SPEED = 40 -- studs per second at full lean
local RUN_LEAN = 12 -- degrees forward

local function sample(keys: { Key }, t: number): number
	for index = 2, #keys do
		local from, to = keys[index - 1], keys[index]
		if t < to[1] then
			local share = math.max(t - from[1], 0) / (to[1] - from[1])
			return from[2] + (to[2] - from[2]) * share
		end
	end
	return keys[#keys][2]
end

function BodyPose.frame(seconds: number): number
	return math.floor(seconds * BodyPose.frameRate)
end

function BodyPose.slideIn(since: number): number
	return sample(SLIDE_IN, since)
end

function BodyPose.slideOut(since: number, from: number): number
	return sample(SLIDE_OUT, since) * from
end

function BodyPose.landDip(since: number): number
	return sample(LAND_DIP, since)
end

-- Degrees of forward lean at this flat speed.
function BodyPose.runLean(speed: number): number
	return math.min(speed / RUN_LEAN_SPEED, 1) * RUN_LEAN
end

return BodyPose
