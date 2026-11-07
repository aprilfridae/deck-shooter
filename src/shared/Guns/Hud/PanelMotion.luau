-- How the Outpost panels move: held frames at a low frame rate, with fading copies between them.
local PanelMotion = {
	FPS = 12,
	FRAMES = 4, -- held frames from closed to open
	COPIES = 3,
}

local COPY_TRANSPARENCY = { 0.55, 0.72, 0.87 } -- nearest the panel first

-- How far along a move is, from 0 to 1, stepped to whole frames.
function PanelMotion.held(elapsed: number): number
	local frame = math.floor(elapsed * PanelMotion.FPS + 1e-6)
	return math.min(frame, PanelMotion.FRAMES) / PanelMotion.FRAMES
end

-- The copies left between the last held frame and this one, nearest the panel first.
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

return PanelMotion
