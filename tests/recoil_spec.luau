local harness = require("./harness")
local GunConfig = require("../src/shared/Guns/GunConfig")
local Recoil = require("../src/client/Recoil")

local describe, it, expect = harness.describe, harness.it, harness.expect

local STEP = 1 / 240
local TEST_GUN = {
	pattern = { { 2, 4, 1 }, { 4, 6, -2 } },
	recovery = 10,
}

-- Fires a spray and returns where each bullet went, relative to the original aim.
local function spray(gun: any, shots: number, interval: number): { { number } }
	local viewPitch, viewYaw = 0, 0
	local bullets = {}
	for _ = 1, shots do
		local pitch, yaw = Recoil.aimOffset(gun)
		table.insert(bullets, { viewPitch + pitch, viewYaw + yaw })
		Recoil.kick()
		for _ = 1, math.floor(interval / STEP) do
			local stepPitch, stepYaw = Recoil.advance(STEP)
			viewPitch += stepPitch
			viewYaw += stepYaw
		end
	end
	return bullets
end

describe("Spray pattern", function()
	it("reads points between and past the pattern", function()
		local pitch, yaw = Recoil.sample(TEST_GUN.pattern, 1)
		expect(pitch).toBeCloseTo(2)
		expect(yaw).toBeCloseTo(0.5)
		pitch, yaw = Recoil.sample(TEST_GUN.pattern, 3)
		expect(pitch).toBeCloseTo(5)
		expect(yaw).toBeCloseTo(-0.5)
		pitch = Recoil.sample(TEST_GUN.pattern, 99)
		expect(pitch).toBeCloseTo(6)
	end)

	it("puts the first bullet exactly on the aim", function()
		Recoil.reset()
		local bullets = spray(TEST_GUN, 1, 0.05)
		expect(bullets[1][1]).toBeCloseTo(0)
		expect(bullets[1][2]).toBeCloseTo(0)
	end)

	it("puts each later bullet on the pattern", function()
		Recoil.reset()
		local bullets = spray(TEST_GUN, 5, 0.05)
		expect(bullets[3][1]).toBeCloseTo(math.rad(4), 1e-4)
		expect(bullets[3][2]).toBeCloseTo(math.rad(1), 1e-4)
		expect(bullets[5][1]).toBeCloseTo(math.rad(6), 1e-4)
		expect(bullets[5][2]).toBeCloseTo(math.rad(-2), 1e-4)
	end)

	it("gives the same spray every time", function()
		Recoil.reset()
		local first = spray(TEST_GUN, 5, 0.05)
		Recoil.reset()
		local second = spray(TEST_GUN, 5, 0.05)
		for i, bullet in first do
			expect(second[i][1]).toBeCloseTo(bullet[1], 1e-9)
			expect(second[i][2]).toBeCloseTo(bullet[2], 1e-9)
		end
	end)

	it("moves the camera less than the bullets", function()
		Recoil.reset()
		Recoil.aimOffset({ pattern = TEST_GUN.pattern, recovery = 0 })
		Recoil.kick()
		Recoil.kick()
		Recoil.kick()
		Recoil.kick()
		local view = 0
		for _ = 1, 28 do
			view += (Recoil.advance(STEP))
		end
		expect(view > math.rad(6) * Recoil.VIEW_SHARE * 0.9).toBe(true)
		expect(view <= math.rad(6) * Recoil.VIEW_SHARE).toBe(true)
	end)

	it("swings the camera sideways by the same share as it rises", function()
		Recoil.reset()
		Recoil.aimOffset({ pattern = { { 1, 4, 2 } }, recovery = 0 })
		Recoil.kick()
		local up, side = 0, 0
		for _ = 1, 28 do
			local stepUp, stepSide = Recoil.advance(STEP)
			up += stepUp
			side += stepSide
		end
		expect(side > 0).toBe(true)
		expect(side).toBeCloseTo(up / 2, 1e-9)
	end)

	it("uses Counter-Strike's camera share", function()
		expect(Recoil.VIEW_SHARE).toBe(0.45)
	end)

	it("only falls after firing stops", function()
		Recoil.reset()
		spray(TEST_GUN, 4, 0.05)
		for _ = 1, 60 do
			Recoil.advance(STEP)
		end
		for _ = 1, 240 do
			expect((Recoil.advance(STEP)) <= 0).toBe(true)
		end
	end)

	it("falls in a straight line, not back along the pattern", function()
		Recoil.reset()
		spray({ pattern = { { 2, 4, 6 }, { 4, 8, -6 } }, recovery = 10 }, 4, 0.05)
		for _ = 1, 120 do
			Recoil.advance(STEP)
		end
		local firstUp, firstSide = Recoil.advance(STEP)
		for _ = 1, 240 do
			local up, side = Recoil.advance(STEP)
			expect(side * firstUp).toBeCloseTo(up * firstSide, 1e-9)
		end
	end)

	it("rises from where the camera is when firing starts again mid-fall", function()
		Recoil.reset()
		local gun = { pattern = { { 4, 8, 0 }, { 8, 16, 0 } }, recovery = 1 }
		spray(gun, 4, 0.05)
		for _ = 1, 120 do
			Recoil.advance(STEP)
		end
		Recoil.aimOffset(gun)
		Recoil.kick()
		local rise = 0
		for _ = 1, 28 do
			rise += (Recoil.advance(STEP))
		end
		expect(rise <= math.rad(2) * Recoil.VIEW_SHARE).toBe(true)
	end)

	it("recovers after firing stops, so the next first bullet is accurate", function()
		Recoil.reset()
		spray(TEST_GUN, 4, 0.05)
		local view = 0
		for _ = 1, 240 * 3 do
			view += (Recoil.advance(STEP))
		end
		local pitch, yaw = Recoil.aimOffset(TEST_GUN)
		expect(math.abs(pitch) < 1e-3).toBe(true)
		expect(math.abs(yaw) < 1e-3).toBe(true)
	end)

	it("starts the new gun's pattern from the beginning after a swap", function()
		Recoil.reset()
		spray(TEST_GUN, 4, 0.05)
		local other = { pattern = { { 1, 9, 0 } }, recovery = 10 }
		local pitch = Recoil.aimOffset(other)
		expect(pitch <= 0).toBe(true)
	end)
end)

describe("Gun patterns", function()
	it("gives every gun a pattern that fits its magazine and a recovery rate", function()
		for id, gun in GunConfig.guns do
			local last = 0
			for _, point in gun.pattern do
				expect(point[1] > last).toBe(true)
				last = point[1]
			end
			expect(last <= gun.mag).toBe(true)
			expect(gun.recovery > 0).toBe(true)
			expect(gun.recoil).toBeNil()
		end
	end)

	it("makes the AK-47 climb harder than the M4", function()
		local ak = Recoil.sample(GunConfig.guns.AK47.pattern, 30)
		local m4 = Recoil.sample(GunConfig.guns.M4.pattern, 30)
		expect(ak > m4).toBe(true)
	end)
end)
