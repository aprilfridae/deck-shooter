local harness = require("./harness")

local describe, it, expect = harness.describe, harness.it, harness.expect

local SoldierClip = require("../src/shared/Guns/SoldierClip")

local GUNS = {
	M57 = require("../src/shared/Guns/SoldierClips/M57"),
	B33 = require("../src/shared/Guns/SoldierClips/B33"),
	SMG = require("../src/shared/Guns/SoldierClips/SMG"),
	Longscope = require("../src/shared/Guns/SoldierClips/Longscope"),
	Shotgun = require("../src/shared/Guns/SoldierClips/Shotgun"),
	EnergyPistol = require("../src/shared/Guns/SoldierClips/EnergyPistol"),
}
local SoldierRig = require("../src/shared/Guns/SoldierRig")

local CLIPS = { "idle", "aim", "aimIn", "aimOut", "fire", "aimFire", "run", "equip", "holster", "reload" }
local BONES = { "Gun", "Mag", "Action" }
for _, side in { "Right", "Left" } do
	for _, part in { "UpperArm", "LowerArm", "Hand" } do
		table.insert(BONES, side .. part)
	end
	for _, finger in { "Thumb", "Index", "Middle", "Ring", "Pinky" } do
		for joint = 1, 3 do
			table.insert(BONES, side .. finger .. joint)
		end
	end
end

local function isFrame(value: any): boolean
	if type(value) ~= "table" or #value ~= 7 then
		return false
	end
	local length = math.sqrt(value[4] ^ 2 + value[5] ^ 2 + value[6] ^ 2 + value[7] ^ 2)
	return math.abs(length - 1) < 0.002
end

local tiny = {
	poses = {
		A = { Gun = { 0, 0, 0, 0, 0, 0, 1 } },
		B = { Gun = { 2, 0, 0, 0, 0, 0, 1 } },
	},
	clips = {
		one = { fps = 12, loop = false, frames = { { "A" }, { "A", "B", 0.5 }, { "A", "B", 0.5 } } },
		reload = { fps = 12, loop = false, scaled = true, frames = { { "B" } } },
	},
}

describe("SoldierClip", function()
	it("blends between two poses", function()
		local clips = SoldierClip.expand(tiny)
		expect(clips.one.frames[1].bones.Gun[1]).toBe(0)
		expect(clips.one.frames[2].bones.Gun[1]).toBe(1)
	end)

	it("shares one table between frames that name the same thing", function()
		local clips = SoldierClip.expand(tiny)
		expect(clips.one.frames[2] == clips.one.frames[3]).toBe(true)
	end)

	it("keeps the scaled flag and stretches a scaled clip to a time", function()
		local clips = SoldierClip.expand(tiny)
		expect(clips.reload.scaled).toBe(true)
		expect(clips.one.scaled).toBe(false)
		expect(SoldierClip.fpsFor(clips.one, 0.5)).toBe(6)
	end)
end)

describe("SoldierClips", function()
	it("has every clip for every gun, and every clip expands", function()
		for _, gun in GUNS do
			local clips = SoldierClip.expand(gun)
			for _, name in CLIPS do
				expect(clips[name] ~= nil).toBe(true)
				expect(#clips[name].frames > 0).toBe(true)
			end
			expect(clips.reload.scaled).toBe(true)
		end
	end)

	it("gives every pose every arm part, finger, the gun, magazine and action", function()
		for _, gun in GUNS do
			for _, pose in gun.poses do
				for _, bone in BONES do
					expect(isFrame(pose[bone])).toBe(true)
				end
			end
		end
	end)

	it("loops the Shotgun's reload, one loop per shell", function()
		expect(GUNS.Shotgun.clips.reload.loop).toBe(true)
		expect(GUNS.M57.clips.reload.loop).toBe(false)
	end)

	it("aims every long gun straight down the middle of the view", function()
		for name, gun in GUNS do
			if name ~= "EnergyPistol" then
				local value = gun.poses.Aim.Gun
				expect(math.abs(value[1]) < 0.001).toBe(true)
			end
		end
	end)

	it("knows the part of every soldier arm piece", function()
		local parts = {}
		for _, bone in BONES do
			parts[bone] = true
		end
		local count = 0
		for _, piece in SoldierRig.arms do
			count += 1
			expect(parts[piece.part] == true).toBe(true)
			expect(isFrame(piece.offset)).toBe(true)
			expect(SoldierRig.colors[piece.material] ~= nil).toBe(true)
		end
		expect(count > 0).toBe(true)
	end)
end)
