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
		key(0.36, -0.05, 0.21, 0.2, 83, 0, 9),
		key(0.44, -0.05, 0.2, 0.32, 80, 0, 9), -- the slide is racked: the gun is tugged back
		key(0.5, -0.04, 0.21, 0.16, 82, 0, 8), -- and let go: it snaps forward
		key(0.56, -0.04, 0.2, 0.18, 78, 0, 8),
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
		key(0.5, -0.42, 0.02, 0.34, 35, 38, 31),
		key(0.56, -0.45, 0.06, 0.1, 39, 40, 28),
		key(0.64, -0.42, 0.04, 0.1, 36, 38, 26),
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

-- The left hand's own part in a draw: where it is from its place on the gun, in the gun's space (x right, y up,
-- z toward you), at each time. River, 2026-11-12: "for the pistol like actually cock the gun".
local HANDS: { [string]: { { at: number, x: number, y: number, z: number } } } = {
	-- Off the grip, over the back of the slide, pulled back with it, let go, and back to the grip.
	pistol = {
		{ at = 0.2, x = 0, y = 0, z = 0 },
		{ at = 0.36, x = 0.09, y = 0.32, z = 0 },
		{ at = 0.44, x = 0.09, y = 0.32, z = 0.26 },
		{ at = 0.5, x = 0.04, y = 0.3, z = 0.3 },
		{ at = 0.7, x = 0, y = 0, z = 0 },
	},
}

-- Where the left hand has got to, from its place on the gun. Nil when it is simply on the gun.
function GunDraw.hand(kind: string, elapsed: number): { x: number, y: number, z: number }?
	local keys = HANDS[kind]
	if not keys or elapsed <= keys[1].at or elapsed >= keys[#keys].at then
		return nil
	end
	local index = 1
	while keys[index + 1].at < elapsed do
		index += 1
	end
	local from, to = keys[index], keys[index + 1]
	local share = (elapsed - from.at) / (to.at - from.at)
	share = share * share * (3 - 2 * share)
	return {
		x = from.x + (to.x - from.x) * share,
		y = from.y + (to.y - from.y) * share,
		z = from.z + (to.z - from.z) * share,
	}
end

-- A gun whose bolt is racked in its draw (River, 2026-11-12: "make the hands actually like. pull the tab"): when
-- the rack starts, and how fast the gun's own rack is played.
local RACKS: { [string]: { from: number, rate: number } } = {
	rifle = { from = 0.2, rate = 0.6 },
}

-- How far into its rack a gun is, in the rack's own seconds. Nil before it starts or for a kind that has none.
function GunDraw.rack(kind: string, elapsed: number): number?
	local rack = RACKS[kind]
	if not rack or elapsed < rack.from then
		return nil
	end
	return (elapsed - rack.from) * rack.rate
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
