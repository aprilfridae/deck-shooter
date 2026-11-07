-- How the Outpost panels move. A heavy sheet: it swings past its mark on the way in and settles,
-- and pulls back a touch before it drops away. Fading copies between frames give it motion blur.
local PanelMotion = {
	FPS = 30,
	DURATION = 0.5, -- seconds
	COPIES = 8,
	SHAKE_TIME = 7 / 30, -- seconds, in whole frames
	VIEW_SCALE = 0.75, -- the sheared camera is shrunk by this, which the picture doesn't show
	EXPAND_TIME = 6 / 30, -- seconds, in whole frames, for a row to open
	MOST_SHIFT = 1.2, -- at that scale Roblox accepts up to 1.25 facing any way, measured in Play
}

local OVERSHOOT = 1.1 -- higher swings further past the mark
local PULL_BACK = 0.6 -- higher gathers further before closing
local COPY_NEAREST = 0.5 -- transparency of the copy by the panel
local COPY_FARTHEST = 0.95
local COPY_REACH = 1.6 -- how many frames of travel the copies stretch back over
local CHARACTER_PLACE = 0.5 -- of the way from the screen's centre to its left edge
local BLUR_PER_TRAVEL = 130 -- blur size for each share of the panel crossed in one frame
local MOST_BLUR = 32
local LEAN_PER_TRAVEL = math.rad(7.5) -- tilt for each share of the panel crossed in one frame
local GLOW_PER_TRAVEL = 5 -- glow for each share of the panel crossed in one frame
local SHAKE = 0.022 -- how far the landing throws the view, per unit of depth
local SHAKE_HEIGHT = 0.6 -- of the sideways throw
local SHAKE_LEAN = math.rad(0.6)
local DECODE_STEP = 2 -- characters the text gains each frame
local DECODE_FRONT = 8 -- characters of noise at its leading edge
local NOISE = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789/:.-+_>" -- all drawn by the Label font

-- How far through a move it is, from 0 to 1, stepped to whole frames.
function PanelMotion.held(elapsed: number): number
	local frame = math.floor(elapsed * PanelMotion.FPS + 1e-6)
	return math.min(frame / PanelMotion.FPS / PanelMotion.DURATION, 1)
end

-- How open a row is, from 0 to 1, stepped to whole frames and easing out.
function PanelMotion.expand(elapsed: number): number
	local frame = math.floor(elapsed * PanelMotion.FPS + 1e-6)
	local progress = math.min(frame / PanelMotion.FPS / PanelMotion.EXPAND_TIME, 1)
	return 1 - (1 - progress) ^ 3
end

-- The text as it stands this long into typing out: settled letters with a front of noise ahead of
-- them. The noise comes from the frame number, so it holds still for a whole frame.
function PanelMotion.decode(text: string, elapsed: number): string
	local frame = math.floor(elapsed * PanelMotion.FPS + 1e-6)
	local reached = frame * DECODE_STEP
	local shown = {}
	for index = 1, math.min(reached, #text) do
		local letter = string.sub(text, index, index)
		if index > reached - DECODE_FRONT and letter ~= " " and letter ~= "\n" then
			local pick = (index * index * 7 + frame * 23) % #NOISE + 1
			letter = string.sub(NOISE, pick, pick)
		end
		table.insert(shown, letter)
	end
	return table.concat(shown)
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
			share = to + (from - to) * COPY_REACH * index / PanelMotion.COPIES,
			transparency = COPY_NEAREST + (COPY_FARTHEST - COPY_NEAREST) * (index - 1) / (PanelMotion.COPIES - 1),
		})
	end
	return trail
end

-- How far the view's centre moves left, as a shear per unit of depth.
function PanelMotion.viewShift(verticalFov: number, aspect: number): number
	return math.tan(math.rad(verticalFov) / 2) * aspect * CHARACTER_PLACE
end

-- Past a limit that changes with the way the camera faces, Roblox straightens a sheared camera and
-- the picture snaps back to the centre. Shrinking the camera raises the limit; this stays under it.
function PanelMotion.safeShift(shift: number): number
	return math.clamp(shift, -PanelMotion.MOST_SHIFT, PanelMotion.MOST_SHIFT)
end

-- How much the view blurs for this much travel in one frame of the panel.
function PanelMotion.viewBlur(travel: number): number
	return math.min(math.abs(travel) * BLUR_PER_TRAVEL, MOST_BLUR)
end

-- How far the view leans, in radians, for this much travel in one frame of the panel.
function PanelMotion.viewLean(travel: number): number
	return travel * LEAN_PER_TRAVEL
end

-- How strongly things glow for this much travel in one frame of the panel, from 0 to 1.
function PanelMotion.glow(travel: number): number
	return math.min(math.abs(travel) * GLOW_PER_TRAVEL, 1)
end

-- The view's throw this long after a closing panel lands: side to side, fading out in held frames.
function PanelMotion.landShake(elapsed: number): { x: number, y: number, lean: number }
	local frame = math.floor(elapsed * PanelMotion.FPS + 1e-6)
	local frames = math.round(PanelMotion.SHAKE_TIME * PanelMotion.FPS)
	if frame < 0 or frame >= frames then
		return { x = 0, y = 0, lean = 0 }
	end
	local fade = 1 - frame / frames
	local side = if frame % 2 == 0 then 1 else -1
	return {
		x = SHAKE * fade * side,
		y = SHAKE * SHAKE_HEIGHT * fade * (if frame % 3 == 0 then 1 else -1),
		lean = SHAKE_LEAN * fade * -side,
	}
end

return PanelMotion
