local harness = require("./harness")
local PackArt = require("../src/shared/CardCore/PackArt")
local Packs = require("../src/shared/CardCore/Packs")

local describe, it, expect = harness.describe, harness.it, harness.expect

describe("PackArt", function()
	it("has art for every pack", function()
		for _, pack in Packs.ids do
			expect(type(PackArt.image(pack))).toBe("string")
		end
		expect(PackArt.image("Nonsense")).toBe(nil)
	end)
end)
