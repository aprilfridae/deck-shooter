local harness = require("./harness")
local Weapon = require("../src/shared/Guns/Weapon")

local describe, it, expect = harness.describe, harness.it, harness.expect

local function emptyOut(loadout: any, gap: number)
	local t = 0
	while Weapon.ammo(loadout) > 0 do
		Weapon.tryFire(loadout, t)
		t += gap
	end
	return t
end

describe("Weapon", function()
	it("gives each class its guns and full magazines", function()
		local loadout = Weapon.newLoadout("Assault", "AK47")
		expect(loadout.slots.primary.gunId).toBe("AK47")
		expect(loadout.slots.sidearm.gunId).toBe("Pistol")
		expect(loadout.active).toBe("primary")
		expect(Weapon.ammo(loadout)).toBe(30)
	end)

	it("ignores the rifle choice on other classes", function()
		expect(Weapon.newLoadout("Rusher", "AK47").slots.primary.gunId).toBe("SMG")
	end)

	it("fires at no more than the gun's rate", function()
		local loadout = Weapon.newLoadout("Assault", "M4")
		expect(Weapon.tryFire(loadout, 0)).toBe(true)
		expect(Weapon.tryFire(loadout, 0.05)).toBe(false)
		expect(Weapon.tryFire(loadout, 0.1)).toBe(true)
	end)

	it("allows a small network tolerance on the fire rate", function()
		local loadout = Weapon.newLoadout("Assault", "M4")
		Weapon.tryFire(loadout, 0)
		expect(Weapon.tryFire(loadout, 0.094)).toBe(false)
		expect(Weapon.tryFire(loadout, 0.096)).toBe(true)
	end)

	it("uses one round for each shot", function()
		local loadout = Weapon.newLoadout("Assault", "M4")
		Weapon.tryFire(loadout, 0)
		expect(Weapon.ammo(loadout)).toBe(29)
	end)

	it("refuses to fire on an empty magazine", function()
		local loadout = Weapon.newLoadout("Assault", "M4")
		local t = emptyOut(loadout, 0.2)
		expect(Weapon.tryFire(loadout, t + 1)).toBe(false)
		expect(Weapon.ammo(loadout)).toBe(0)
	end)

	it("refills after the reload time", function()
		local loadout = Weapon.newLoadout("Assault", "M4")
		Weapon.tryFire(loadout, 0)
		expect(Weapon.startReload(loadout, 1)).toBe(true)
		Weapon.update(loadout, 1.96)
		expect(Weapon.ammo(loadout)).toBe(29)
		Weapon.update(loadout, 1.97)
		expect(Weapon.ammo(loadout)).toBe(30)
	end)

	it("loads a shotgun one shell at a time, and a shot ends the reload", function()
		local loadout = Weapon.newLoadout("Breacher", nil)
		emptyOut(loadout, 1)
		Weapon.startReload(loadout, 10)
		Weapon.update(loadout, 11.1)
		expect(Weapon.ammo(loadout)).toBe(2)
		expect(Weapon.tryFire(loadout, 11.2)).toBe(true)
		expect(Weapon.ammo(loadout)).toBe(1)
		Weapon.update(loadout, 20)
		expect(Weapon.ammo(loadout)).toBe(1)
	end)

	it("stops loading shells at a full magazine", function()
		local loadout = Weapon.newLoadout("Breacher", nil)
		Weapon.tryFire(loadout, 0)
		Weapon.startReload(loadout, 2)
		Weapon.update(loadout, 50)
		expect(Weapon.ammo(loadout)).toBe(6)
	end)

	it("will not reload a full magazine", function()
		expect(Weapon.startReload(Weapon.newLoadout("Assault", "M4"), 1)).toBe(false)
	end)

	it("will not restart a reload already running", function()
		local loadout = Weapon.newLoadout("Assault", "M4")
		Weapon.tryFire(loadout, 0)
		Weapon.startReload(loadout, 1)
		expect(Weapon.startReload(loadout, 2)).toBe(false)
		Weapon.update(loadout, 3.2)
		expect(Weapon.ammo(loadout)).toBe(30)
	end)

	it("refills both guns", function()
		local loadout = Weapon.newLoadout("Assault", "M4")
		Weapon.tryFire(loadout, 0)
		Weapon.swap(loadout, "sidearm", 1)
		Weapon.tryFire(loadout, 1)
		Weapon.refill(loadout)
		expect(Weapon.ammo(loadout)).toBe(12)
		Weapon.swap(loadout, "primary", 2)
		expect(Weapon.ammo(loadout)).toBe(30)
	end)

	it("rejects an unknown slot", function()
		expect(Weapon.swap(Weapon.newLoadout("Assault", "M4"), "knife", 0)).toBe(false)
	end)

	-- Review Focus 2
	it("refuses to fire during a reload", function()
		local loadout = Weapon.newLoadout("Assault", "M4")
		Weapon.tryFire(loadout, 0)
		Weapon.startReload(loadout, 1)
		expect(Weapon.tryFire(loadout, 1.5)).toBe(false)
		expect(Weapon.ammo(loadout)).toBe(29)
	end)

	-- Review Focus 3
	it("cancels a reload on swap and keeps each gun's ammo", function()
		local loadout = Weapon.newLoadout("Assault", "M4")
		Weapon.tryFire(loadout, 0)
		Weapon.startReload(loadout, 1)
		expect(Weapon.swap(loadout, "sidearm", 1.5)).toBe(true)
		expect(Weapon.ammo(loadout)).toBe(12)
		Weapon.update(loadout, 5)
		Weapon.swap(loadout, "primary", 5)
		expect(Weapon.ammo(loadout)).toBe(29)
	end)
end)

describe("Weapon.isUntouched", function()
	it("is true for a fresh loadout", function()
		expect(Weapon.isUntouched(Weapon.newLoadout("Assault", "M4"))).toBe(true)
	end)

	it("is false after a shot, on either gun", function()
		local loadout = Weapon.newLoadout("Assault", "M4")
		Weapon.tryFire(loadout, 10)
		expect(Weapon.isUntouched(loadout)).toBe(false)
		Weapon.swap(loadout, "sidearm", 11)
		expect(Weapon.isUntouched(loadout)).toBe(false)
	end)

	it("is false during a reload and true once it has finished", function()
		local loadout = Weapon.newLoadout("Assault", "M4")
		Weapon.tryFire(loadout, 10)
		Weapon.startReload(loadout, 11)
		expect(Weapon.isUntouched(loadout)).toBe(false)
		Weapon.update(loadout, 100)
		expect(Weapon.isUntouched(loadout)).toBe(true)
	end)
end)

describe("Overclock hooks", function()
	it("fires faster with a fire-rate bonus", function()
		local loadout = Weapon.newLoadout("Assault", "M4") -- 0.1s between shots
		loadout.fireRateBonus = 0.18
		expect(Weapon.tryFire(loadout, 1)).toBe(true)
		expect(Weapon.tryFire(loadout, 1.08)).toBe(false)
		expect(Weapon.tryFire(loadout, 1.09)).toBe(true)
	end)

	it("starts each life with no fire-rate bonus", function()
		expect(Weapon.newLoadout("Assault", "M4").fireRateBonus).toBe(0)
	end)
end)

describe("Weapon.nextShotTime", function()
	it("waits until the gun is ready", function()
		expect(Weapon.nextShotTime(10, 0.1, 10.09)).toBeNil()
	end)

	it("keeps shots an exact interval apart when a frame lands late", function()
		expect(Weapon.nextShotTime(10, 0.1, 10.116)).toBeCloseTo(10.1)
	end)

	it("holds the average rate at 60 frames a second", function()
		local shot = 0
		local shots = 0
		for frame = 1, 600 do
			local due = Weapon.nextShotTime(shot, 0.1, frame / 60)
			if due then
				shot = due
				shots += 1
			end
		end
		expect(shots).toBe(100)
	end)

	it("starts fresh after a pause", function()
		expect(Weapon.nextShotTime(10, 0.1, 12)).toBe(12)
		expect(Weapon.nextShotTime(-math.huge, 0.1, 12)).toBe(12)
	end)
end)
