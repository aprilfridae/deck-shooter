local harness = require("./harness")
local KillRewards = require("../src/shared/Guns/KillRewards")
local Timing = require("../src/shared/Guns/Hud/KillPopupTiming")

local describe, it, expect = harness.describe, harness.it, harness.expect

local function kill(fields: { [string]: any }?)
	local made = { victim = "a", pays = true, head = false, fullHealth = false, bullets = 3, distance = 40 }
	for key, value in fields or {} do
		made[key] = value
	end
	return made
end

local function names(lines): string
	local list = {}
	for _, line in lines do
		table.insert(list, line.name)
	end
	return table.concat(list, ", ")
end

describe("KillRewards", function()
	it("pays 500 for a plain kill", function()
		local lines, total = KillRewards.forShot({ kill() }, false, KillRewards.newRecord(), 0)
		expect(names(lines)).toBe("KILL")
		expect(total).toBe(500)
		expect(lines[1].amount).toBe(500)
	end)

	it("adds a line for a headshot, a one shot kill and a long shot", function()
		local shot = { kill({ head = true, fullHealth = true, bullets = 1, distance = 150 }) }
		local lines, total = KillRewards.forShot(shot, false, KillRewards.newRecord(), 0)
		expect(names(lines)).toBe("KILL, HEADSHOT, ONE SHOT ONE KILL, LONG SHOT")
		expect(total).toBe(500 + 100 + 100 + 150)
	end)

	it("only counts one bullet from full health as a one shot kill", function()
		local hurt = KillRewards.forShot({ kill({ bullets = 1 }) }, false, KillRewards.newRecord(), 0)
		expect(names(hurt)).toBe("KILL")
		local pellets = KillRewards.forShot({ kill({ fullHealth = true, bullets = 4 }) }, false, KillRewards.newRecord(), 0)
		expect(names(pellets)).toBe("KILL")
		local near = KillRewards.forShot({ kill({ distance = 149 }) }, false, KillRewards.newRecord(), 0)
		expect(names(near)).toBe("KILL")
	end)

	it("pays a collateral once for the shot, on top of each kill", function()
		local shot = {
			kill({ victim = "a", fullHealth = true, bullets = 1, distance = 160 }),
			kill({ victim = "b", fullHealth = true, bullets = 1, distance = 160 }),
		}
		local lines, total = KillRewards.forShot(shot, true, KillRewards.newRecord(), 0)
		expect(names(lines)).toBe("KILL, ONE SHOT ONE KILL, LONG SHOT, KILL, ONE SHOT ONE KILL, LONG SHOT, COLLATERAL")
		expect(total).toBe(1750)
		local one = KillRewards.forShot({ kill() }, true, KillRewards.newRecord(), 0)
		expect(names(one)).toBe("KILL") -- it takes two
	end)

	it("pays streaks at 3, 5 and 10 kills without dying, once each", function()
		local record = KillRewards.newRecord()
		local seen = {}
		for count = 1, 11 do
			local lines = KillRewards.forShot({ kill({ victim = count }) }, false, record, count)
			seen[count] = names(lines)
		end
		expect(seen[2]).toBe("KILL")
		expect(seen[3]).toBe("KILL, KILLING SPREE")
		expect(seen[4]).toBe("KILL")
		expect(seen[5]).toBe("KILL, RAMPAGE")
		expect(seen[10]).toBe("KILL, UNSTOPPABLE")
		expect(seen[11]).toBe("KILL")
		KillRewards.died(record)
		for count = 12, 13 do
			KillRewards.forShot({ kill({ victim = count }) }, false, record, count)
		end
		local again = KillRewards.forShot({ kill({ victim = 14 }) }, false, record, 14)
		expect(names(again)).toBe("KILL, KILLING SPREE")
	end)

	it("shows the lines for a target that doesn't pay, with no amounts, and doesn't count it", function()
		local record = KillRewards.newRecord()
		local lines, total = KillRewards.forShot({ kill({ pays = false, head = true }) }, false, record, 0)
		expect(names(lines)).toBe("KILL, HEADSHOT")
		expect(total).toBe(0)
		expect(lines[1].amount).toBe(nil)
		expect(record.streak).toBe(0)
	end)

	it("pays the same victim to the same killer only once every 20 seconds", function()
		local record = KillRewards.newRecord()
		local _, first = KillRewards.forShot({ kill() }, false, record, 100)
		local lines, second = KillRewards.forShot({ kill() }, false, record, 119)
		local _, third = KillRewards.forShot({ kill() }, false, record, 120)
		local _, other = KillRewards.forShot({ kill({ victim = "b" }) }, false, record, 121)
		expect(first).toBe(500)
		expect(second).toBe(0)
		expect(lines[1].amount).toBe(nil)
		expect(third).toBe(500)
		expect(other).toBe(700) -- the third kill that paid, so it's a spree too
		expect(record.streak).toBe(3) -- the one that didn't pay didn't count
	end)
end)

describe("KillPopupTiming", function()
	it("punches a line in big and settles it", function()
		local scale, fade, alive = Timing.line(0)
		expect(scale).toBe(Timing.PUNCH)
		expect(fade).toBe(1)
		expect(alive).toBe(true)
		local settled, solid = Timing.line(0.12)
		expect(math.abs(settled - 1) < 1e-6).toBe(true)
		expect(solid).toBe(0)
	end)

	it("holds a line for 2 seconds and fades it over 0.3", function()
		local _, held = Timing.line(2.1)
		expect(held).toBe(0)
		local _, fading, alive = Timing.line(2.27)
		expect(fading > 0.4 and fading < 0.6).toBe(true)
		expect(alive).toBe(true)
		local _, gone, there = Timing.line(Timing.LIFE)
		expect(gone).toBe(1)
		expect(there).toBe(false)
	end)

	it("waits for a staggered line without dropping it", function()
		local _, fade, alive = Timing.line(-0.05)
		expect(fade).toBe(1)
		expect(alive).toBe(true)
	end)

	it("counts the total up and clears it when things go quiet", function()
		expect(Timing.total(500, 1350, 0)).toBe(500)
		expect(Timing.total(500, 1350, 0.35)).toBe(1350)
		local part = Timing.total(500, 1350, 0.15)
		expect(part > 500 and part < 1350).toBe(true)
		expect(Timing.total(0, 500, 5)).toBe(500)
		expect(Timing.cleared(2.4)).toBe(false)
		expect(Timing.cleared(2.5)).toBe(true)
	end)
end)
