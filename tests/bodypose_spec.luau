local harness = require("./harness")
local BodyPose = require("../src/shared/Movement/BodyPose")

local describe, it, expect = harness.describe, harness.it, harness.expect

describe("BodyPose joints", function()
	it("names only R15 joints", function()
		local known = {}
		for _, name in { "Waist", "Neck", "LeftShoulder", "LeftElbow", "LeftWrist", "RightShoulder", "RightElbow", "RightWrist", "LeftHip", "LeftKnee", "LeftAnkle", "RightHip", "RightKnee", "RightAnkle" } do
			known[name] = true
		end
		for _, pose in { BodyPose.slide, BodyPose.crouch } do
			for name in pose do
				expect(known[name]).toBe(true)
			end
		end
	end)

	it("jitters every R15 joint", function()
		local count = 0
		for _, degrees in BodyPose.jitter do
			count += 1
			expect(degrees > 0).toBe(true)
		end
		expect(count).toBe(15)
	end)

	it("keeps the slide above the floor", function()
		local lowestPoseHeight = 1.61 -- measured on the rig in Play, with no drop
		expect(BodyPose.slideDrop < lowestPoseHeight).toBe(true)
	end)

	it("straightens the lead leg and bends the back one in a slide", function()
		expect(BodyPose.slide.LeftKnee.x < BodyPose.slide.RightKnee.x).toBe(true)
	end)

	it("keeps the lead leg off the ground in a slide", function()
		expect(BodyPose.slideLean + BodyPose.slide.RightHip.x < 90).toBe(true)
	end)

	it("bends the legs enough to cover the crouch drop", function()
		local hip, knee = math.rad(BodyPose.crouch.RightHip.x), math.rad(BodyPose.crouch.RightKnee.x)
		local thigh, shin = 1.4, 1.4
		local standing = thigh + shin
		local bent = thigh * math.cos(hip) + shin * math.cos(hip + knee)
		expect(standing - bent >= BodyPose.crouchDrop - 0.1).toBe(true)
	end)
end)

describe("BodyPose timing", function()
	it("holds each frame", function()
		local step = 1 / BodyPose.frameRate
		expect(BodyPose.frame(step * 3.1)).toBe(BodyPose.frame(step * 3.9))
		expect(BodyPose.frame(step * 4.1) ~= BodyPose.frame(step * 3.9)).toBe(true)
	end)

	it("runs at the arms' running frame rate", function()
		expect(BodyPose.frameRate >= 10 and BodyPose.frameRate <= 13.33).toBe(true)
	end)

	it("throws the weight past the slide, then settles", function()
		expect(BodyPose.slideIn(0)).toBe(0)
		expect(BodyPose.slideIn(0.1) > 1).toBe(true)
		expect(BodyPose.slideIn(5)).toBe(1)
	end)

	it("comes out of a slide from wherever it was", function()
		expect(BodyPose.slideOut(0, 0.6)).toBe(0.6)
		expect(BodyPose.slideOut(5, 0.6)).toBe(0)
	end)

	it("dips on landing and recovers", function()
		expect(BodyPose.landDip(0)).toBe(0)
		expect(BodyPose.landDip(0.08) > 0).toBe(true)
		expect(BodyPose.landDip(5)).toBe(0)
	end)

	it("leans into a run, up to a limit", function()
		expect(BodyPose.runLean(0)).toBe(0)
		expect(BodyPose.runLean(30) > BodyPose.runLean(10)).toBe(true)
		expect(BodyPose.runLean(1000)).toBe(BodyPose.runLean(40))
	end)
end)
