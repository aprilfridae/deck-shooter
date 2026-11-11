local harness = require("./harness")
local Settings = require("../src/shared/CardCore/Settings")

local describe, it, expect = harness.describe, harness.it, harness.expect

describe("Settings", function()
	it("starts on the defaults", function()
		expect(Settings.new().fieldOfView).toBe(80)
		expect(Settings.new().keys.sprint).toBeNil()
		expect(Settings.new().keys.crouch).toBe("LeftShift")
	end)

	it("moves an old save's default crouch keys to the new ones", function()
		local keys = Settings.new().keys
		keys.sprint, keys.crouch, keys.crouchAlt = "LeftShift", "C", "LeftControl"
		local cleaned = Settings.clean({ keys = keys }).keys
		expect(cleaned.crouch).toBe("LeftShift")
		expect(cleaned.crouchAlt).toBe("C")
		expect(cleaned.sprint).toBeNil()
	end)

	it("keeps an old save's own crouch key", function()
		local keys = Settings.new().keys
		keys.sprint, keys.crouch, keys.crouchAlt = "LeftShift", "V", "LeftControl"
		expect(Settings.clean({ keys = keys }).keys.crouch).toBe("V")
	end)

	it("replaces bad values one field at a time", function()
		local clean = Settings.clean({ music = 0.5, game = "loud", fieldOfView = 500, sensitivity = 0 / 0 })
		expect(clean.music).toBe(0.5)
		expect(clean.game).toBe(1)
		expect(clean.fieldOfView).toBe(80)
		expect(clean.sensitivity).toBe(1)
		expect(Settings.clean("nonsense").menu).toBe(1)
	end)

	it("gives an unknown key its action's default", function()
		expect(Settings.clean({ keys = { reload = "Banana" } }).keys.reload).toBe("R")
	end)

	it("resets every key if two actions share one", function()
		local defaults = Settings.new().keys
		local clean = Settings.clean({ keys = { reload = "Q", jump = "Q" } })
		expect(clean.keys.jump).toBe(defaults.jump)
		expect(clean.keys.reload).toBe(defaults.reload)
	end)

	it("swaps the two actions when a key is in use, leaving the input alone", function()
		local defaults = Settings.new().keys
		local swapped = Settings.rebind(defaults, "jump", "R")
		expect(swapped.jump).toBe("R")
		expect(swapped.reload).toBe("Space")
		expect(defaults.jump).toBe("Space")
	end)

	it("won't bind reserved keys or unknown actions", function()
		local defaults = Settings.new().keys
		expect(Settings.rebind(defaults, "jump", "W")).toBeNil()
		expect(Settings.rebind(defaults, "jump", "B")).toBeNil()
		expect(Settings.rebind(defaults, "nothing", "Q")).toBeNil()
	end)

	it("gives every action a default", function()
		local defaults = Settings.new().keys
		for _, action in Settings.actions do
			expect(defaults[action.id] ~= nil).toBe(true)
		end
	end)

	it("names keys for the screen", function()
		expect(Settings.keyLabel("Three")).toBe("3")
		expect(Settings.keyLabel("LeftShift")).toBe("L SHIFT")
		expect(Settings.keyLabel("MouseButton1")).toBe("MOUSE 1")
		expect(Settings.keyLabel("Q")).toBe("Q")
	end)

	it("binds arrows, punctuation and the number pad", function()
		local defaults = Settings.new().keys
		expect(Settings.rebind(defaults, "jump", "Up").jump).toBe("Up")
		expect(Settings.rebind(defaults, "jump", "Comma").jump).toBe("Comma")
		expect(Settings.rebind(defaults, "jump", "KeypadOne").jump).toBe("KeypadOne")
		expect(Settings.rebind(defaults, "jump", "CapsLock").jump).toBe("CapsLock")
	end)

	it("won't bind the chat key", function()
		expect(Settings.rebind(Settings.new().keys, "jump", "Slash")).toBeNil()
	end)

	it("keeps saved settings when only one field changed before the save arrived", function()
		local saved = Settings.clean({ music = 0.2, keys = { jump = "Q" } })
		local merged = Settings.merge(saved, { game = 0.5 })
		expect(merged.music).toBe(0.2)
		expect(merged.keys.jump).toBe("Q")
		expect(merged.game).toBe(0.5)
	end)

	it("gives each slider its range", function()
		local low, high = Settings.range("fieldOfView")
		expect(low).toBe(60)
		expect(high).toBe(100)
	end)
end)
