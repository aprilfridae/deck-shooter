-- Where everything sits on the front of a card, in the units of River's drawing (1280 by 2048, measured from
-- the top left). tools/make-card-art.py bakes its layers to these same boxes, so change both together.
-- Rects are x, y, w, h. The design is docs/specs/card-face-redesign.md.
local CardLayout = {
	WIDTH = 1280,
	HEIGHT = 2048,
	CORNER = 85,
	MARGIN = 45, -- left, right and bottom
	MONOGRAM = { x = 45, y = 69, w = 645, h = 1061 },
	RAYS = { x = 773, y = 308, w = 462, h = 172 },
	BURST_DOT = { x = 1004.84, y = 394.13, r = 43.77 },
	STAR_BIG = { x = 706, y = 443, w = 386, h = 386 },
	STAR_SMALL = { x = 948, y = 559, w = 154, h = 154 },
	-- The globe sits 170 lower than in the drawing (River, 2026-11-11). Rings are listed outer first.
	GLOBE = { x = 640, y = 1476, ry = 134.12, rings = { 397.11, 291.91, 192.04 } },
	NAME = { x = 36, y = 1800, w = 760, h = 104 }, -- its baseline is at 1891
	RARITY = { x = 41, line = 1968, size = 64, tracking = -0.02 },
	SERIAL = { right = 1235, line = 1891, size = 112 },
	BARCODE = { x = 839, y = 1919, w = 396, h = 84 },
	LOW_SERIAL = { x = 860, y = 1780, w = 400, h = 240 }, -- baseline 2003, digits 275 tall
	LOW_GLOW = { x = 800, y = 1730, w = 480, h = 318 },
	CROSSHAIR = { x = 520, y = 1356, w = 240, h = 240 }, -- centred on the globe
	MEASURE = { x = 45, y = 1140, w = 645, h = 60 },
	GRID_TILE = 80,
	SMALL_CARD = 160, -- pixels wide. Below this a card shows half the particles.
}

local ADVANCE = 0.6 -- PP Fraktion Mono's letter width, as a share of its size

-- The right edge of this rarity text.
function CardLayout.rarityRight(text: string): number
	local rarity = CardLayout.RARITY
	return rarity.x + #text * (ADVANCE + rarity.tracking) * rarity.size
end

-- How many particles a card this many pixels wide draws.
function CardLayout.count(full: number, cardWidth: number): number
	return math.max(1, if cardWidth < CardLayout.SMALL_CARD then full // 2 else full)
end

return CardLayout
