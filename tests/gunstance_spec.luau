local harness = require("./harness")
local GunStance = require("../src/shared/Movement/GunStance")

local describe, it, expect = harness.describe, harness.it, harness.expect

local function input(overrides: { [string]: any }): any
	local base = {
		reloading = false,
		pose = "Normal",
		airborne = false,
		verticalSpeed = 0,
		flatSpeed = 0,
		sinceLanded = math.huge,
		sinceShot = math.huge,
		travel = 0,
	}
	for key, value in overrides do
		base[key] = value
	end
	return base
end

describe("GunStance.pick", function()
	it("stands still with nothing going on", function()
		expect(GunStance.pick(input({})).name).toBe("Stand")
	end)

	it("puts a reload ahead of everything", function()
		local pick = GunStance.pick(input({ reloading = true, pose = "Slide", airborne = true }))
		expect(pick.name).toBe("Reload")
	end)

	it("slides ahead of the air and the ground", function()
		expect(GunStance.pick(input({ pose = "Slide", airborne = true })).name).toBe("Slide")
	end)

	it("jumps while rising and falls after", function()
		expect(GunStance.pick(input({ airborne = true, verticalSpeed = 20 })).name).toBe("Jump_Up")
		expect(GunStance.pick(input({ airborne = true, verticalSpeed = -5 })).name).toBe("Fall")
	end)

	it("holds the landing for a moment", function()
		expect(GunStance.pick(input({ sinceLanded = 0.1, flatSpeed = 16 })).name).toBe("Land")
		expect(GunStance.pick(input({ sinceLanded = 0.3 })).name).toBe("Stand")
	end)

	it("keeps the gun up for a while after a shot", function()
		expect(GunStance.pick(input({ sinceShot = 0.05, flatSpeed = 16 })).name).toBe("Fire")
		expect(GunStance.pick(input({ sinceShot = GunStance.fireTime - 0.05 })).name).toBe("Fire")
		expect(GunStance.pick(input({ sinceShot = GunStance.fireTime + 0.05 })).name).toBe("Stand")
	end)

	it("crouches still or walks crouched", function()
		expect(GunStance.pick(input({ pose = "Crouch" })).name).toBe("Crouch_Idle")
		expect(GunStance.pick(input({ pose = "Crouch", flatSpeed = 8 })).name).toBe("Crouch_Walk")
	end)

	it("walks and sprints by speed", function()
		expect(GunStance.pick(input({ flatSpeed = 16 })).name).toBe("Walk_Contact")
		expect(GunStance.pick(input({ flatSpeed = 24 })).name).toBe("Sprint_Contact")
	end)

	it("steps through a four-beat stride, swapping legs halfway", function()
		local length = GunStance.stride.walk
		local names, mirrored = {}, {}
		for beat = 0, 3 do
			local pick = GunStance.pick(input({ flatSpeed = 16, travel = beat * length + 0.1 }))
			names[beat + 1], mirrored[beat + 1] = pick.name, pick.mirrored
		end
		expect(names).toEqual({ "Walk_Contact", "Walk_Pass", "Walk_Contact", "Walk_Pass" })
		expect(mirrored).toEqual({ false, false, true, true })
	end)
end)

describe("GunStance.mirror", function()
	it("swaps a joint across the body's middle", function()
		expect(GunStance.mirror({ 1, 2, 3, 0.1, 0.2, 0.3, 0.9 })).toEqual({ -1, 2, 3, 0.1, -0.2, -0.3, 0.9 })
	end)

	it("pairs every leg joint with the other side", function()
		for joint, other in GunStance.legSwap do
			expect(GunStance.legSwap[other]).toBe(joint)
		end
	end)
end)
