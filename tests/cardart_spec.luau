local harness = require("./harness")
local CardArt = require("../src/shared/CardCore/CardArt")
local Cards = require("../src/shared/CardCore/Cards")

local describe, it, expect = harness.describe, harness.it, harness.expect

describe("CardArt", function()
	it("has an image for every card in every look", function()
		for _, id in Cards.ids do
			for _, look in { "Field", "Redline", "Prototype", "ZeroDay" } do
				expect(string.sub(CardArt.base(id, look) or "", 1, 13)).toBe("rbxassetid://")
			end
			expect(string.sub(CardArt.outline(id) or "", 1, 13)).toBe("rbxassetid://")
		end
	end)

	it("gives nothing for a card with no art yet", function()
		expect(CardArt.base("no_such_card", "Field")).toBe(nil)
		expect(CardArt.outline("no_such_card")).toBe(nil)
	end)
end)
