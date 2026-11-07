local harness = require("./harness")
local PullParticles = require("../src/shared/CardCore/PullParticles")

local describe, it, expect = harness.describe, harness.it, harness.expect

local function lowest(low: number, _high: number): number
	return low
end

describe("PullParticles", function()
	it("gives every rarity its own style", function()
		local seen = {}
		for _, card in {
			{ tier = "Field", variant = "Base" },
			{ tier = "BlackSite", variant = "Base" },
			{ tier = "Prototype", variant = "Base" },
			{ tier = "Field", variant = "Chromatic" },
			{ tier = "Field", variant = "Redacted" },
			{ tier = "Field", variant = "ZeroDay" },
		} do
			local style = PullParticles.style(card)
			expect(seen[style]).toBe(nil)
			seen[style] = true
		end
	end)

	it("picks the variant's style over the tier's", function()
		local plain = PullParticles.style({ tier = "Prototype", variant = "Base" })
		expect(PullParticles.style({ tier = "Prototype", variant = "Chromatic" }) == plain).toBe(false)
	end)

	it("shows the same style for a Zero-Day at any tier", function()
		local field = PullParticles.style({ tier = "Field", variant = "ZeroDay" })
		expect(PullParticles.style({ tier = "Prototype", variant = "ZeroDay" })).toBe(field)
	end)

	it("makes as many particles as the share asks for", function()
		local style = PullParticles.style({ tier = "BlackSite", variant = "Base" })
		expect(#PullParticles.spawn(style, 1, lowest)).toBe(style.count)
		expect(#PullParticles.spawn(style, 0.5, lowest)).toBe(math.round(style.count / 2))
	end)

	it("always makes at least one", function()
		local style = PullParticles.style({ tier = "Field", variant = "Base" })
		expect(#PullParticles.spawn(style, 0, lowest)).toBe(1)
	end)

	it("pulls particles down over time when the style has gravity", function()
		local style = { gravity = 2 }
		local particle = { x = 0, y = 0, vx = 1, vy = 0 }
		local x, y = PullParticles.position(style, particle, 1)
		expect(x).toBe(1)
		expect(y).toBe(1)
	end)

	it("moves a stepped style in jumps", function()
		local style = { gravity = 0, stepped = true }
		local particle = { x = 0, y = 0, vx = 1, vy = 0 }
		local first = PullParticles.position(style, particle, 0.01)
		local second = PullParticles.position(style, particle, 0.02)
		expect(first).toBe(second)
	end)

	it("fades out by the end of a particle's life", function()
		local particle = { life = 2 }
		expect(PullParticles.fade(particle, 0)).toBe(0)
		expect(PullParticles.fade(particle, 2)).toBe(1)
		expect(PullParticles.fade(particle, 3)).toBe(1)
	end)
end)
