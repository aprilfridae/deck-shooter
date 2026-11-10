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

	it("ends as one squared deck with one card flipped out of it", function()
		local pose = CardFlourish.at(CardFlourish.LENGTH)
		local bottom = pose.cards[CardFlourish.HALF + 1]
		for index, frame in pose.cards do
			local offset = bottom:PointToObjectSpace(frame.Position)
			local squared = math.abs(offset.X) < 0.001 and math.abs(offset.Z) < 0.001
			expect(squared).toBe(index ~= CardFlourish.CHOSEN)
		end
		local top = bottom:PointToObjectSpace(pose.cards[CardFlourish.CHOSEN - 1].Position)
		-- The cards lie face down, so further up the deck is further down a card's own axis.
		expect(top.Y < bottom:PointToObjectSpace(pose.cards[CardFlourish.COUNT].Position).Y).toBe(true)
	end)

	it("shows only backs until the chosen card is flipped face up at the end", function()
		for _, share in { 0, 0.1, 0.4, 0.63, 0.83 } do
			for _, frame in CardFlourish.at(share * CardFlourish.LENGTH).cards do
				expect(frame.UpVector:Dot(-frame.Position) < 0).toBe(true) -- the face points away from the eye
			end
		end
		local pose = CardFlourish.at(CardFlourish.LENGTH)
		for index, frame in pose.cards do
			expect(frame.UpVector:Dot(-frame.Position) > 0).toBe(index == CardFlourish.CHOSEN)
		end
	end)

	it("crushes the flipped card into the right hand from any moment", function()
		for _, elapsed in { 0, 0.5, 3.6, CardFlourish.LENGTH } do
			local crush = CardFlourish.crush(elapsed, CardFlourish.CRUSH)
			expect(crush.crushed).toBe(1)
			expect((crush.pose.cards[CardFlourish.CHOSEN].Position - crush.palm).Magnitude < 1e-4).toBe(true)
		end
	end)

	it("turns the next card face up onto the one the right hand holds", function()
		local ended = CardFlourish.at(CardFlourish.LENGTH)
		local first = ended.cards[CardFlourish.CHOSEN]
		for turns = 1, 3 do
			local pose = CardFlourish.turn(turns, 5)
			expect(#pose.cards).toBe(CardFlourish.COUNT)
			local top = CardFlourish.top(turns)
			expect(top).toBe(CardFlourish.CHOSEN - turns)
			local offset = first:PointToObjectSpace(pose.cards[top].Position)
			expect(math.abs(offset.X) < 0.001 and math.abs(offset.Z) < 0.001 and offset.Y > 0).toBe(true)
			for index, frame in pose.cards do
				expect(frame.UpVector:Dot(-frame.Position) > 0).toBe(index >= top and index <= CardFlourish.CHOSEN)
			end
		end
		local start = CardFlourish.turn(1, 0).cards[CardFlourish.CHOSEN - 1]
		expect((start.Position - ended.cards[CardFlourish.CHOSEN - 1].Position).Magnitude < 0.05).toBe(true)
	end)

	it("crushes the card turned to", function()
		local crush = CardFlourish.crush(CardFlourish.LENGTH, CardFlourish.CRUSH, 2)
		expect(crush.card).toBe(CardFlourish.CHOSEN - 2)
		expect((crush.pose.cards[crush.card].Position - crush.palm).Magnitude < 1e-4).toBe(true)
	end)

	it("sways each hand a little, with its cards", function()
		for _, elapsed in { 0.3, 1.5, CardFlourish.LENGTH } do
			local pose = CardFlourish.at(elapsed)
			local swayed = CardFlourish.sway(pose, 12.3)
			expect(#swayed.cards).toBe(CardFlourish.COUNT)
			local moved = (swayed.left.Position - pose.left.Position).Magnitude
			expect(moved > 0 and moved < 0.03).toBe(true)
			for index, frame in pose.cards do
				local hand, was = swayed.left, pose.left
				if pose.sides[index] == 1 then
					hand, was = swayed.right, pose.right
				elseif pose.sides[index] ~= 0 then
					continue
				end
				local slipped = hand:ToObjectSpace(swayed.cards[index]).Position - was:ToObjectSpace(frame).Position
				expect(slipped.Magnitude < 1e-4).toBe(true)
			end
		end
	end)

	it("loosens the tempo but starts and ends on time", function()
		expect(CardFlourish.tempo(0, 5)).toBe(0)
		expect(CardFlourish.tempo(CardFlourish.LENGTH, 5)).toBe(CardFlourish.LENGTH)
		local last = 0
		for step = 1, 200 do
			local now = CardFlourish.tempo(step * CardFlourish.LENGTH / 200, 5 + step * CardFlourish.LENGTH / 200)
			expect(now > last).toBe(true)
			last = now
		end
	end)

	it("bends the deck in the right hand and lets every card go flat", function()
		local squeezed = CardFlourish.at(0.055).bends
		for index = 1, CardFlourish.COUNT do
			expect(squeezed[index] > 0.5).toBe(true)
		end
		expect(CardFlourish.at(CardFlourish.LENGTH).bends).toBe(nil)
		local landing = CardFlourish.at(0.718).bends
		for index = 1, CardFlourish.COUNT do
			expect(math.abs(landing[index]) < 0.01).toBe(true)
		end
		expect(CardFlourish.sway(CardFlourish.at(0.055), 3).bends).toBe(squeezed)
	end)

	it("shows a bent card as an arc between its two ends", function()
		local frame = CFrame.new(1, 2, 3) * CFrame.Angles(0.3, 0.2, 0.1)
		local length = CardFlourish.CARD_SIZE.Z
		local flat = CardFlourish.strips(frame, 0)
		expect(#flat).toBe(CardFlourish.STRIPS)
		for piece, at in flat do
			local offset = frame:PointToObjectSpace(at.Position)
			expect(math.abs(offset.Y) < 1e-5).toBe(true)
			expect(math.abs(offset.Z - ((piece - 0.5) / CardFlourish.STRIPS - 0.5) * length) < 1e-5).toBe(true)
		end
		local bent = CardFlourish.strips(frame, 0.7)
		local first = frame:ToObjectSpace(bent[1])
		local last = frame:ToObjectSpace(bent[CardFlourish.STRIPS])
		local middle = frame:PointToObjectSpace(bent[CardFlourish.STRIPS / 2].Position)
		expect(middle.Y > first.Position.Y and first.Position.Y > 0).toBe(true) -- bowed toward its face
		expect(math.abs(first.Position.Y - last.Position.Y) < 1e-5).toBe(true)
		-- The first piece's outer end is where the flat card's end is.
		local tip = first * Vector3.new(0, 0, -length / CardFlourish.STRIPS / 2)
		expect(math.abs(tip.Y) < 0.004 and math.abs(tip.Z + length / 2) < 0.012).toBe(true)
		local other = frame:PointToObjectSpace(CardFlourish.strips(frame, -0.7)[2].Position)
		expect(other.Y < 0).toBe(true)
	end)

	it("holds its end", function()
		local last = CardFlourish.at(CardFlourish.LENGTH).cards[1]
		local later = CardFlourish.at(CardFlourish.LENGTH + 10).cards[1]
		expect((last.Position - later.Position).Magnitude < 1e-6).toBe(true)
	end)
end)
