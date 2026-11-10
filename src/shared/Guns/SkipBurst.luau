--!strict
-- The burst that pops off the deck when the card flourish is cut short. It's drawn flat and hard-edged like the HUD:
-- a square outline that jumps outward in beats, eight dashes shot along the axes and diagonals, and blocks of static
-- on a grid. Everything is a flat rectangle facing the eye, placed in studs from the middle of the burst.
local SkipBurst = {}

local LENGTH = 0.32 -- seconds it lasts
local STEPS = 8 -- beats the outline and the static move on
local EDGES = 4 -- sides of the outline
local RAYS = 8
local BITS = 10
local COUNT = EDGES + RAYS + BITS
local LINE = 0.008 -- how thick the outline is
local FRAME_FROM = 0.1 -- half the outline's side, at the start and the end
local FRAME_TO = 0.38
local RAY_FROM = 0.12 -- how far out the dashes start and end
local RAY_TO = 0.62
local RAY_LENGTH = 0.2 -- a dash at the start; it shortens to nothing
local RAY_LINE = 0.014
local GRID = 0.07 -- the static's grid
local BIT = 0.035 -- one block of static
local REACH = 4 -- grid squares the static reaches each way
local DARK = { [2] = true, [5] = true } -- beats the outline drops out for

export type Piece = {
	x: number,
	y: number,
	width: number,
	height: number,
	turn: number, -- radians anticlockwise
	tone: string, -- a Palette colour
	shown: boolean,
}

-- The same -1 to 1 for the same n, and nothing alike for the next.
local function noise(n: number): number
	return (math.sin(n * 12.9898) * 43758.5453) % 2 - 1
end

-- Every piece, share of the way through (0 to 1). Always COUNT of them, in the same order with the same tones.
function SkipBurst.at(share: number): { Piece }
	local live = share >= 0 and share < 1
	local through = math.clamp(share, 0, 1)
	local step = math.min(math.floor(through * STEPS), STEPS - 1)
	local pieces: { Piece } = table.create(COUNT)

	local jumped = 1 - (1 - (step + 1) / STEPS) ^ 2
	local half = FRAME_FROM + (FRAME_TO - FRAME_FROM) * jumped
	local framed = live and not DARK[step]
	for edge = 1, EDGES do
		local flat = edge <= 2 -- top and bottom, then left and right
		local side = if edge % 2 == 1 then 1 else -1
		table.insert(pieces, {
			x = if flat then 0 else side * half,
			y = if flat then side * half else 0,
			width = if flat then half * 2 + LINE else LINE,
			height = if flat then LINE else half * 2 + LINE,
			turn = 0,
			tone = "Bone",
			shown = framed,
		})
	end

	local out = 1 - (1 - through) ^ 3
	local reach = RAY_FROM + (RAY_TO - RAY_FROM) * out
	local length = RAY_LENGTH * (1 - through)
	for ray = 1, RAYS do
		local turn = (ray - 1) * math.pi / 4
		table.insert(pieces, {
			x = math.cos(turn) * reach,
			y = math.sin(turn) * reach,
			width = math.max(length, 0.001),
			height = RAY_LINE,
			turn = turn,
			tone = if ray % 2 == 1 then "DataCyan" else "SignalAcid",
			shown = live,
		})
	end

	for bit = 1, BITS do
		table.insert(pieces, {
			x = math.round(noise(bit * 3.1) * REACH) * GRID,
			y = math.round(noise(bit * 7.7) * REACH) * GRID,
			width = BIT,
			height = BIT,
			turn = 0,
			tone = if bit % 3 == 0 then "SignalAcid" elseif bit % 3 == 1 then "DataCyan" else "Bone",
			shown = live and noise(bit + step * 17.3) > 0,
		})
	end
	return pieces
end

SkipBurst.LENGTH = LENGTH
SkipBurst.COUNT = COUNT
SkipBurst.REACH = RAY_TO + RAY_LENGTH

return SkipBurst
