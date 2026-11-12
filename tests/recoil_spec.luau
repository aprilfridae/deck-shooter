local harness = require("./harness")
local GunConfig = require("../src/shared/Guns/GunConfig")
local Recoil = require("../src/client/Recoil")

local describe, it, expect = harness.describe, harness.it, harness.expect

local STEP = 1 / 240

local function settle(seconds: number): (number, number)
	local pitch, yaw = 0, 0
	for _ = 1, math.floor(seconds / STEP) do
		local up, side = Recoil.advance(STEP)
		pitch += up
		yaw += side
	end
	return pitch, yaw
end

describe("Recoil", function()
	it("sends every bullet at the crosshair", function()
		Recoil.reset()
		for _ = 1, 30 do
			local pitch, yaw = Recoil.aimOffset(GunConfig.guns.M4)
			expect(pitch).toBe(0)
			expect(yaw).toBe(0)
			Recoil.kick()
			settle(0.1)
		end
	end)

	it("nudges the view up by less than the gun's kick, then comes back", function()
		Recoil.reset()
		local gun = GunConfig.guns.Sniper
		Recoil.aimOffset(gun)
		Recoil.kick(0)
		local peak, view = 0, 0
		for _ = 1, 240 do
			view += (Recoil.advance(STEP))
			peak = math.max(peak, view)
		end
		expect(peak > 0).toBe(true)
		expect(peak <= math.rad(gun.kick)).toBe(true)
		expect(math.abs(view) < math.rad(gun.kick) * 0.01).toBe(true)
	end)

	it("barely climbs over a whole magazine of the M57", function()
		Recoil.reset()
		local gun = GunConfig.guns.M4
		Recoil.aimOffset(gun)
		local climb = 0
		for _ = 1, gun.mag do
			Recoil.kick(1)
			climb += (settle(60 / gun.rpm))
		end
		expect(math.deg(climb) < 1).toBe(true)
	end)

	it("gives every gun a small kick", function()
		for _, gun in GunConfig.guns do
			expect(type(gun.kick)).toBe("number")
			expect(gun.kick > 0 and gun.kick <= 1.5).toBe(true)
			expect(gun.pattern).toBe(nil)
		end
	end)
end)
