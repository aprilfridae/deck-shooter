local harness = require("./harness")
local Recoil = require("../src/client/Recoil")

local describe, it, expect = harness.describe, harness.it, harness.expect

local function run(seconds: number): (number, number)
	local pitch, peak = 0, 0
	for _ = 1, math.floor(seconds * 60) do
		local dPitch = Recoil.advance(1 / 60)
		pitch += dPitch
		peak = math.max(peak, pitch)
	end
	return pitch, peak
end

describe("Recoil", function()
	it("lifts the aim by about the kick and no more", function()
		Recoil.reset()
		Recoil.kick(2)
		local _, peak = run(0.1)
		expect(peak <= math.rad(2) + 1e-6).toBe(true)
		expect(peak > math.rad(1.5)).toBe(true)
	end)

	it("eases back to where the aim started", function()
		Recoil.reset()
		Recoil.kick(4)
		local pitch = run(4)
		expect(math.abs(pitch) < math.rad(0.05)).toBe(true)
	end)

	it("stops climbing at the limit however long the gun fires", function()
		Recoil.reset()
		local pitch = 0
		for _ = 1, 600 do
			Recoil.kick(1)
			pitch += Recoil.advance(1 / 60)
		end
		expect(pitch <= math.rad(12) + 1e-6).toBe(true)
	end)
end)
