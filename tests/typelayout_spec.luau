local harness = require("./harness")
local GlyphData = require("../src/shared/Guns/Hud/GlyphData")
local TypeLayout = require("../src/shared/Guns/Hud/TypeLayout")

local describe, it, expect = harness.describe, harness.it, harness.expect

local NUMBER_SCALE = 46 / GlyphData.Number.source
local EIGHT = GlyphData.Number.glyphs["8"].advance * NUMBER_SCALE

describe("TypeLayout.lay", function()
	it("measures by advance", function()
		local width = TypeLayout.lay("88", "Number", 46, 0)
		expect(width).toBeCloseTo(2 * EIGHT)
	end)

	it("adds tracking between characters only", function()
		local width = TypeLayout.lay("88", "Number", 46, 3)
		expect(width).toBeCloseTo(2 * EIGHT + 3)
	end)

	it("uppercases", function()
		local lower = TypeLayout.lay("m57", "Label", 12, 0)
		local upper = TypeLayout.lay("M57", "Label", 12, 0)
		expect(lower).toBeCloseTo(upper)
	end)

	it("gives an unknown character a space's width and draws nothing", function()
		local width, placed = TypeLayout.lay("A", "Number", 46, 0)
		expect(width).toBeCloseTo(GlyphData.Number.space * NUMBER_SCALE)
		expect(#placed).toBe(0)
	end)

	it("draws nothing for a space", function()
		local _, placed = TypeLayout.lay("A B", "Label", 12, 0)
		expect(#placed).toBe(2)
	end)

	it("handles empty text", function()
		local width, placed = TypeLayout.lay("", "Label", 12, 2)
		expect(width).toBe(0)
		expect(#placed).toBe(0)
	end)

	it("places each glyph by its offset and keeps its sheet rectangle", function()
		local _, placed = TypeLayout.lay("88", "Number", 46, 3)
		local glyph = GlyphData.Number.glyphs["8"]
		expect(placed[2].x).toBeCloseTo(EIGHT + 3 + glyph.ox * NUMBER_SCALE)
		expect(placed[2].y).toBeCloseTo(glyph.oy * NUMBER_SCALE)
		expect(placed[2].w).toBeCloseTo(glyph.w * NUMBER_SCALE)
		expect(placed[2].rectX).toBe(glyph.x)
		expect(placed[2].rectH).toBe(glyph.h)
	end)
end)
