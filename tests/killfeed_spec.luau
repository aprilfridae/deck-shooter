local harness = require("./harness")
local KillFeed = require("../src/shared/Guns/Hud/KillFeed")

local describe, it, expect = harness.describe, harness.it, harness.expect

local function entry(killer: string): any
	return { killer = killer, victim = "DUMMY", mine = false }
end

describe("KillFeed", function()
	it("adds a kill with the names it was given", function()
		local list = {}
		KillFeed.push(list, { killer = "MARROW", victim = "KESTREL", mine = true }, 10)
		expect(#list).toBe(1)
		expect(list[1].killer).toBe("MARROW")
		expect(list[1].victim).toBe("KESTREL")
		expect(list[1].mine).toBe(true)
		expect(list[1].at).toBe(10)
	end)

	it("keeps only the newest five", function()
		local list = {}
		for index = 1, 6 do
			KillFeed.push(list, entry(`P{index}`), index)
		end
		expect(#list).toBe(KillFeed.MAX)
		expect(list[1].killer).toBe("P2")
		expect(list[5].killer).toBe("P6")
	end)

	it("drops a line once it has faded", function()
		local list = {}
		KillFeed.push(list, entry("A"), 0)
		expect(KillFeed.prune(list, KillFeed.SECONDS - 1)).toBe(false)
		expect(#list).toBe(1)
		expect(KillFeed.prune(list, KillFeed.SECONDS + KillFeed.FADE + 0.1)).toBe(true)
		expect(#list).toBe(0)
	end)

	it("drops only the old lines", function()
		local list = {}
		KillFeed.push(list, entry("OLD"), 0)
		KillFeed.push(list, entry("NEW"), 5)
		expect(KillFeed.prune(list, KillFeed.SECONDS + KillFeed.FADE + 0.1)).toBe(true)
		expect(#list).toBe(1)
		expect(list[1].killer).toBe("NEW")
	end)

	it("fades at the end of a line's time", function()
		local shown = { killer = "A", victim = "B", mine = false, at = 0 }
		expect(KillFeed.fade(shown, KillFeed.SECONDS - 1)).toBe(0)
		expect(math.round(KillFeed.fade(shown, KillFeed.SECONDS + KillFeed.FADE / 2) * 100)).toBe(50)
		expect(KillFeed.fade(shown, KillFeed.SECONDS + KillFeed.FADE)).toBe(1)
		expect(KillFeed.fade(shown, KillFeed.SECONDS + 10)).toBe(1)
	end)

	it("cleans a name for the feed", function()
		expect(KillFeed.clean("marrow")).toBe("MARROW")
		expect(#(KillFeed.clean(string.rep("a", 30)) :: string)).toBe(KillFeed.NAME_LENGTH)
		expect(KillFeed.clean("")).toBe(nil)
		expect(KillFeed.clean(5)).toBe(nil)
		expect(KillFeed.clean(nil)).toBe(nil)
	end)

	it("swaps letters the font can't draw", function()
		expect(KillFeed.clean("Ré_x 9")).toBe("R?_X 9")
	end)
end)
