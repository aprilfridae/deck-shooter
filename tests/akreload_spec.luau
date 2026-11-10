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
			expect(pose.rightWeight).toBe(0)
		end
	end)

	it("tips the muzzle up and rolls the gun over, top to the right, for the magazines", function()
		for _, t in { 0.3, 0.5, 0.66 } do
			local over = AkReload.at(t).gun
			expect(over.UpVector.X > 0.5).toBe(true)
			expect(over.LookVector.Y > 0.4).toBe(true)
		end
		-- And has it down again, near upright, for the charge.
		expect(math.abs(AkReload.at(0.9).gun.UpVector.X) < 0.4).toBe(true)
	end)

	it("rips the old magazine out before the new one comes up", function()
		expect(still(AkReload.at(0.17).mag)).toBe(true)
		expect(AkReload.at(0.17).spare).toBe(nil)
		-- Rocked off its lug, then pulled well clear of the well.
		local rocking = AkReload.at(0.26).mag
		expect(rocking.UpVector.Z > 0.15).toBe(true)
		expect(AkReload.at(0.33).mag.Position.Magnitude > 0.05).toBe(true)
		-- The new one is still down out of view when the old one is let go, and isn't near the gun until later.
		local spare = AkReload.at(0.36)
		expect(spare.spare ~= nil).toBe(true)
		expect((spare.gun * spare.spare).Position.Y < -0.25).toBe(true)
	end)

	it("tosses the old magazine up in an arc, in the hold, whatever the gun does, and it falls away", function()
		local function inHold(t: number): Vector3
			local pose = AkReload.at(t)
			return (pose.gun * pose.mag).Position
		end
		local let, up, down, gone = inHold(0.34), inHold(0.42), inHold(0.58), inHold(0.74)
		expect(up.Y > let.Y + 0.05).toBe(true) -- up first
		expect(up.Z > let.Z).toBe(true) -- and back over the shoulder
		expect(down.Y < up.Y and gone.Y < -0.7).toBe(true) -- then down out of view
	end)

	it("hooks the new magazine's lug and rocks it home on the slam", function()
		local hooked = AkReload.at(0.6).spare
		expect(math.abs(math.deg(math.asin(hooked.UpVector.Z)) - AkReload.ROCK) < 0.5).toBe(true)
		expect((hooked * AkReload.LUG - AkReload.LUG).Magnitude < 1e-4).toBe(true) -- about the lug
		local home = AkReload.at(0.72)
		expect(still(home.spare)).toBe(true) -- the new one, in the gun, while the old one is still falling
		expect(still(AkReload.at(0.8).mag)).toBe(true)
		expect(AkReload.at(0.8).spare).toBe(nil)
	end)

	it("keeps the hand on whichever magazine it has", function()
		local function onMag(t: number): Vector3
			local pose = AkReload.at(t)
			local held = if t < 0.34 or t >= 0.76 then pose.mag else pose.spare
			return (pose.gun * held):ToObjectSpace(pose.palm).Position
		end
		local grip = onMag(0.24)
		for _, t in { 0.23, 0.28, 0.46, 0.5, 0.57, 0.62, 0.66 } do
			expect(AkReload.at(t).weight > 0.99).toBe(true)
			expect((onMag(t) - grip).Magnitude < 1e-4).toBe(true)
		end
	end)

	it("has the left hand back on the handguard before the right hand charges", function()
		expect(AkReload.at(0.67).weight > 0.99).toBe(true)
		expect(AkReload.at(0.86).weight).toBe(0)
		expect(AkReload.at(0.71).rightWeight).toBe(0)
		local pulling = AkReload.at(0.9)
		expect(pulling.rightWeight > 0.99).toBe(true)
		-- The right hand is outside the gun's right side, and goes back with the handle.
		local wrist = pulling.gun:ToObjectSpace(pulling.right).Position
		expect(wrist.X > 0.1).toBe(true) -- well clear of the receiver, which ends at about 0.02
		local before, after = AkReload.at(0.865), AkReload.at(0.93)
		local moved = after.gun:ToObjectSpace(after.right).Position.Z - before.gun:ToObjectSpace(before.right).Position.Z
		expect(moved > AkReload.TRAVEL * 0.7).toBe(true)
		expect(AkReload.at(1.2).rightWeight).toBe(0)
	end)

	it("pulls the bolt back on the charge and lets it fly home", function()
		expect(AkReload.at(0.86).bolt).toBe(0)
		expect(math.abs(AkReload.at(0.93).bolt - AkReload.TRAVEL) < 1e-6).toBe(true)
		expect(AkReload.at(0.9).bolt > 0.03).toBe(true)
		expect(AkReload.at(0.97).bolt).toBe(0)
	end)

	it("never jumps", function()
		local last = AkReload.at(0)
		for step = 1, 400 do
			local pose = AkReload.at(step * AkReload.LENGTH / 400)
			expect((pose.palm.Position - last.palm.Position).Magnitude < 0.05).toBe(true)
			expect((pose.gun.Position - last.gun.Position).Magnitude < 0.035).toBe(true)
			expect(math.abs(pose.weight - last.weight) < 0.06).toBe(true)
			last = pose
		end
	end)
end)
