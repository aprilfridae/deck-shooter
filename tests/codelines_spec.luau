local harness = require("./harness")
local CodeLines = require("../src/shared/Guns/CodeLines")

local describe, it, expect = harness.describe, harness.it, harness.expect

describe("CodeLines", function()
	it("gives the same lines for the same seed", function()
		local a, b = CodeLines.new(42), CodeLines.new(42)
		for _ = 1, 50 do
			expect(CodeLines.next(a)).toBe(CodeLines.next(b))
		end
	end)

	it("gives different lines for different seeds", function()
		local a, b = CodeLines.new(1), CodeLines.new(2)
		local same = 0
		for _ = 1, 20 do
			if CodeLines.next(a) == CodeLines.next(b) then
				same += 1
			end
		end
		expect(same < 5).toBe(true)
	end)

	it("keeps lines short enough for a small screen", function()
		local s = CodeLines.new(7)
		for _ = 1, 500 do
			local line = CodeLines.next(s)
			expect(#line > 0 and #line <= 60).toBe(true)
		end
	end)
end)
