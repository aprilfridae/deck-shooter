local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")
local harness = require("./harness")

local describe, it, expect = harness.describe, harness.it, harness.expect
local CFrame, Vector3 = roblox.CFrame, roblox.Vector3
local Loosen = luau.load(fs.readFile("src/shared/Guns/Loosen.luau"), {
	environment = { CFrame = CFrame, Vector3 = Vector3 },
})()

describe("Loosen", function()
	it("loosens the tempo but starts and ends on time, never running backwards", function()
		for _, length in { 0.3, 1, 2.6 } do
			expect(Loosen.tempo(0, length, 5)).toBe(0)
			expect(Loosen.tempo(length, length, 5)).toBe(length)
			expect(Loosen.tempo(length + 1, length, 5)).toBe(length + 1)
			local last, moved = 0, false
			for step = 1, 200 do
				local at = step * length / 200
				local now = Loosen.tempo(at, length, 5 + at)
				expect(now > last).toBe(true)
				expect(math.abs(now - at) <= 0.035).toBe(true)
				moved = moved or now ~= at
				last = now
			end
			expect(moved).toBe(true)
		end
	end)

	it("goes differently each play", function()
		expect(Loosen.tempo(0.5, 2, 3) ~= Loosen.tempo(0.5, 2, 40)).toBe(true)
	end)

	it("drifts a little, and not at all with none showing", function()
		local pivot = Vector3.new(0.3, -0.4, -1)
		local still = Loosen.drift(pivot, 12.3, 0)
		expect((still.Position).Magnitude < 1e-6).toBe(true)
		local drifted = Loosen.drift(pivot, 12.3, 1)
		local moved = (drifted * pivot - pivot).Magnitude
		expect(moved > 0 and moved < 0.03).toBe(true)
	end)
end)
