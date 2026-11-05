local harness = require("./harness")
local MenuState = require("../src/shared/Guns/MenuState")

local describe, it, expect = harness.describe, harness.it, harness.expect

describe("MenuState", function()
	it("starts open", function()
		expect(MenuState.isOpen(MenuState.new())).toBe(true)
	end)

	it("closes on play and stays closed", function()
		local state = MenuState.new()
		MenuState.play(state)
		MenuState.play(state)
		expect(MenuState.isOpen(state)).toBe(false)
	end)

	it("makes every key false while open", function()
		local keys = MenuState.filter(MenuState.new(), { fire = true, jump = false })
		expect(keys.fire).toBe(false)
		expect(keys.jump).toBe(false)
	end)

	it("passes keys through after play", function()
		local state = MenuState.new()
		MenuState.play(state)
		expect(MenuState.filter(state, { fire = true }).fire).toBe(true)
	end)
end)
