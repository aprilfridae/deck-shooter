-- How the Outpost panels move. A heavy sheet: it swings past its mark on the way in and settles,
-- and pulls back a touch before it drops away. Fading copies between frames give it motion blur.
local PanelMotion = {
	FPS = 30,
	DURATION = 0.5, -- seconds
	COPIES = 3,
}

local OVERSHOOT = 1.1 -- higher swings further past the mark
local PULL_BACK = 0.6 -- higher gathers further before closing
local COPY_TRANSPARENCY = { 0.55, 0.72, 0.87 } -- nearest the panel first
local CHARACTER_PLACE = 0.5 -- of the way from the screen's centre to its left edge

-- How far through a move it is, from 0 to 1, stepped to whole frames.
function PanelMotion.held(elapsed: number): number
	local frame = math.floor(elapsed * PanelMotion.FPS + 1e-6)
	return math.min(frame / PanelMotion.FPS / PanelMotion.DURATION, 1)
end

local function swingIn(progress: number): number
	local rest = progress - 1
	return 1 + (OVERSHOOT + 1) * rest ^ 3 + OVERSHOOT * rest ^ 2
end

local function dropAway(progress: number): number
	return (PULL_BACK + 1) * progress ^ 3 - PULL_BACK * progress ^ 2
end

-- Where the panel is at this point of a move, with 0 closed and 1 open.
function PanelMotion.share(from: number, to: number, progress: number): number
	local eased = if to > from then swingIn(progress) else dropAway(progress)
	return from + (to - from) * eased
end

-- The copies left between the last frame and this one, nearest the panel first.
function PanelMotion.trail(from: number, to: number): { { share: number, transparency: number } }
	local trail = {}
	if from == to then
		return trail
	end
	for index = 1, PanelMotion.COPIES do
		table.insert(trail, {
			share = to + (from - to) * index / (PanelMotion.COPIES + 1),
			transparency = COPY_TRANSPARENCY[index],
		})
	end
	return trail
end

-- How far the view's centre moves left, as a shear per unit of depth.
function PanelMotion.viewShift(verticalFov: number, aspect: number): number
	return math.tan(math.rad(verticalFov) / 2) * aspect * CHARACTER_PLACE
end

return PanelMotion
