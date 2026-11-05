local harness = require("./harness")
local HudText = require("../src/shared/Guns/Hud/HudText")

local describe, it, expect = harness.describe, harness.it, harness.expect

describe("HudText", function()
	it("rounds health up", function()
		expect(HudText.health(0.4)).toBe("1")
		expect(HudText.health(87)).toBe("87")
	end)

	it("shows no character as 0 health", function()
		expect(HudText.health(nil)).toBe("0")
	end)

	it("shows a shield rounded up, or nothing", function()
		expect(HudText.shield(39.2)).toBe("+40")
		expect(HudText.shield(nil)).toBe("")
		expect(HudText.shield(0)).toBe("")
	end)

	it("shows ammo, or nothing before it's set", function()
		expect(HudText.ammo(24)).toBe("24")
		expect(HudText.ammo(nil)).toBe("")
	end)

	it("labels the gun, or says it's reloading", function()
		expect(HudText.gunLabel("M57", 30, false)).toBe("M57  /  30")
		expect(HudText.gunLabel("M57", 30, true)).toBe("RELOADING")
	end)

	it("numbers ability keys from 3", function()
		expect(HudText.key(1)).toBe("3")
		expect(HudText.key(3)).toBe("5")
	end)

	it("fills cooldown segments", function()
		expect(HudText.filled(0, 10, 10)).toBe(10)
		expect(HudText.filled(5, 10, 10)).toBe(5)
		expect(HudText.filled(10, 10, 10)).toBe(0)
		expect(HudText.filled(-1, 10, 10)).toBe(10)
	end)

	it("treats a zero cooldown as ready", function()
		expect(HudText.filled(5, 0, 10)).toBe(10)
	end)

	it("scales with screen height, within limits", function()
		expect(HudText.scale(720)).toBe(1)
		expect(HudText.scale(1080)).toBe(1.5)
		expect(HudText.scale(400)).toBe(0.75)
		expect(HudText.scale(2160)).toBe(2)
	end)
end)
