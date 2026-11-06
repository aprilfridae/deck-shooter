local harness = require("./harness")
local Zones = require("../src/shared/Guns/Zones")

local describe, it, expect = harness.describe, harness.it, harness.expect

local function playerIn(zone: any)
	return {
		GetAttribute = function(_, name: string)
			return if name == "Zone" then zone else nil
		end,
	}
end

describe("Zones", function()
	it("blocks combat in the Outpost", function()
		expect(Zones.allowsCombat(Zones.Outpost)).toBe(false)
	end)

	it("allows combat in the test room", function()
		expect(Zones.allowsCombat(Zones.TestRoom)).toBe(true)
	end)

	it("reads the player's zone", function()
		expect(Zones.of(playerIn("TestRoom"))).toBe(Zones.TestRoom)
		expect(Zones.of(playerIn("Outpost"))).toBe(Zones.Outpost)
	end)

	it("treats a missing or unknown zone as the Outpost", function()
		expect(Zones.of(playerIn(nil))).toBe(Zones.Outpost)
		expect(Zones.of(playerIn("Arena"))).toBe(Zones.Outpost)
		expect(Zones.of(playerIn(7))).toBe(Zones.Outpost)
	end)

	it("makes every key false in the Outpost", function()
		local keys = Zones.filter(Zones.Outpost, { fire = true, reload = true })
		expect(keys.fire).toBe(false)
		expect(keys.reload).toBe(false)
	end)

	it("passes keys through in the test room", function()
		expect(Zones.filter(Zones.TestRoom, { fire = true }).fire).toBe(true)
	end)
end)

describe("Zones.autoRotates", function()
	it("turns the body with movement only in the Outpost", function()
		expect(Zones.autoRotates(Zones.Outpost)).toBe(true)
		expect(Zones.autoRotates(Zones.TestRoom)).toBe(false)
	end)
end)
