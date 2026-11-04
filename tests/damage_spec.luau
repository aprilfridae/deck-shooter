local harness = require("./harness")
local Combat = require("../src/shared/Guns/Combat")
local Damage = require("../src/shared/Guns/Damage")
local GunConfig = require("../src/shared/Guns/GunConfig")

local describe, it, expect = harness.describe, harness.it, harness.expect

local guns = GunConfig.guns

describe("GunConfig", function()
	it("matches the spec's primaries", function()
		local expected = {
			M4 = { 24, 600, 30, 2.2 },
			AK47 = { 24, 540, 30, 2.4 },
			SMG = { 17, 800, 32, 2.0 },
			Sniper = { 85, 50, 5, 3.0 },
			Shotgun = { 14, 75, 6, 0.5 },
		}
		for id, row in expected do
			local gun = guns[id]
			expect({ gun.body, gun.rpm, gun.mag, gun.reload }).toEqual(row)
		end
	end)

	it("matches the spec's sidearms", function()
		local expected = {
			Pistol = { 20, 400, 12, 1.4 },
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
		expect(GunConfig.classes.Assault).toEqual({ primaries = { "M4", "AK47" }, sidearm = "Pistol" })
		expect(GunConfig.classes.Rusher).toEqual({ primaries = { "SMG" }, sidearm = "MachinePistol" })
		expect(GunConfig.classes.Marksman).toEqual({ primaries = { "Sniper" }, sidearm = "Revolver" })
		expect(GunConfig.classes.Breacher).toEqual({ primaries = { "Shotgun" }, sidearm = "AutoPistol" })
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

	it("kills on a Sniper headshot, and has no falloff", function()
		expect(Damage.hit(guns.Sniper, 900, true)).toBe(Damage.KILL)
		expect(Damage.hit(guns.Sniper, 900, false)).toBe(85)
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
	end)
end)
