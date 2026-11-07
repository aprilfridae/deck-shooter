local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")
local harness = require("./harness")
local ArmPose = require("../src/shared/Guns/ArmPose")
local SoldierArmsData = require("../src/shared/Guns/SoldierArmsData")

local describe, it, expect = harness.describe, harness.it, harness.expect
local CFrame, Vector3 = roblox.CFrame, roblox.Vector3

local function load(path: string, extra: { [string]: any }?): any
	local environment: any = { CFrame = CFrame, Vector3 = Vector3 }
	for key, value in extra or {} do
		environment[key] = value
	end
	return luau.load(fs.readFile(path), { environment = environment })()
end

local SoldierPose = load("src/shared/Guns/SoldierPose.luau", {
	require = function(path: string): any
		return if path == "./ArmPose" then ArmPose else SoldierArmsData
	end,
})
local clip = load("src/shared/Guns/ArmClips/M57.luau")
local bones = clip.idle.frames[1].bones
local pose = SoldierPose.new(bones)

local function bone(name: string): any
	local b = bones[name]
	return CFrame.new(b[1] * 0.7, b[2] * 0.7, b[3] * 0.7, b[4], b[5], b[6], b[7])
end

local function close(a: any, b: any, within: number): boolean
	return (a - b).Magnitude < within
end

local function wristOf(parts: any): any
	return parts.RightHand:PointToWorldSpace(Vector3.new(0, SoldierArmsData.wrist, 0))
end

describe("SoldierPose", function()
	local parts = SoldierPose.fromBones(pose, clip.meshOffset, bones)

	it("puts every part of both arms somewhere", function()
		local count = 0
		for name in SoldierArmsData.frames do
			expect(parts[name] ~= nil).toBe(true)
			count += 1
		end
		expect(count).toBe(36)
	end)

	it("puts the soldier's wrist on the clip's palm", function()
		local palm = clip.meshOffset * bone("R.Brazo") * bone("R.Antebrazo") * bone("R.Palma")
		expect(close(wristOf(parts), palm.Position, 0.001)).toBe(true)
	end)

	it("keeps the knuckles near the clip's knuckles", function()
		local knuckle = clip.meshOffset:PointToWorldSpace(bone("R.DedoMedio").Position)
		expect(close(parts.RightMiddle1.Position, knuckle, 0.1)).toBe(true)
	end)

	it("joins the lower arm to the hand", function()
		local elbowToWrist = parts.RightLowerArm:PointToWorldSpace(Vector3.new(0, -0.6, 0))
		expect(close(elbowToWrist, wristOf(parts), 0.02)).toBe(true)
	end)

	it("aims a finger the way the clip's finger points", function()
		local tip = parts.RightIndex3.Position - parts.RightIndex2.Position
		local aim = clip.meshOffset:VectorToWorldSpace((bone("R.Indice") * bone("R.Indice2")).UpVector)
		expect(tip.Unit:Dot(aim) > 0.95).toBe(true)
	end)

	it("keeps the arm joined when the hand is out of reach", function()
		local far = CFrame.new(0.8, -0.4, -6)
		local reached = SoldierPose.fromPalms(pose, far, CFrame.new(-0.4, -0.5, -1.2))
		local wrist = reached.RightLowerArm:PointToWorldSpace(Vector3.new(0, -0.6, 0))
		expect(close(wrist, far.Position, 0.02)).toBe(true)
	end)

	it("curls the fingers the same on a gun with no clip", function()
		local palm = CFrame.new(0.5, -0.8, -1.2)
		local gripped = SoldierPose.fromPalms(pose, palm, palm)
		local first = parts.RightHand:ToObjectSpace(parts.RightIndex2)
		local second = gripped.RightHand:ToObjectSpace(gripped.RightIndex2)
		expect(close(first.Position, second.Position, 0.05)).toBe(true)
	end)

	it("turns a grip into a palm at the wrist", function()
		local grip = { wrist = Vector3.new(0, 1, 0), along = Vector3.new(0, 0, -1), thumb = Vector3.new(0, 1, 0) }
		local palm = SoldierPose.palm(CFrame.new(2, 0, 0), grip)
		expect(close(palm.Position, Vector3.new(2, 1, 0), 0.001)).toBe(true)
		expect(close(palm.UpVector, Vector3.new(0, 0, -1), 0.001)).toBe(true)
		expect(close(palm.LookVector, Vector3.new(0, 1, 0), 0.001)).toBe(true)
	end)
end)
