local harness = require("./harness")
local CardSpin = require("../src/shared/Guns/Hud/CardSpin")

local describe, it, expect = harness.describe, harness.it, harness.expect

local function near(a: number, b: number): boolean
	return math.abs(a - b) < 1e-6
end

describe("CardSpin", function()
	it("turns with the drag and stops tipping past the limit", function()
		local yaw, pitch = CardSpin.drag(0, 0, 100, 10000)
		expect(yaw > 0).toBe(true)
		expect(near(pitch, CardSpin.PITCH_LIMIT)).toBe(true)
		local _, up = CardSpin.drag(0, 0, 0, -10000)
		expect(near(up, -CardSpin.PITCH_LIMIT)).toBe(true)
	end)

	it("comes to rest on whichever side is nearest", function()
		expect(near(CardSpin.rest(0.4), 0)).toBe(true)
		expect(near(CardSpin.rest(2), math.pi)).toBe(true)
		expect(near(CardSpin.rest(-2), -math.pi)).toBe(true)
		expect(near(CardSpin.rest(7), 2 * math.pi)).toBe(true)
	end)

	it("settles towards its target at any frame rate", function()
		local coarse = CardSpin.settle(1, 0, 0.1)
		local fine = 1
		for _ = 1, 10 do
			fine = CardSpin.settle(fine, 0, 0.01)
		end
		expect(coarse > 0 and coarse < 1).toBe(true)
		expect(near(coarse, fine)).toBe(true)
	end)

	it("spins once and grows as it arrives", function()
		local spin, scale = CardSpin.enter(0)
		expect(near(spin, 2 * math.pi)).toBe(true)
		expect(scale < 1).toBe(true)
		local finalSpin, finalScale = CardSpin.enter(CardSpin.ENTER_TIME)
		expect(near(finalSpin, 0)).toBe(true)
		expect(near(finalScale, 1)).toBe(true)
		expect(near(CardSpin.enter(CardSpin.ENTER_TIME * 5), 0)).toBe(true)
	end)

	it("ignores a click off the card just after it opens, so a double click doesn't close it", function()
		expect(CardSpin.canClose(0.1)).toBe(false)
		expect(CardSpin.canClose(CardSpin.CLOSE_DELAY)).toBe(true)
	end)

	it("shrinks away as it leaves", function()
		expect(near(CardSpin.leave(0), 1)).toBe(true)
		expect(near(CardSpin.leave(CardSpin.LEAVE_TIME), 0)).toBe(true)
		expect(near(CardSpin.leave(CardSpin.LEAVE_TIME * 2), 0)).toBe(true)
	end)

	it("moves the shine across the card with how far it is turned", function()
		expect(near(CardSpin.shine(0), 0)).toBe(true)
		expect(near(CardSpin.shine(100), 1)).toBe(true)
		expect(near(CardSpin.shine(-100), -1)).toBe(true)
	end)
end)
