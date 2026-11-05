local harness = require("./harness")
local Combat = require("../src/shared/Guns/Combat")
local Damage = require("../src/shared/Guns/Damage")
local GunConfig = require("../src/shared/Guns/GunConfig")
local Spread = require("../src/shared/Guns/Spread")

local describe, it, expect = harness.describe, harness.it, harness.expect

local function degreesBetween(a: any, b: any): number
	local dot = a.x * b.x + a.y * b.y + a.z * b.z
	return math.deg(math.acos(math.clamp(dot, -1, 1)))
end

describe("Spread", function()
	it("gives other guns the same accuracy whatever they send", function()
		local m4 = GunConfig.guns.M4
		expect(Spread.angle(m4, false)).toBe(0.2)
		expect(Spread.angle(m4, true)).toBe(0.2)
	end)

	it("keeps the Longscope inaccurate unless scoped", function()
		local sniper = GunConfig.guns.Sniper
		expect(Spread.angle(sniper, false)).toBe(7)
		expect(Spread.angle(sniper, true)).toBe(0)
	end)

	it("lets only the Longscope aim", function()
		for id, gun in GunConfig.guns do
			expect(type(gun.spread)).toBe("number")
			expect(gun.hipSpread == nil).toBe(id ~= "Sniper")
			expect(gun.aimFov == nil).toBe(id ~= "Sniper")
		end
	end)

	it("spreads a direction by no more than the angle", function()
		local seed = 7
		local function rng(): number
			seed = (seed * 16807) % 2147483647
			return seed / 2147483647
		end
		local direction = { x = 0, y = 0.6, z = 0.8 }
		local widest = 0
		for _ = 1, 500 do
			local spread = Spread.apply(direction, 3, rng)
			expect(math.sqrt(spread.x ^ 2 + spread.y ^ 2 + spread.z ^ 2)).toBeCloseTo(1)
			widest = math.max(widest, degreesBetween(direction, spread))
		end
		expect(widest <= 3.0001).toBe(true)
		expect(widest > 2).toBe(true)
	end)

	it("works when the direction points straight up", function()
		local spread = Spread.apply({ x = 0, y = 1, z = 0 }, 2, function()
			return 0.5
		end)
		expect(spread.y < 1).toBe(true)
	end)

	it("leaves the direction alone at zero spread", function()
		local direction = { x = 0, y = 0, z = 1 }
		expect(Spread.apply(direction, 0, function()
			return 0.5
		end)).toEqual(direction)
	end)
end)

describe("Combat", function()
	it("takes damage from health and stops at zero", function()
		local health, killed = Combat.applyDamage(100, 24)
		expect(health).toBe(76)
		expect(killed).toBe(false)
		health, killed = Combat.applyDamage(10, 24)
		expect(health).toBe(0)
		expect(killed).toBe(true)
	end)

	it("kills from full health on Damage.KILL", function()
		local health, killed = Combat.applyDamage(100, Damage.KILL)
		expect(health).toBe(0)
		expect(killed).toBe(true)
	end)

	-- Review Focus 4
	it("does nothing to a target that is already dead", function()
		local health, killed = Combat.applyDamage(0, 50)
		expect(health).toBe(0)
		expect(killed).toBe(false)
	end)
end)
