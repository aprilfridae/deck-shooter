local harness = require("./harness")
local TowerRules = require("../src/shared/Guns/TowerRules")

local describe, it, expect = harness.describe, harness.it, harness.expect

describe("TowerRules", function()
	it("starts in arena 4 with the coin's team attacking and the other owning the tower", function()
		local state = TowerRules.new(2)
		expect(state.arena).toBe(4)
		expect(state.attacker).toBe(2)
		expect(TowerRules.defender(state)).toBe(1)
		expect(TowerRules.roundSeconds(state)).toBe(40)
	end)

	it("gives home arenas and the tiebreaker 60 seconds", function()
		expect(TowerRules.roundSeconds({ arena = 1 } :: any)).toBe(60)
		expect(TowerRules.roundSeconds({ arena = 7 } :: any)).toBe(60)
		expect(TowerRules.roundSeconds({ arena = TowerRules.TIEBREAKER } :: any)).toBe(60)
	end)

	it("lets a living player capture within 6 studs of a tower that isn't theirs", function()
		expect(TowerRules.canCapture(1, 2, true, 5.9)).toBe(true)
		expect(TowerRules.canCapture(1, 2, true, 6.1)).toBe(false)
		expect(TowerRules.canCapture(1, 1, true, 1)).toBe(false)
		expect(TowerRules.canCapture(1, 2, false, 1)).toBe(false)
	end)

	it("gives the round to the owner at the time limit or on wiping the others", function()
		expect(TowerRules.roundResult(1, { 3, 2 }, false, false)).toBeNil()
		expect(TowerRules.roundResult(1, { 3, 2 }, true, false)).toBe(1)
		expect(TowerRules.roundResult(2, { 0, 1 }, false, false)).toBe(2)
		expect(TowerRules.roundResult(2, { 0, 0 }, false, false)).toBe(2)
	end)

	it("gives a team that wipes the owner 14 seconds to capture, past the clock", function()
		expect(TowerRules.capturing(1, { 0, 2 })).toBe(true)
		expect(TowerRules.roundResult(1, { 0, 2 }, true, false)).toBeNil()
		expect(TowerRules.roundResult(1, { 0, 2 }, true, true)).toBe(1)
		-- Once captured, the capturing team owns it and the old owner is already wiped.
		expect(TowerRules.roundResult(2, { 0, 2 }, false, false)).toBe(2)
	end)

	it("moves toward the loser's home, and the winner attacks next", function()
		local state = TowerRules.new(1)
		expect(TowerRules.finishRound(state, 1, 1)).toBeNil()
		expect(state.arena).toBe(5)
		expect(state.attacker).toBe(1)
		expect(TowerRules.finishRound(state, 2, 1)).toBeNil()
		expect(state.arena).toBe(4)
		expect(state.attacker).toBe(2)
	end)

	it("wins the match with a clean sweep of 4 rounds into the enemy home", function()
		local state = TowerRules.new(2)
		expect(TowerRules.finishRound(state, 2, 1)).toBeNil()
		expect(TowerRules.finishRound(state, 2, 1)).toBeNil()
		expect(TowerRules.finishRound(state, 2, 1)).toBeNil()
		expect(state.arena).toBe(1)
		expect(TowerRules.finishRound(state, 2, 1)).toBe(2)
		expect(state.wins[2]).toBe(4)
	end)

	it("sends 7-7 to one deciding round in the tiebreaker, with random roles", function()
		local state = TowerRules.new(1)
		for _ = 1, 7 do
			expect(TowerRules.finishRound(state, 1, 2)).toBeNil()
			expect(TowerRules.finishRound(state, 2, 2)).toBeNil()
		end
		expect(state.rounds).toBe(14)
		expect(state.arena).toBe(TowerRules.TIEBREAKER)
		expect(state.attacker).toBe(2)
		expect(TowerRules.finishRound(state, 1, 2)).toBe(1)
	end)

	it("gives the match to more round wins if the limit comes any other way", function()
		local state = { arena = 3, wins = { 8, 6 }, rounds = 14, attacker = 1 } :: any
		expect(TowerRules.finishRound(state, 2, 1)).toBe(1)
	end)
end)
