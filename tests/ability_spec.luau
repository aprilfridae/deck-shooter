local harness = require("./harness")
local Ability = require("../src/shared/CardCore/Ability")
local Cards = require("../src/shared/CardCore/Cards")
local Config = require("../src/shared/CardCore/Config")
local MoveConfig = require("../src/shared/Movement/MoveConfig")
local MoveState = require("../src/shared/Movement/MoveState")

local describe, it, expect = harness.describe, harness.it, harness.expect

local deck = { { cardId = "phase_dash", tier = "Field" }, { cardId = "arc_mine", tier = "Prototype" } }

describe("Ability", function()
	it("accepts only whole slot numbers from 1 to 3", function()
		expect(Ability.parseSlot(1)).toBe(1)
		expect(Ability.parseSlot(3)).toBe(3)
		for _, bad in { 0, 4, 1.5, "1", 0 / 0, math.huge, {} } do
			expect(Ability.parseSlot(bad)).toBeNil()
		end
		expect(Ability.parseSlot(nil)).toBeNil()
	end)

	it("has no abilities before the deck loads", function()
		expect(#Ability.new(nil)).toBe(0)
		expect(Ability.ready(Ability.new(nil), 1, 0)).toBeNil()
	end)

	it("is ready at the start, then waits out the cooldown from the moment of use", function()
		local slots = Ability.new(deck)
		local slot = Ability.ready(slots, 1, 5)
		Ability.spend(slot, 5)
		expect(slot.readyAt).toBe(17)
		expect(Ability.ready(slots, 1, 5)).toBeNil()
		expect(Ability.ready(slots, 1, 16.9)).toBeNil()
		expect(Ability.ready(slots, 1, 17)).toBe(slot)
	end)

	it("does not spend a cooldown just by checking it", function()
		local slots = Ability.new(deck)
		Ability.ready(slots, 2, 5)
		expect(slots[2].readyAt).toBe(-math.huge)
	end)

	it("does not share the deck table it was given", function()
		local slots = Ability.new(deck)
		Ability.spend(slots[1], 1)
		expect(deck[1].readyAt).toBeNil()
	end)

	it("scales each perk by tier", function()
		expect(Ability.camoSeconds("Field")).toBeCloseTo(1.2)
		expect(Ability.camoSeconds("BlackSite")).toBeCloseTo(1.35)
		expect(Ability.camoSeconds("Prototype")).toBeCloseTo(1.5)
		expect(Ability.teamRevealSeconds("Field")).toBeCloseTo(1.6)
		expect(Ability.teamRevealSeconds("Prototype")).toBeCloseTo(2.5)
		expect(Ability.pushSpeed("Field")).toBeCloseTo(48)
		expect(Ability.mineVisibility("Field")).toBeCloseTo(0.2)
		expect(Ability.mineVisibility("BlackSite")).toBeCloseTo(0.1)
		expect(Ability.mineVisibility("Prototype")).toBeCloseTo(0)
	end)

	it("arms a mine after 1 second and triggers it within 6 studs", function()
		expect(Ability.mineTriggered(10, 10.9, 1)).toBe(false)
		expect(Ability.mineTriggered(10, 11, 6)).toBe(true)
		expect(Ability.mineTriggered(10, 11, 6.1)).toBe(false)
	end)

	-- The server sees a client's position late, so the guard must wait past that too.
	it("keeps the guard away until a dash is back under the speed limit", function()
		local SERVER_VIEW_DELAY = 0.3
		local fastest = Cards.stat("phase_dash", "Prototype", "distance") / Config.DashSeconds
		local sprinting = { moving = true, sprint = true, crouch = false, jump = false, grounded = true }
		local slowest = 0
		for landAfter = 0.05, 0.4, 0.05 do
			local s = MoveState.new()
			MoveState.finishDash(s, 16, fastest, 0)
			MoveState.step(s, sprinting, landAfter)
			local t = landAfter
			while MoveState.speed(s, t) > MoveConfig.SpeedLimit do
				t += 0.01
			end
			slowest = math.max(slowest, t)
		end
		expect(Config.DashGraceSeconds >= Config.DashSeconds + slowest + SERVER_VIEW_DELAY).toBe(true)
	end)

	it("slows only until the slow ends", function()
		expect(Ability.slowFactor(0.25, 10, 9)).toBeCloseTo(0.75)
		expect(Ability.slowFactor(0.25, 10, 10)).toBe(1)
	end)
end)
