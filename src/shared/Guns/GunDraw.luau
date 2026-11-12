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
	-- Up from under the screen to the middle, muzzle high and a little left, turned at the wrist (see `wrist`). It
	-- is held there while the left hand racks the slide, then punched out to its place. Seen in Play by Claude,
	-- held still at each moment (workspace's PinDraw attribute): with the muzzle straight up, or turned with the
	-- whole view, the hands were a mass at the bottom of the screen and the gun could hardly be seen.
	pistol = {
		key(0, -0.1, -1.1, 0.1, 20, 5, 0),
		key(0.16, -0.18, -0.1, 0.05, 40, 15, 0),
		key(0.3, -0.2, 0.15, 0, 46, 20, 0),
		key(0.36, -0.2, 0.15, 0, 45, 20, 0),
		key(0.46, -0.2, 0.12, 0.12, 40, 20, 0), -- the slide is racked: the gun is tugged back
		key(0.51, -0.2, 0.16, -0.04, 48, 20, 0), -- and let go: it snaps forward
		key(0.6, -0.18, 0.13, 0, 42, 18, 0),
		key(0.72, 0, -0.02, -0.05, -4, -2, 0),
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

-- The left hand's own part in a draw (River, 2026-11-12: "for the pistol like actually cock the gun"): at each
-- time, how much of the hand is on the slide (0 is wherever the hold has it, 1 is on the slide), how far back
-- along the gun the hand has gone and how far back the slide is, both in slide travels (1 is all the way back).
-- The slide goes back with the hand and flies home the moment it is let go ("it needs to slide the thing back"). The Energy Pistol is held in one hand with the other far off to
-- the side, so the hand has to come right across to the gun: a nudge from where it rests never reached it.
local HANDS: { [string]: { { at: number, on: number, back: number, slide: number } } } = {
	-- Whipped across onto the slide, dragged back with it, let go, and away again.
	pistol = {
		{ at = 0.16, on = 0, back = 0, slide = 0 },
		{ at = 0.36, on = 1, back = 0, slide = 0 },
		{ at = 0.46, on = 1, back = 1, slide = 1 },
		{ at = 0.5, on = 0.85, back = 1.3, slide = 0 },
		{ at = 0.76, on = 0, back = 0, slide = 0 },
	},
}

-- Where the left hand has got to. Nil when it is simply where the hold has it.
function GunDraw.hand(kind: string, elapsed: number): { on: number, back: number, slide: number }?
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
		on = from.on + (to.on - from.on) * share,
		back = from.back + (to.back - from.back) * share,
		-- The slide's own spring throws it home: no easing out of the start.
		slide = from.slide + (to.slide - from.slide) * (if to.slide < from.slide then share * share else share),
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

-- Whether a draw's turn is made at the wrist of the hand on the grip (a gun held in one hand), not by the whole
-- view, arms and all.
function GunDraw.wrist(kind: string): boolean
	return kind == "pistol"
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
