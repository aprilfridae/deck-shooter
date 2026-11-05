local harness = require("./harness")
local GlyphData = require("../src/shared/Guns/Hud/GlyphData")

local describe, it, expect = harness.describe, harness.it, harness.expect

local LETTERS = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
local DIGITS = "0123456789"
local PROMISED = {
	Number = DIGITS .. "/+",
	NumberThin = DIGITS .. "+",
	Label = LETTERS .. DIGITS .. "/:.-+",
	LabelBold = LETTERS .. DIGITS .. "/:.-+",
}
local SHEET = 1024
local APART = 2

local function close(a: any, b: any): boolean
	return a.x < b.x + b.w + APART
		and b.x < a.x + a.w + APART
		and a.y < b.y + b.h + APART
		and b.y < a.y + a.h + APART
end

describe("GlyphData", function()
	it("has every character a style promises", function()
		for style, characters in PROMISED do
			for _, character in characters:split("") do
				expect(GlyphData[style].glyphs[character] ~= nil).toBe(true)
			end
		end
	end)

	it("has a space width for every style", function()
		for style in PROMISED do
			expect(GlyphData[style].space > 0).toBe(true)
		end
	end)

	it("stays on a 1024 sheet", function()
		for style in PROMISED do
			for _, glyph in GlyphData[style].glyphs do
				expect(glyph.x >= 0 and glyph.y >= 0).toBe(true)
				expect(glyph.x + glyph.w <= SHEET and glyph.y + glyph.h <= SHEET).toBe(true)
			end
		end
	end)

	it("keeps glyphs apart", function()
		for style in PROMISED do
			local list = {}
			for _, glyph in GlyphData[style].glyphs do
				table.insert(list, glyph)
			end
			for i, a in list do
				for j = i + 1, #list do
					expect(close(a, list[j])).toBe(false)
				end
			end
		end
	end)
end)
