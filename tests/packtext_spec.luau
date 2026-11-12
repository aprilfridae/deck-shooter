local harness = require("./harness")
local GlyphData = require("../src/shared/Guns/Hud/GlyphData")
local PackText = require("../src/shared/CardCore/PackText")

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

describe("PackText", function()
	it("names packs as players know them", function()
		expect(PackText.name("Field")).toBe("FIELD")
		expect(PackText.name("BlackSite")).toBe("REDLINE")
		expect(PackText.name("ZeroDay")).toBe("ZERO-DAY")
	end)

	it("writes odds without a percent sign", function()
		expect(PackText.odds(0.8)).toBe("80 PCT")
		expect(PackText.odds(0.0398)).toBe("3.98 PCT")
		expect(PackText.odds(0.0002)).toBe("1 IN 5000")
		expect(PackText.odds(0.00035)).toBe("1 IN 2857")
		expect(PackText.odds(1)).toBe("100 PCT")
		expect(PackText.odds(0)).toBe("0 PCT")
	end)

	it("writes income like the spec", function()
		expect(PackText.income(3.44)).toBe("+3.4 CR/S")
		expect(PackText.income(0)).toBe("+0 CR/S")
		expect(PackText.income(1234567)).toBe("+1.23M CR/S")
	end)

	it("shortens big Credits", function()
		expect(PackText.credits(950)).toBe("950 CR")
		-- The Outpost's balance shortens from a thousand up, and carries no "CR".
		expect(PackText.balance(16)).toBe("16")
		expect(PackText.balance(999.7)).toBe("999")
		expect(PackText.balance(1000)).toBe("1K")
		expect(PackText.balance(1125)).toBe("1.12K")
		expect(PackText.balance(12500)).toBe("12.5K")
		expect(PackText.balance(1250000)).toBe("1.25M")
		expect(PackText.balance(3200000000)).toBe("3.2B")
		expect(PackText.balance(4e12)).toBe("4T")
		expect(PackText.credits(9999)).toBe("9999 CR")
		expect(PackText.credits(12500)).toBe("12.5K CR")
		expect(PackText.credits(999999)).toBe("999K CR")
		expect(PackText.credits(1250000)).toBe("1.25M CR")
		expect(PackText.credits(3200000000)).toBe("3.2B CR")
	end)

	it("shows a saved Open All on its button", function()
		expect(PackText.openAll(0)).toBe("OPEN ALL")
		expect(PackText.openAll(2)).toBe("OPEN ALL X2")
	end)

	it("shows luck", function()
		expect(PackText.luck(0)).toBe("LUCK X1")
		expect(PackText.luck(5)).toBe("LUCK X1.75")
	end)

	it("only uses letters the font can draw", function()
		for _, text in
			{
				PackText.odds(0.0398),
				PackText.odds(0.0002),
				PackText.income(1.5),
				PackText.income(2 ^ 40),
				PackText.credits(1250000),
				PackText.credits(2 ^ 53),
				PackText.luck(5),
				PackText.name("ZeroDay"),
			}
		do
			expect(drawable(text)).toBe(true)
		end
	end)
end)
