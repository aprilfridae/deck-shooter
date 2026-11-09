local harness = require("./harness")
local Combat = require("../src/shared/Guns/Combat")
local Damage = require("../src/shared/Guns/Damage")
local GunConfig = require("../src/shared/Guns/GunConfig")
local GunSounds = require("../src/shared/Guns/GunSounds")
local Packs = require("../src/shared/CardCore/Packs")

local describe, it, expect = harness.describe, harness.it, harness.expect

local guns = GunConfig.guns

describe("GunConfig", function()
	it("matches the spec's primaries", function()
		local expected = {
			M4 = { 24, 600, 30, 0.985 },
			AK47 = { 24, 540, 30, 0.985 },
			SMG = { 17, 800, 32, 2.0 },
			Sniper = { 85, 50, 1, 1.714 },
			Shotgun = { 14, 75, 6, 0.5 },
		}
		for id, row in expected do
			local gun = guns[id]
			expect({ gun.body, gun.rpm, gun.mag, gun.reload }).toEqual(row)
		end
	end)

	it("matches the spec's sidearms", function()
		local expected = {
			Pistol = { 20, 400, 12, 0.964 },
			MachinePistol = { 13, 900, 20, 1.6 },
			Revolver = { 45, 150, 6, 2.2 },
			AutoPistol = { 16, 550, 15, 1.5 },
		}
		for id, row in expected do
			local gun = guns[id]
			expect({ gun.body, gun.rpm, gun.mag, gun.reload }).toEqual(row)
		end
	end)

	it("fires 8 shotgun pellets and loads one shell at a time", function()
		expect(guns.Shotgun.pellets).toBe(8)
		expect(guns.Shotgun.perShell).toBe(true)
		expect(guns.M4.pellets).toBe(1)
		expect(guns.M4.perShell).toBe(false)
	end)

	it("gives the right guns to each class", function()
		expect(GunConfig.classes.Assault).toEqual({ primaries = { "M4" }, sidearm = "Pistol" })
		expect(GunConfig.classes.Rusher).toEqual({ primaries = { "SMG" }, sidearm = "Pistol" })
		expect(GunConfig.classes.Marksman).toEqual({ primaries = { "Sniper" }, sidearm = "Pistol" })
		expect(GunConfig.classes.Breacher).toEqual({ primaries = { "Shotgun" }, sidearm = "Pistol" })
	end)

	it("makes only the four automatic guns automatic", function()
		local automatic = { M4 = true, AK47 = true, SMG = true, MachinePistol = true }
		for id, gun in guns do
			expect(gun.automatic).toBe(automatic[id] == true)
		end
	end)
end)

describe("Damage", function()
	it("keeps full damage to the near range, then falls in a line", function()
		expect(Damage.hit(guns.M4, 90, false)).toBe(24)
		expect(Damage.hit(guns.M4, 135, false)).toBeCloseTo(20.4)
		expect(Damage.hit(guns.M4, 180, false)).toBeCloseTo(16.8)
		expect(Damage.hit(guns.M4, 500, false)).toBeCloseTo(16.8)
	end)

	it("falls to 60% on the SMG", function()
		expect(Damage.hit(guns.SMG, 40, false)).toBe(17)
		expect(Damage.hit(guns.SMG, 90, false)).toBeCloseTo(10.2)
	end)

	it("doubles an M4 headshot", function()
		expect(Damage.hit(guns.M4, 10, true)).toBe(48)
	end)

	it("kills on an AK-47 headshot at any range", function()
		expect(Damage.hit(guns.AK47, 500, true)).toBe(Damage.KILL)
	end)

	it("kills on any Sniper hit, head or body, at any range", function()
		expect(Damage.hit(guns.Sniper, 900, true)).toBe(Damage.KILL)
		expect(Damage.hit(guns.Sniper, 900, false)).toBe(Damage.KILL)
		expect(Damage.hit(guns.Sniper, 5, false)).toBe(Damage.KILL)
	end)

	it("scales each shotgun pellet to nothing by 45 studs", function()
		expect(Damage.hit(guns.Shotgun, 15, false)).toBe(14)
		expect(Damage.hit(guns.Shotgun, 30, false)).toBeCloseTo(7)
		expect(Damage.hit(guns.Shotgun, 45, false)).toBe(0)
		expect(Damage.hit(guns.Shotgun, 15, true)).toBe(28)
	end)

	it("doubles sidearm headshots", function()
		for _, id in { "Pistol", "MachinePistol", "Revolver", "AutoPistol" } do
			expect(Damage.hit(guns[id], 10, true)).toBe(guns[id].body * 2)
		end
	end)

	it("fades sidearms to 70% by 90 studs", function()
		expect(Damage.hit(guns.Pistol, 40, false)).toBe(20)
		expect(Damage.hit(guns.Pistol, 90, false)).toBeCloseTo(14)
	end)
end)

describe("Shield", function()
	it("takes damage on the shield and loses what is left over", function()
		local left, broke = Combat.absorb(20, 15)
		expect(left).toBe(5)
		expect(broke).toBe(false)
		left, broke = Combat.absorb(20, 50)
		expect(left).toBe(0)
		expect(broke).toBe(true)
	end)

	it("breaks a full shield on an instant-kill headshot", function()
		local left, broke = Combat.absorb(64, Damage.KILL)
		expect(left).toBe(0)
		expect(broke).toBe(true)
		left, broke = Combat.absorb(1, Damage.KILL)
		expect(left).toBe(0)
		expect(broke).toBe(true)
	end)
end)

describe("GunSounds", function()
	it("has uploaded takes for every gun a class can use", function()
		for _, class in GunConfig.classes do
			local guns = table.clone(class.primaries)
			table.insert(guns, class.sidearm)
			for _, gunId in guns do
				local takes = GunSounds.shots[gunId]
				expect(#takes >= 2).toBe(true)
				for _, sound in takes do
					expect(string.match(sound, "^rbxassetid://%d+$") ~= nil).toBe(true)
				end
			end
		end
	end)

	it("has an opening sound for every pack rarity", function()
		for _, pack in Packs.ids do
			expect(string.match(GunSounds.packOpens[pack] or "", "^rbxassetid://%d+$") ~= nil).toBe(true)
		end
	end)
end)

describe("GunSounds.startOffset", function()
	it("skips as much of the silent padding as the shot is late", function()
		expect(GunSounds.startOffset(0.008)).toBeCloseTo(0.008)
	end)

	it("never skips past the padding into the shot", function()
		expect(GunSounds.startOffset(0.05)).toBeCloseTo(GunSounds.paddingSeconds)
	end)

	it("plays from the start when a shot isn't late", function()
		expect(GunSounds.startOffset(0)).toBe(0)
		expect(GunSounds.startOffset(-0.01)).toBe(0)
	end)
end)

describe("GunSounds.hitSound", function()
	it("matches what the shot did, with a kill first", function()
		expect(GunSounds.hitSound(false, false)).toBe(GunSounds.hits.body)
		expect(GunSounds.hitSound(true, false)).toBe(GunSounds.hits.head)
		expect(GunSounds.hitSound(false, true)).toBe(GunSounds.hits.kill)
		expect(GunSounds.hitSound(true, true)).toBe(GunSounds.hits.kill)
	end)

	it("has an uploaded sound for every hit and the hurt sound", function()
		for _, sound in { GunSounds.hits.body, GunSounds.hits.head, GunSounds.hits.kill, GunSounds.hurt } do
			expect(string.match(sound, "^rbxassetid://%d+$") ~= nil).toBe(true)
		end
	end)
end)

describe("GunSounds.hurtPlays", function()
	it("plays when damage leaves you at 20 health or less", function()
		expect(GunSounds.hurtPlays(45, 20)).toBe(true)
		expect(GunSounds.hurtPlays(20, 7)).toBe(true)
	end)

	it("stays quiet above 20 health", function()
		expect(GunSounds.hurtPlays(100, 21)).toBe(false)
	end)

	it("stays quiet when health doesn't drop", function()
		expect(GunSounds.hurtPlays(20, 20)).toBe(false)
		expect(GunSounds.hurtPlays(0, 15)).toBe(false)
	end)

	it("stays quiet when the damage kills you", function()
		expect(GunSounds.hurtPlays(15, 0)).toBe(false)
	end)
end)
