local harness = require("./harness")
local GunDraw = require("../src/shared/Guns/GunDraw")

local describe, it, expect = harness.describe, harness.it, harness.expect

local KINDS = { "pistol", "rifle", "sniper" }
local FIELDS = { "x", "y", "z", "pitch", "yaw", "roll" }

local function size(pose: any): number
	local total = 0
	for _, field in FIELDS do
		total += math.abs(pose[field])
	end
	return total
end

describe("GunDraw", function()
	it("picks a draw by the kind of gun", function()
		expect(GunDraw.kind(true, false)).toBe("pistol")
		expect(GunDraw.kind(true, true)).toBe("pistol")
		expect(GunDraw.kind(false, true)).toBe("sniper")
		expect(GunDraw.kind(false, false)).toBe("rifle")
	end)

	it("draws a pistol fastest and a sniper slowest", function()
		expect(GunDraw.length("pistol") < GunDraw.length("rifle")).toBe(true)
		expect(GunDraw.length("rifle") < GunDraw.length("sniper")).toBe(true)
	end)

	it("starts every gun well away from its place", function()
		for _, kind in KINDS do
			local start = GunDraw.at(kind, 0)
			-- Slid a long way, or swung a long way round.
			local slid = math.abs(start.x) + math.abs(start.y) + math.abs(start.z)
			expect(slid > 1 or math.abs(start.pitch) > 45).toBe(true)
		end
	end)

	it("brings the pistol and the rifle up from under the screen, muzzle high", function()
		for _, kind in { "pistol", "rifle" } do
			local start = GunDraw.at(kind, 0)
			expect(start.y < -1).toBe(true)
			expect(GunDraw.at(kind, 0.3).pitch > 30).toBe(true)
		end
	end)

	it("holds the pistol's muzzle to the sky before it drops level", function()
		expect(GunDraw.at("pistol", 0.4).pitch > 70).toBe(true)
	end)

	it("tugs the rifle back and lets it snap forward, as the bolt is racked", function()
		expect(GunDraw.at("rifle", 0.44).z > GunDraw.at("rifle", 0.3).z + 0.1).toBe(true)
		expect(GunDraw.at("rifle", 0.52).z < GunDraw.at("rifle", 0.44).z - 0.1).toBe(true)
	end)

	it("ends every gun exactly at rest, and keeps it there", function()
		for _, kind in KINDS do
			expect(size(GunDraw.at(kind, GunDraw.length(kind)))).toBe(0)
			expect(size(GunDraw.at(kind, GunDraw.length(kind) + 5))).toBe(0)
		end
	end)

	it("arrives at rest without a jump", function()
		for _, kind in KINDS do
			local nearly = GunDraw.at(kind, GunDraw.length(kind) - 0.005)
			expect(math.abs(nearly.x) + math.abs(nearly.y) + math.abs(nearly.z) < 0.01).toBe(true)
			expect(math.abs(nearly.pitch) + math.abs(nearly.yaw) + math.abs(nearly.roll) < 1).toBe(true)
		end
	end)

	it("never jumps between one frame and the next", function()
		for _, kind in KINDS do
			local last = GunDraw.at(kind, 0)
			for step = 1, math.ceil(GunDraw.length(kind) * 120) do
				local now = GunDraw.at(kind, step / 120)
				expect(math.abs(now.y - last.y) < 0.2).toBe(true)
				expect(math.abs(now.pitch - last.pitch) < 12).toBe(true)
				last = now
			end
		end
	end)

	it("leaves a gun it doesn't know at rest", function()
		expect(size(GunDraw.at("banana", 0))).toBe(0)
		expect(GunDraw.length("banana")).toBe(0)
	end)
end)
