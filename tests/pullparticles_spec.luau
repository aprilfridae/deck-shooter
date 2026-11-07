local harness = require("./harness")
local PullParticles = require("../src/shared/CardCore/PullParticles")

local describe, it, expect = harness.describe, harness.it, harness.expect

local function lowest(low: number, _high: number): number
	return low
end

describe("PullParticles", function()
	it("bursts harder for rarer cards", function()
		local field = PullParticles.power({ tier = "Field", variant = "Base" })
		local redline = PullParticles.power({ tier = "BlackSite", variant = "Base" })
		local prototype = PullParticles.power({ tier = "Prototype", variant = "Base" })
		local zero = PullParticles.power({ tier = "Field", variant = "ZeroDay" })
		expect(field < redline).toBe(true)
		expect(redline < prototype).toBe(true)
		expect(prototype < zero).toBe(true)
	end)

	it("adds to the burst for a rare variant", function()
		local plain = PullParticles.power({ tier = "BlackSite", variant = "Base" })
		expect(PullParticles.power({ tier = "BlackSite", variant = "Redacted" }) > plain).toBe(true)
	end)

	it("makes more shards for a stronger burst", function()
		expect(#PullParticles.spawn(1, lowest) > #PullParticles.spawn(0.5, lowest)).toBe(true)
	end)

	it("sends a stronger burst further", function()
		local weak = PullParticles.spawn(0.5, function(_low, high)
			return high
		end)[1]
		local strong = PullParticles.spawn(1, function(_low, high)
			return high
		end)[1]
		local weakX, weakY = PullParticles.position(weak, 5)
		local strongX, strongY = PullParticles.position(strong, 5)
		expect(strongX * strongX + strongY * strongY > weakX * weakX + weakY * weakY).toBe(true)
	end)

	it("slows shards down as they fly", function()
		local particle = { vx = 1, vy = 0 }
		local first = PullParticles.position(particle, 0.2)
		local second = PullParticles.position(particle, 0.4)
		expect(second - first < first).toBe(true)
	end)

	it("reaches further with the rings than a weak burst would", function()
		expect(PullParticles.ringReach(1) > PullParticles.ringReach(0.5)).toBe(true)
	end)

	it("keeps a weak pull's rings big enough to see", function()
		expect(PullParticles.ringReach(0.1) >= 0.5).toBe(true)
	end)

	it("fades out by the end of a shard's life", function()
		local particle = { life = 2 }
		expect(PullParticles.fade(particle, 0)).toBe(0)
		expect(PullParticles.fade(particle, 2)).toBe(1)
		expect(PullParticles.fade(particle, 3)).toBe(1)
	end)
end)
