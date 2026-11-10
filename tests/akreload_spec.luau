local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")
local harness = require("./harness")

local describe, it, expect = harness.describe, harness.it, harness.expect
local CFrame, Vector3 = roblox.CFrame, roblox.Vector3
local AkReload = luau.load(fs.readFile("src/shared/Guns/AkReload.luau"), {
	environment = { CFrame = CFrame, Vector3 = Vector3 },
})()

local function still(frame): boolean
	return frame.Position.Magnitude < 1e-5 and (frame.LookVector - Vector3.new(0, 0, -1)).Magnitude < 1e-5
end

describe("AkReload", function()
	it("starts and ends with everything in place and the hand on the handguard", function()
		for _, t in { 0, 0.05, AkReload.LENGTH, 3 } do
			local pose = AkReload.at(t)
			expect(still(pose.mag)).toBe(true)
			expect(pose.bolt).toBe(0)
			expect(pose.weight).toBe(0)
		end
	end)

	it("rocks the magazine off its lug on the click and has it home on the slam", function()
		local out = AkReload.at(0.42).mag
		expect(math.abs(math.deg(math.asin(out.UpVector.Z)) - AkReload.ROCK) < 0.5).toBe(true)
		-- The lug itself hasn't moved: it rocks about it.
		expect((out * AkReload.LUG - AkReload.LUG).Magnitude < 1e-4).toBe(true)
		expect(AkReload.at(0.52).mag.Position.Y < -0.2).toBe(true) -- gone, down out of view
		expect(still(AkReload.at(0.64).mag)).toBe(true)
		expect(still(AkReload.at(0.29).mag)).toBe(true)
	end)

	it("pulls the bolt back on the charge and lets it fly home", function()
		expect(AkReload.at(0.85).bolt).toBe(0)
		expect(math.abs(AkReload.at(0.93).bolt - AkReload.TRAVEL) < 1e-6).toBe(true)
		expect(AkReload.at(0.9).bolt > 0.03).toBe(true)
		expect(AkReload.at(0.97).bolt).toBe(0)
	end)

	it("keeps the hand on the magazine while it moves, then on the handle", function()
		local held = AkReload.at(0.3).mag:ToObjectSpace(AkReload.at(0.3).palm)
		for _, t in { 0.36, 0.42, 0.5, 0.6, 0.64 } do
			local pose = AkReload.at(t)
			expect(pose.weight).toBe(1)
			local now = pose.mag:ToObjectSpace(pose.palm)
			expect((now.Position - held.Position).Magnitude < 1e-4).toBe(true)
		end
		local before, pulled = AkReload.at(0.84).palm, AkReload.at(0.93).palm
		expect(math.abs(pulled.Position.Z - before.Position.Z - AkReload.TRAVEL) < 1e-5).toBe(true)
	end)

	it("never jumps", function()
		local last = AkReload.at(0)
		for step = 1, 300 do
			local pose = AkReload.at(step * AkReload.LENGTH / 300)
			expect((pose.palm.Position - last.palm.Position).Magnitude < 0.05).toBe(true)
			expect(math.abs(pose.weight - last.weight) < 0.06).toBe(true)
			expect(math.abs(pose.bolt - last.bolt) < 0.03).toBe(true)
			last = pose
		end
	end)
end)
