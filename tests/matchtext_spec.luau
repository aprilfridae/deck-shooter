local harness = require("./harness")
local MatchText = require("../src/shared/Guns/Hud/MatchText")

local describe, it, expect = harness.describe, harness.it, harness.expect

local function state(phase: string, extra: { [string]: any }?)
	local result = { phase = phase, round = 3, mine = 1, left = 0 } :: any
	for key, value in extra or {} do
		result[key] = value
	end
	return result
end

describe("MatchText", function()
	it("shows the time left as minutes and seconds", function()
		expect(MatchText.clock(90)).toBe("1:30")
		expect(MatchText.clock(9.2)).toBe("0:10")
		expect(MatchText.clock(-3)).toBe("0:00")
	end)

	it("counts the start down to FIGHT", function()
		expect(MatchText.banner(state("Countdown", { left = 2.9 }))).toBe("3")
		expect(MatchText.banner(state("Countdown", { left = 0.7 }))).toBe("1")
		expect(MatchText.banner(state("Countdown", { left = 0.2 }))).toBe("FIGHT")
		expect(MatchText.banner(state("Playing"))).toBe("")
	end)

	it("says who took the round from the player's side", function()
		expect(MatchText.banner(state("Between", { roundWinner = 1 }))).toBe("ROUND WON")
		expect(MatchText.banner(state("Between", { roundWinner = 2 }))).toBe("ROUND LOST")
		expect(MatchText.banner(state("Between", { roundWinner = 0 }))).toBe("TIE")
	end)

	it("ends with victory, defeat, or neither when nobody was left", function()
		expect(MatchText.banner(state("Over", { winner = 1 }))).toBe("VICTORY")
		expect(MatchText.banner(state("Over", { winner = 2 }))).toBe("DEFEAT")
		expect(MatchText.banner(state("Over", { winner = 0 }))).toBe("MATCH OVER")
	end)

	it("names the round while it's on", function()
		expect(MatchText.line(state("Playing"))).toBe("ROUND 3")
	end)
end)
