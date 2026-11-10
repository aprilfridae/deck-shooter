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
		for _, t in { 0, AkReload.LENGTH, 3 } do
			local pose = AkReload.at(t)
			expect(still(pose.gun)).toBe(true)
			expect(still(pose.mag)).toBe(true)
			expect(pose.spare).toBe(nil)
			expect(pose.bolt).toBe(0)
			expect(pose.weight).toBe(0)
		end
	end)

	it("tips the muzzle up and rolls the gun over, top to the right, until the charge is done", function()
		for _, t in { 0.35, 0.6, 0.9 } do
			local over = AkReload.at(t).gun
			expect(over.UpVector.X > 0.5).toBe(true)
			expect(over.LookVector.Y > 0.4).toBe(true)
		end
	end)

	it("keeps the hand outside the gun's right side on the charging knob", function()
		local pose = AkReload.at(0.86)
		local wrist = pose.gun:ToObjectSpace(pose.palm).Position
		expect(wrist.X > 0.06 and wrist.Y < -0.05).toBe(true)
	end)

	it("keeps the old magazine in the gun until the new one knocks it out", function()
		expect(still(AkReload.at(0.41).mag)).toBe(true)
		expect(AkReload.at(0.3).spare ~= nil).toBe(true) -- the new one, coming up in the hand
		local knocked = AkReload.at(0.5)
		expect(knocked.spare ~= nil and knocked.spare.Position.Magnitude > 0.05).toBe(true) -- the old one, falling
		expect(AkReload.at(0.73).spare).toBe(nil)
	end)

	it("hooks the new magazine's lug and rocks it home on the slam", function()
		local hooked = AkReload.at(0.55).mag
		expect(math.abs(math.deg(math.asin(hooked.UpVector.Z)) - AkReload.ROCK) < 0.5).toBe(true)
		expect((hooked * AkReload.LUG - AkReload.LUG).Magnitude < 1e-4).toBe(true) -- about the lug
		expect(still(AkReload.at(0.64).mag)).toBe(true)
	end)

	it("lets the old magazine fall straight down in the hold, whatever the gun does", function()
		local function inHold(t: number): Vector3
			local pose = AkReload.at(t)
			return (pose.gun * pose.spare).Position
		end
		local early, later, last = inHold(0.46), inHold(0.56), inHold(0.66)
		expect(later.Y < early.Y and last.Y < later.Y).toBe(true)
		expect(early.Y - later.Y < later.Y - last.Y).toBe(true) -- it speeds up
		expect(last.Y < -0.5).toBe(true)
	end)

	it("swings the hand out under the gun on its way back from the knob", function()
		local pose = AkReload.at(1.04)
		local out = pose.gun.Rotation:Inverse() * pose.swing
		expect(out.X > 0.05 and out.Y < -0.06).toBe(true)
		expect(AkReload.at(0.9).swing.Magnitude).toBe(0)
		expect(AkReload.at(1.15).swing.Magnitude).toBe(0)
	end)

	it("pulls the bolt back on the charge and lets it fly home", function()
		expect(AkReload.at(0.85).bolt).toBe(0)
		expect(math.abs(AkReload.at(0.93).bolt - AkReload.TRAVEL) < 1e-6).toBe(true)
		expect(AkReload.at(0.9).bolt > 0.03).toBe(true)
		expect(AkReload.at(0.97).bolt).toBe(0)
	end)

	it("keeps the hand on the new magazine from the fetch to the slam", function()
		local function onMag(t: number): Vector3
			local pose = AkReload.at(t)
			local held = if t < 0.42 then pose.spare else pose.mag
			return (pose.gun * held):ToObjectSpace(pose.palm).Position
		end
		local grip = onMag(0.3)
		for _, t in { 0.2, 0.36, 0.44, 0.5, 0.6, 0.64 } do
			expect(AkReload.at(t).weight).toBe(1)
			expect((onMag(t) - grip).Magnitude < 1e-4).toBe(true)
		end
	end)

	it("never jumps", function()
		local last = AkReload.at(0)
		for step = 1, 400 do
			local pose = AkReload.at(step * AkReload.LENGTH / 400)
			expect((pose.palm.Position - last.palm.Position).Magnitude < 0.05).toBe(true)
			expect((pose.gun.Position - last.gun.Position).Magnitude < 0.02).toBe(true)
			expect(math.abs(pose.weight - last.weight) < 0.06).toBe(true)
			last = pose
		end
	end)
end)
