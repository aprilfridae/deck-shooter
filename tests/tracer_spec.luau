local harness = require("./harness")
local Tracer = require("../src/shared/Guns/Tracer")

local describe, it, expect = harness.describe, harness.it, harness.expect

describe("Tracer.span", function()
	it("starts as a dot at the muzzle", function()
		local tail, head = Tracer.span(100, 0, 500, 8)
		expect(tail).toBeCloseTo(0)
		expect(head).toBeCloseTo(0)
	end)

	it("grows to its full length as it leaves the muzzle", function()
		local tail, head = Tracer.span(100, 0.1, 500, 8)
		expect(head).toBeCloseTo(50)
		expect(tail).toBeCloseTo(42)
	end)

	it("never passes the point it hits", function()
		local tail, head = Tracer.span(20, 0.041, 500, 8)
		expect(head).toBeCloseTo(20)
		expect(tail).toBeCloseTo(12.5)
	end)

	it("is gone once its tail reaches the hit", function()
		local tail = Tracer.span(20, 0.1, 500, 8)
		expect(tail).toBe(nil)
	end)
end)
