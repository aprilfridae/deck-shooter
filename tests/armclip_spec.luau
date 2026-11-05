local harness = require("./harness")
local ArmClip = require("../src/shared/Guns/ArmClip")

local describe, it, expect = harness.describe, harness.it, harness.expect

local function clip(loop: boolean): any
	return { fps = 10, loop = loop, frames = { "a", "b", "c" } }
end

describe("ArmClip.frameAt", function()
	it("holds each frame until the next one", function()
		expect(ArmClip.frameAt(clip(true), 0)).toBe("a")
		expect(ArmClip.frameAt(clip(true), 0.19)).toBe("b")
		expect(ArmClip.frameAt(clip(true), 0.21)).toBe("c")
	end)

	it("starts again when a looping clip ends", function()
		expect(ArmClip.frameAt(clip(true), 0.31)).toBe("a")
	end)

	it("returns nothing once a one-shot clip ends", function()
		expect(ArmClip.frameAt(clip(false), 0.29)).toBe("c")
		expect(ArmClip.frameAt(clip(false), 0.31)).toBe(nil)
	end)
end)

describe("ArmClip.blendBones", function()
	local half = math.sqrt(0.5)

	it("moves each bone part of the way", function()
		local from = { Palm = { 0, 0, 0, 0, 0, 0, 1 } }
		local to = { Palm = { 2, 4, 6, 0, 0, 0, 1 } }
		local bone = ArmClip.blendBones(from, to, 0.25).Palm
		expect(bone[1]).toBeCloseTo(0.5)
		expect(bone[2]).toBeCloseTo(1)
		expect(bone[3]).toBeCloseTo(1.5)
	end)

	it("keeps the turn a valid rotation", function()
		local from = { Palm = { 0, 0, 0, 0, 0, 0, 1 } }
		local to = { Palm = { 0, 0, 0, 1, 0, 0, 0 } }
		local bone = ArmClip.blendBones(from, to, 0.5).Palm
		expect(bone[4]).toBeCloseTo(half)
		expect(bone[7]).toBeCloseTo(half)
	end)

	it("turns the short way round", function()
		local from = { Palm = { 0, 0, 0, 0, 0, 0, 1 } }
		local to = { Palm = { 0, 0, 0, 0, 0, 0, -1 } }
		local bone = ArmClip.blendBones(from, to, 0.5).Palm
		expect(bone[7]).toBeCloseTo(1)
	end)
end)

describe("ArmClip.overlay", function()
	local under = { gun = "held", bones = { Left = { 1 }, Right = { 2 } } }
	local top = { gun = "ignored", bones = { Left = { 9 } } }

	it("takes the top frame's bones and keeps the rest", function()
		local bones = ArmClip.overlay(under, top).bones
		expect(bones.Left[1]).toBe(9)
		expect(bones.Right[1]).toBe(2)
	end)

	it("keeps the gun where the frame underneath has it", function()
		expect(ArmClip.overlay(under, top).gun).toBe("held")
	end)

	it("leaves both frames as they were", function()
		ArmClip.overlay(under, top)
		expect(under.bones.Left[1]).toBe(1)
		expect(top.bones.Right).toBe(nil)
	end)
end)

describe("reload timing", function()
	local GunConfig = require("../src/shared/Guns/GunConfig")

	it("lasts as long as the reload sound", function()
		expect(GunConfig.guns.M4.reload).toBeCloseTo(0.964)
		expect(GunConfig.guns.AK47.reload).toBeCloseTo(0.964)
		expect(GunConfig.guns.Sniper.reload).toBeCloseTo(1.714)
	end)
end)
