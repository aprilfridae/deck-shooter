local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")
local harness = require("./harness")

local describe, it, expect = harness.describe, harness.it, harness.expect
local CFrame, Vector3 = roblox.CFrame, roblox.Vector3
local CardFlourish = luau.load(fs.readFile("src/shared/Guns/CardFlourish.luau"), {
	environment = { CFrame = CFrame, Vector3 = Vector3 },
})()

describe("CardFlourish", function()
	it("places every card at every moment", function()
		for step = 0, 60 do
			local pose = CardFlourish.at(step * CardFlourish.LENGTH / 60)
			expect(#pose.cards).toBe(CardFlourish.COUNT)
		end
	end)

	it("ends as one squared deck with the right hand's half on top", function()
		local pose = CardFlourish.at(CardFlourish.LENGTH)
		local bottom = pose.cards[CardFlourish.HALF + 1]
		for _, frame in pose.cards do
			local offset = bottom:PointToObjectSpace(frame.Position)
			expect(math.abs(offset.X) < 0.001 and math.abs(offset.Z) < 0.001).toBe(true)
		end
		local top = bottom:PointToObjectSpace(pose.cards[CardFlourish.HALF].Position)
		expect(top.Y > bottom:PointToObjectSpace(pose.cards[CardFlourish.COUNT].Position).Y).toBe(true)
	end)

	it("holds its end", function()
		local last = CardFlourish.at(CardFlourish.LENGTH).cards[1]
		local later = CardFlourish.at(CardFlourish.LENGTH + 10).cards[1]
		expect((last.Position - later.Position).Magnitude < 1e-6).toBe(true)
	end)
end)
