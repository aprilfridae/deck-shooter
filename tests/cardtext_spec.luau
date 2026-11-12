local harness = require("./harness")
local Cards = require("../src/shared/CardCore/Cards")
local CardText = require("../src/shared/CardCore/CardText")
local GlyphData = require("../src/shared/Guns/Hud/GlyphData")
local Tier = require("../src/shared/CardCore/Tier")

local describe, it, expect = harness.describe, harness.it, harness.expect

local function drawable(text: string): boolean
	for index = 1, #text do
		local letter = string.sub(text, index, index)
		if letter ~= " " and not GlyphData.Label.glyphs[letter] then
			return false
		end
	end
	return true
end

local function find(stats: { any }, label: string): string?
	for _, stat in stats do
		if stat.label == label then
			return stat.value
		end
	end
	return nil
end

describe("CardText", function()
	it("describes every card in letters the font can draw", function()
		for _, id in Cards.ids do
			expect(drawable(CardText.blurb(id))).toBe(true)
			for _, tier in Tier.order do
				local stats = CardText.stats(id, tier)
				expect(#stats > 0).toBe(true)
				for _, stat in stats do
					expect(drawable(stat.label)).toBe(true)
					expect(drawable(stat.value)).toBe(true)
				end
			end
		end
	end)

	it("has nothing to say about a card with no words yet, and doesn't error", function()
		expect(CardText.blurb("gone")).toBe("")
		expect(#CardText.stats("gone", "Field")).toBe(0)
	end)

	it("reads each stat at the card's tier", function()
		local field = CardText.stats("phase_dash", "Field")
		expect(find(field, "DISTANCE")).toBe("8 STUDS")
		expect(find(field, "COOLDOWN")).toBe("16 S")
		expect(find(CardText.stats("phase_dash", "Prototype"), "DISTANCE")).toBe("16 STUDS")
		expect(find(CardText.stats("overclock", "BlackSite"), "FIRE RATE")).toBe("+22 PCT")
		expect(find(CardText.stats("aegis_shell", "Prototype"), "DURATION")).toBe("5 S")
	end)

	it("wraps on spaces and keeps every line within the width", function()
		local lines = CardText.wrap("A BUBBLE THAT TAKES EVERY HIT", 12)
		expect(lines[1]).toBe("A BUBBLE")
		expect(table.concat(lines, " ")).toBe("A BUBBLE THAT TAKES EVERY HIT")
		for _, line in lines do
			expect(#line <= 12).toBe(true)
		end
	end)

	it("says who owns a card", function()
		expect(CardText.copies(3)).toBe("X3")
		expect(CardText.copies(0)).toBe("NOT OWNED")
	end)
end)
