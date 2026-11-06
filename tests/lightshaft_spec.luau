local harness = require("./harness")
local LightShaft = require("../src/server/Outpost/LightShaft")

local describe, it, expect = harness.describe, harness.it, harness.expect

describe("LightShaft.columns", function()
	it("fills the circle from a centre column outward", function()
		local columns = LightShaft.columns(6)
		expect(#columns).toBe(17)
		expect(columns[1].x).toBe(0)
		expect(columns[1].z).toBe(0)
	end)

	it("keeps every column inside the circle", function()
		for _, column in LightShaft.columns(6) do
			local edge = math.sqrt(column.x ^ 2 + column.z ^ 2) + column.width / 2
			expect(edge <= 6.001).toBe(true)
		end
	end)

	it("fades toward the rim", function()
		local columns = LightShaft.columns(6)
		expect(columns[#columns].transparency > columns[1].transparency).toBe(true)
	end)
end)
