local harness = require("./harness")
local MusicBars = require("../src/shared/Guns/MusicBars")

local describe, it, expect = harness.describe, harness.it, harness.expect

describe("MusicBars", function()
	it("is flat in silence", function()
		expect(MusicBars.level(0, 3, 24, 1)).toBe(0)
	end)

	it("stays between empty and full however loud it gets", function()
		for bar = 1, 24 do
			local level = MusicBars.level(5000, bar, 24, 2.3)
			expect(level >= 0 and level <= 1).toBe(true)
		end
	end)

	it("gives bars different heights", function()
		expect(MusicBars.level(200, 2, 24, 1) ~= MusicBars.level(200, 9, 24, 1)).toBe(true)
	end)

	it("jumps up at once and falls slowly", function()
		expect(MusicBars.ease(0.2, 0.8, 0.016)).toBe(0.8)
		local fallen = MusicBars.ease(0.8, 0.2, 0.016)
		expect(fallen < 0.8 and fallen > 0.6).toBe(true)
	end)

	it("lights this many segments", function()
		expect(MusicBars.lit(0, 10)).toBe(0)
		expect(MusicBars.lit(0.55, 10)).toBe(6)
		expect(MusicBars.lit(1, 10)).toBe(10)
	end)
end)
