-- The maths behind the first-person arms.
local MIN_REACH = 0.01

local ArmPose = {}

-- Which held pose the moment falls in, for animation that steps like stop motion.
function ArmPose.step(now: number, fps: number): number
	return math.floor(now * fps)
end

-- Six amounts from -1 to 1, the same all through a step and different on the next. Three to move by and three
-- to turn by. Each seed shakes on its own, so things jitter separately.
function ArmPose.shake(step: number, seed: number): (number, number, number, number, number, number)
	local function noise(index: number): number
		local value = math.sin(step * 12.9898 + seed * 78.233 + index * 37.719) * 43758.5453
		return (value - math.floor(value)) * 2 - 1
	end
	return noise(1), noise(2), noise(3), noise(4), noise(5), noise(6)
end

-- Where the elbow goes on a two-bone arm: how far along the shoulder-to-hand line,
-- and how far out from it. upper and fore are bone lengths, reach is the hand's distance.
function ArmPose.elbow(upper: number, fore: number, reach: number): (number, number)
	local distance = math.clamp(reach, math.max(MIN_REACH, math.abs(upper - fore)), upper + fore)
	local along = (upper * upper - fore * fore + distance * distance) / (2 * distance)
	return along, math.sqrt(math.max(upper * upper - along * along, 0))
end

return ArmPose
