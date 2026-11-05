-- Works out where each letter of a piece of HUD text goes on screen.
local GlyphData = require("./GlyphData")

local TypeLayout = {}

export type Placed = {
	x: number,
	y: number,
	w: number,
	h: number,
	rectX: number,
	rectY: number,
	rectW: number,
	rectH: number,
}

-- The text's width and its drawn letters at display size, from the start of the baseline.
-- A character the style doesn't have takes up a space and draws nothing.
function TypeLayout.lay(text: string, style: string, size: number, tracking: number): (number, { Placed })
	local font = GlyphData[style]
	local scale = size / font.source
	local placed: { Placed } = {}
	if text == "" then
		return 0, placed
	end
	local characters = text:upper():split("")
	local pen = 0
	for index, character in characters do
		local glyph = font.glyphs[character]
		if glyph then
			table.insert(placed, {
				x = pen + glyph.ox * scale,
				y = glyph.oy * scale,
				w = glyph.w * scale,
				h = glyph.h * scale,
				rectX = glyph.x,
				rectY = glyph.y,
				rectW = glyph.w,
				rectH = glyph.h,
			})
		end
		pen += (if glyph then glyph.advance else font.space) * scale
		if index < #characters then
			pen += tracking
		end
	end
	return pen, placed
end

return TypeLayout
