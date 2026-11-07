local harness = require("./harness")

local describe, it, expect = harness.describe, harness.it, harness.expect

local GUNS = {
	M57 = require("../src/shared/Movement/BodyPoses/M57"),
	B33 = require("../src/shared/Movement/BodyPoses/B33"),
	SMG = require("../src/shared/Movement/BodyPoses/SMG"),
	Longscope = require("../src/shared/Movement/BodyPoses/Longscope"),
	Shotgun = require("../src/shared/Movement/BodyPoses/Shotgun"),
	EnergyPistol = require("../src/shared/Movement/BodyPoses/EnergyPistol"),
}
local Empty = require("../src/shared/Movement/BodyPoses/Empty")

local POSES = {
	"Stand", "Fire", "Reload", "Walk_Contact", "Walk_Pass", "Sprint_Contact", "Sprint_Pass", "Crouch_Idle",
	"Crouch_Walk", "Slide", "Jump_Up", "Fall", "Land",
}
local JOINTS = {
	"Root", "Waist", "Neck", "RightShoulder", "RightElbow", "RightWrist", "LeftShoulder", "LeftElbow", "LeftWrist",
	"RightHip", "RightKnee", "RightAnkle", "LeftHip", "LeftKnee", "LeftAnkle",
}

local function isFrame(value: any): boolean
	if type(value) ~= "table" or #value ~= 7 then
		return false
	end
	local length = math.sqrt(value[4] ^ 2 + value[5] ^ 2 + value[6] ^ 2 + value[7] ^ 2)
	return math.abs(length - 1) < 0.002
end

local function checkPose(pose: any)
	for _, joint in JOINTS do
		expect(isFrame(pose.joints[joint])).toBe(true)
	end
	for _, key in { "gun", "mag", "action", "shell" } do
		expect(isFrame(pose[key])).toBe(true)
	end
	expect(pose.gunOn == "RightHand" or pose.gunOn == "UpperTorso").toBe(true)
end

describe("BodyPoses", function()
	it("has every third-person pose for every gun", function()
		for _, gun in GUNS do
			for _, name in POSES do
				expect(gun.poses[name] ~= nil).toBe(true)
				checkPose(gun.poses[name])
			end
		end
	end)

	it("adds the scoped poses for the Longscope", function()
		checkPose(GUNS.Longscope.poses.Scoped)
		checkPose(GUNS.Longscope.poses.Scoped_Crouch)
	end)

	it("holds every gun in the right hand", function()
		for _, gun in GUNS do
			for _, name in POSES do
				expect(gun.poses[name].gunOn).toBe("RightHand")
			end
		end
	end)

	it("slings the gun on the empty-handed stance", function()
		checkPose(Empty.poses.Stand)
		expect(Empty.poses.Stand.gunOn).toBe("UpperTorso")
	end)

	it("lists the soldier rig's joints with the root lowered to stand 3 studs up", function()
		for _, joint in JOINTS do
			expect(isFrame(Empty.rig[joint].c0)).toBe(true)
			expect(isFrame(Empty.rig[joint].c1)).toBe(true)
		end
		expect(Empty.rig.rootDrop).toBeCloseTo(2.009, 0.001)
	end)

	it("only turns elbows and knees about one axis", function()
		for _, gun in GUNS do
			for _, name in POSES do
				for _, joint in { "RightElbow", "LeftElbow", "RightKnee", "LeftKnee" } do
					local value = gun.poses[name].joints[joint]
					expect(math.abs(value[5]) < 0.01 and math.abs(value[6]) < 0.01).toBe(true)
				end
			end
		end
	end)
end)
