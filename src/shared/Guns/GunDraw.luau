--!strict
-- Pull-out animations: how each kind of gun comes into the hands (River, 2026-11-12: "pull out animations for
-- everything. for the pistol, for the cards, for the ar, for the sniper"). The cards have their own, the deck
-- flourish. Pure numbers: GunView.client turns a pose into a move of the whole gun and both arms.
--
-- A pose is where the gun is, from its place at rest: x to the right, y up, z toward you, in studs; then pitch
-- (muzzle up), yaw (muzzle left) and roll (top to the left), in degrees. Each draw is a few keys, and the gun
-- glides through them on a smooth curve and ends exactly at rest.
local GunDraw = {}

export type Pose = { x: number, y: number, z: number, pitch: number, yaw: number, roll: number }
type Key = { at: number, pose: Pose }

local function key(at: number, x: number, y: number, z: number, pitch: number, yaw: number, roll: number): Key
	return { at = at, pose = { x = x, y = y, z = z, pitch = pitch, yaw = yaw, roll = roll } }
end

local REST: Pose = { x = 0, y = 0, z = 0, pitch = 0, yaw = 0, roll = 0 }
local FIELDS = { "x", "y", "z", "pitch", "yaw", "roll" }

-- The pistol and rifle follow a clip River sent of draws that feel good (2026-11-12, "try to get the take out
-- animation from the other video"). Every draw turns about the gun's own place at the hip.
local DRAWS: { [string]: { Key } } = {
	-- Straight up from under the screen with the muzzle to the sky, the forearm upright beneath it. It hangs
	-- there a moment, still drifting up, then drops level and settles.
	pistol = {
		key(0, -0.1, -1.3, 0.2, 35, 0, 6),
		key(0.1, -0.08, -0.55, 0.2, 62, 0, 8),
		key(0.2, -0.06, 0.05, 0.2, 76, 0, 9),
		key(0.4, -0.05, 0.22, 0.2, 84, 0, 9),
		key(0.52, -0.04, 0.2, 0.18, 78, 0, 8),
		key(0.64, -0.01, 0.04, 0.05, 28, 0, 3),
		key(0.72, 0, -0.03, -0.02, -4, 0, 0),
		key(0.82, 0, 0, 0, 0, 0, 0),
	},
	-- Up from under the screen, muzzle high and off to the left, the gun laid over. It is held there while the
	-- bolt is racked (a tug back and a snap forward), then swung down onto the target.
	rifle = {
		key(0, -0.5, -1.3, 0.3, 20, 30, 20),
		key(0.14, -0.46, -0.25, 0.2, 34, 38, 26),
		key(0.3, -0.45, 0.05, 0.15, 38, 40, 28),
		key(0.44, -0.42, 0.02, 0.34, 35, 38, 31),
		key(0.52, -0.45, 0.06, 0.1, 39, 40, 28),
		key(0.62, -0.42, 0.04, 0.1, 36, 38, 26),
		key(0.74, -0.08, -0.02, 0, 6, 7, 5),
		key(0.82, 0.02, -0.03, -0.04, -3, -2, -2),
		key(0.92, 0, 0, 0, 0, 0, 0),
	},
	-- Heavy, and from over the right shoulder: muzzle to the sky, swung down past level, and brought back up.
	sniper = {
		key(0, 0.9, 0.1, 1.2, 75, -15, -30),
		key(0.38, 0.32, 0.12, 0.38, 34, -7, -15),
		key(0.7, 0, -0.07, -0.06, -6, 2, 5),
		key(1, 0, 0, 0, 0, 0, 0),
	},
}

-- Which draw a gun uses: a sidearm is a pistol, a scoped gun is a sniper, and anything else is a rifle.
function GunDraw.kind(sidearm: boolean, scoped: boolean): string
	return if sidearm then "pistol" elseif scoped then "sniper" else "rifle"
end

function GunDraw.length(kind: string): number
	local keys = DRAWS[kind]
	return if keys then keys[#keys].at else 0
end

-- A smooth curve through four values, a share of the way from the second to the third.
local function curve(before: number, from: number, to: number, after: number, share: number): number
	local squared, cubed = share * share, share * share * share
	return 0.5 * (2 * from + (to - before) * share + (2 * before - 5 * from + 4 * to - after) * squared
		+ (3 * from - before - 3 * to + after) * cubed)
end

-- Where the gun is, `elapsed` seconds into its draw. At rest once the draw is over, or for a kind there isn't.
function GunDraw.at(kind: string, elapsed: number): Pose
	local keys = DRAWS[kind]
	if not keys or elapsed >= keys[#keys].at then
		return REST
	end
	if elapsed <= 0 then
		return keys[1].pose
	end
	local index = 1
	while keys[index + 1].at < elapsed do
		index += 1
	end
	local from, to = keys[index], keys[index + 1]
	local before = keys[math.max(index - 1, 1)].pose
	-- Past the last key the gun is at rest and stays there, so the curve arrives without overshooting again.
	local after = if keys[index + 2] then keys[index + 2].pose else to.pose
	local share = (elapsed - from.at) / (to.at - from.at)
	local pose: any = {}
	for _, field in FIELDS do
		pose[field] = curve((before :: any)[field], (from.pose :: any)[field], (to.pose :: any)[field], (after :: any)[field], share)
	end
	return pose
end

return GunDraw
