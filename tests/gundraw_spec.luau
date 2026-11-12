local harness = require("./harness")
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")
local GunDraw = require("../src/shared/Guns/GunDraw")
local AkReload = luau.load(fs.readFile("src/shared/Guns/AkReload.luau"), {
	environment = { CFrame = roblox.CFrame, Vector3 = roblox.Vector3 },
})()

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

	it("holds the pistol up, muzzle high, while it is racked, and turns it at the wrist", function()
		expect(GunDraw.at("pistol", 0.4).pitch > 35).toBe(true)
		expect(GunDraw.wrist("pistol")).toBe(true)
		expect(GunDraw.wrist("rifle")).toBe(false)
	end)

	it("tugs the rifle back and lets it snap forward, as the bolt is racked", function()
		expect(GunDraw.at("rifle", 0.5).z > GunDraw.at("rifle", 0.3).z + 0.1).toBe(true)
		expect(GunDraw.at("rifle", 0.56).z < GunDraw.at("rifle", 0.5).z - 0.1).toBe(true)
	end)

	it("racks the rifle's bolt just as the gun is tugged back", function()
		expect(GunDraw.rack("rifle", 0.1)).toBeNil()
		expect(GunDraw.rack("pistol", 0.4)).toBeNil()
		-- The handle starts back before the tug's peak and the bolt is home soon after it.
		local pull = GunDraw.rack("rifle", 0.42) :: number
		local home = GunDraw.rack("rifle", 0.58) :: number
		expect(pull >= AkReload.RACK_PULL and pull < AkReload.RACK_HOME).toBe(true)
		expect(home >= AkReload.RACK_HOME).toBe(true)
		-- And the hand is back on the grip before the draw is over.
		expect((GunDraw.rack("rifle", GunDraw.length("rifle")) :: number) >= AkReload.RACK).toBe(true)
	end)

	it("pulls the bolt back and takes the right hand off the grip to do it", function()
		local pulled = AkReload.rack((AkReload.RACK_PULL + AkReload.RACK_HOME) / 2)
		expect(pulled.bolt > 0).toBe(true)
		expect(pulled.rightWeight > 0.9).toBe(true)
		expect(pulled.weight).toBe(0)
		expect(AkReload.rack(0).rightWeight).toBe(0)
		expect(AkReload.rack(AkReload.RACK).rightWeight).toBe(0)
		expect(AkReload.rack(AkReload.RACK).bolt).toBe(0)
	end)

	it("brings the left hand right onto the pistol's slide and drags it back", function()
		expect(GunDraw.hand("pistol", 0.1)).toBeNil()
		expect(GunDraw.hand("pistol", 0.8)).toBeNil()
		expect(GunDraw.hand("rifle", 0.4)).toBeNil()
		local on = GunDraw.hand("pistol", 0.36) :: any
		local back = GunDraw.hand("pistol", 0.44) :: any
		expect(on.on).toBe(1) -- all the way on the gun, not a nudge from where it rests
		expect(on.back).toBe(0)
		expect(back.on).toBe(1)
		expect(back.back > 0.5).toBe(true)
		-- The slide goes back with the hand, all the way, and is home again as soon as it is let go.
		expect(on.slide).toBe(0)
		expect(back.slide > 0.5).toBe(true)
		expect((GunDraw.hand("pistol", 0.46) :: any).slide).toBe(1)
		expect((GunDraw.hand("pistol", 0.52) :: any).slide).toBe(0)
		-- And it is away again before the draw is over.
		expect((GunDraw.hand("pistol", 0.7) :: any).on < 0.2).toBe(true)
		-- The gun is tugged back with it.
		expect(GunDraw.at("pistol", 0.46).z > GunDraw.at("pistol", 0.36).z + 0.05).toBe(true)
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
