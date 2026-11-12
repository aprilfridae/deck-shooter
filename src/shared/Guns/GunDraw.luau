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

local DRAWS: { [string]: { Key } } = {
	-- A quick draw off the right hip: the arms swing up from hanging, a touch past level, and settle. It turns
	-- about the shoulder (see PIVOTS), and barely slides: turned about the gun itself, the shoulders swung round
	-- and it looked like the whole torso was rotating (River, 2026-11-12).
	-- With swagger (River, 2026-11-12): it comes up canted over on its side, punches out a touch past level, and
	-- the wrist rolls it upright last.
	pistol = {
		key(0, 0.1, -0.25, 0.15, -62, -10, 22),
		key(0.14, 0.04, -0.08, 0.05, -24, -6, 28),
		key(0.25, 0, 0.02, -0.04, 7, 3, 14),
		key(0.34, 0, 0, 0.01, -2, -1, -4),
		key(0.44, 0, 0, 0, 0, 0, 0),
	},
	-- Up from low on the left, across the body as if off a sling, canted over. With swagger: it swings past, muzzle
	-- high and tipped the other way, then drops back into the shoulder.
	rifle = {
		key(0, -0.7, -1.25, 0.45, -35, 40, 35),
		key(0.2, -0.14, -0.3, 0.14, -8, 16, 22),
		key(0.34, 0.04, 0.09, -0.1, 9, -5, -9),
		key(0.45, 0, -0.03, 0.05, -2, 1, 3),
		key(0.56, 0, 0, 0, 0, 0, 0),
	},
	-- Heavy, and from over the right shoulder: muzzle to the sky, swung down past level, and brought back up.
	sniper = {
		key(0, 0.9, 0.1, 1.2, 75, -15, -30),
		key(0.28, 0.32, 0.12, 0.38, 34, -7, -15),
		key(0.52, 0, -0.07, -0.06, -6, 2, 5),
		key(0.75, 0, 0, 0, 0, 0, 0),
	},
}

-- The point a draw turns about, from the camera: x right, y up, z toward you. A kind not listed turns about the
-- gun's own place at the hip.
local PIVOTS: { [string]: { x: number, y: number, z: number } } = {
	pistol = { x = 0.35, y = -0.45, z = 0.4 }, -- the right shoulder
}

function GunDraw.pivot(kind: string): { x: number, y: number, z: number }?
	return PIVOTS[kind]
end

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
