local fs = require("@lune/fs")
local luau = require("@lune/luau")
local harness = require("./harness")

local describe, it, expect = harness.describe, harness.it, harness.expect
local SkipBurst = luau.load(fs.readFile("src/shared/Guns/SkipBurst.luau"))()

describe("SkipBurst", function()
	it("always has the same pieces in the same colours", function()
		local start = SkipBurst.at(0)
		expect(#start).toBe(SkipBurst.COUNT)
		for _, share in { 0.3, 0.99, 1, 2, -1 } do
			local pieces = SkipBurst.at(share)
			expect(#pieces).toBe(SkipBurst.COUNT)
			for index, piece in pieces do
				expect(piece.tone).toBe(start[index].tone)
			end
		end
	end)

	it("shows something while it plays and nothing before or after", function()
		for step = 0, 19 do
			local some = false
			for _, piece in SkipBurst.at(step / 20) do
				some = some or piece.shown
				expect(piece.width > 0 and piece.height > 0).toBe(true)
				expect(math.abs(piece.x) <= SkipBurst.REACH and math.abs(piece.y) <= SkipBurst.REACH).toBe(true)
			end
			expect(some).toBe(true)
		end
		for _, share in { -0.1, 1, 3 } do
			for _, piece in SkipBurst.at(share) do
				expect(piece.shown).toBe(false)
			end
		end
	end)

	it("throws its dashes outward and shortens them", function()
		local early, late = SkipBurst.at(0.1), SkipBurst.at(0.9)
		local ray = 5 -- the first dash, which goes straight out to the right
		expect(early[ray].tone).toBe("DataCyan")
		expect(late[ray].x > early[ray].x and early[ray].x > 0).toBe(true)
		expect(late[ray].width < early[ray].width).toBe(true)
		expect(late[1].y > early[1].y).toBe(true) -- the outline grows
	end)
end)
