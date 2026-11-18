local harness = require("./harness")
local MatchRules = require("../src/shared/Guns/MatchRules")

local describe, it, expect = harness.describe, harness.it, harness.expect

local function side(alive: number, health: number, present: number?)
	return { alive = alive, health = health, present = present or alive }
end

describe("MatchRules", function()
	it("keeps playing while both teams have someone alive", function()
		expect(MatchRules.roundResult(side(1, 50), side(2, 120), false)).toBe("Playing")
	end)

	it("ends a round at once on a wipe", function()
		expect(MatchRules.roundResult(side(1, 10), side(0, 0), false)).toBe(1)
		expect(MatchRules.roundResult(side(0, 0), side(3, 300), false)).toBe(2)
	end)

	it("replays a round when both teams are wiped together", function()
		expect(MatchRules.roundResult(side(0, 0), side(0, 0), false)).toBe("Replay")
	end)

	it("gives a timed-out round to more alive, then more health, else replays it", function()
		expect(MatchRules.roundResult(side(2, 20), side(1, 100), true)).toBe(1)
		expect(MatchRules.roundResult(side(1, 40), side(1, 60), true)).toBe(2)
		expect(MatchRules.roundResult(side(1, 60), side(1, 60), true)).toBe("Replay")
	end)

	it("forfeits a team with nobody left", function()
		expect(MatchRules.forfeit(side(0, 0, 0), side(1, 100))).toBe(2)
		expect(MatchRules.forfeit(side(1, 100), side(0, 0, 0))).toBe(1)
		expect(MatchRules.forfeit(side(0, 0, 1), side(1, 100))).toBeNil()
		expect(MatchRules.forfeit(side(0, 0, 0), side(0, 0, 0))).toBeNil()
	end)

	it("takes the match at 5 round wins", function()
		local rules = MatchRules.Elimination
		expect(MatchRules.matchWinner(rules, { 4, 4 }, 8)).toBeNil()
		expect(MatchRules.matchWinner(rules, { 5, 3 }, 8)).toBe(1)
		expect(MatchRules.matchWinner(rules, { 2, 5 }, 7)).toBe(2)
	end)

	it("can't run past 9 scored rounds without a winner", function()
		-- First to 5 settles it by round 9 at the latest, so the limit only matters for other settings.
		local rules = table.clone(MatchRules.Elimination)
		rules.winsNeeded = 10
		expect(MatchRules.matchWinner(rules, { 5, 4 }, 9)).toBe(1)
	end)

	it("splits a queue into alternating teams, first come first served", function()
		local one, two = MatchRules.split({ "a", "b", "c", "d", "e" }, 2)
		expect(one and table.concat(one, ",")).toBe("a,c")
		expect(two and table.concat(two, ",")).toBe("b,d")
		expect((MatchRules.split({ "a", "b", "c" }, 2))).toBeNil()
	end)

	it("knows the launch queues", function()
		expect(MatchRules.queue("Elimination1").size).toBe(1)
		expect(MatchRules.queue("Elimination3").size).toBe(3)
		expect(MatchRules.queue("Tower5")).toBeNil()
		expect(MatchRules.queue(42)).toBeNil()
	end)
end)
