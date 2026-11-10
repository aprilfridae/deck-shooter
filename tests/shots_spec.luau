local harness = require("./harness")
local History = require("../src/shared/Guns/History")
local Hitbox = require("../src/shared/Guns/Hitbox")
local ShotRequest = require("../src/shared/Guns/ShotRequest")

local describe, it, expect = harness.describe, harness.it, harness.expect

local function target(pose: string?)
	return { x = 0, y = 3, z = 0, pose = pose or "Normal" }
end

local east = { x = 1, y = 0, z = 0 }

local function shot(fields: { [string]: any }?)
	local raw: { [string]: any } = {
		origin = { x = 1, y = 2, z = 3 },
		direction = { x = 0, y = 0, z = -2 },
		firedAt = 9.9,
	}
	for key, value in fields or {} do
		raw[key] = value
	end
	return raw
end

describe("History", function()
	it("blends a position between two samples", function()
		local h = History.new()
		History.record(h, 0, 0, 0, "Normal", 1)
		History.record(h, 10, 0, 0, "Slide", 2)
		local at = History.at(h, 1.5)
		expect(at.x).toBeCloseTo(5)
		expect(at.pose).toBe("Normal")
	end)

	it("returns nil with no history", function()
		expect(History.at(History.new(), 1)).toBeNil()
	end)

	it("uses the newest sample for a time after it", function()
		local h = History.new()
		History.record(h, 4, 0, 0, "Normal", 1)
		expect(History.at(h, 5).x).toBe(4)
	end)

	it("forgets anything over 1 second old", function()
		local h = History.new()
		History.record(h, 1, 0, 0, "Normal", 0)
		History.record(h, 2, 0, 0, "Normal", 0.5)
		History.record(h, 3, 0, 0, "Normal", 1.6)
		expect(History.at(h, 0).x).toBe(3)
	end)
end)

describe("Hitbox", function()
	it("hits the head sphere and reports it", function()
		local zone, distance = Hitbox.test({ x = -20, y = 5.9, z = 0 }, east, target())
		expect(zone).toBe("Head")
		expect(distance).toBeCloseTo(19.2, 1e-3)
	end)

	it("hits the body cylinder from the side", function()
		local zone, distance = Hitbox.test({ x = -20, y = 3, z = 0 }, east, target())
		expect(zone).toBe("Body")
		expect(distance).toBeCloseTo(18.9, 1e-3)
	end)

	it("misses past the shoulder", function()
		expect((Hitbox.test({ x = -20, y = 3, z = 1.5 }, east, target()))).toBeNil()
	end)

	it("hits the head first from straight above", function()
		local zone = Hitbox.test({ x = 0, y = 30, z = 0 }, { x = 0, y = -1, z = 0 }, target())
		expect(zone).toBe("Head")
	end)

	it("lowers the hitbox for a crouching target", function()
		expect((Hitbox.test({ x = -20, y = 6, z = 0 }, east, target("Crouch")))).toBeNil()
		expect((Hitbox.test({ x = -20, y = 4.4, z = 0 }, east, target("Crouch")))).toBe("Head")
	end)

	it("lowers the hitbox for a sliding target", function()
		expect((Hitbox.test({ x = -20, y = 6, z = 0 }, east, target("Slide")))).toBeNil()
		expect((Hitbox.test({ x = -20, y = 3.4, z = 0 }, east, target("Slide")))).toBe("Head")
	end)

	it("puts a plain body's head lower than the soldier's", function()
		expect((Hitbox.test({ x = -20, y = 5, z = 0 }, east, target(), Hitbox.shapes.plain))).toBe("Head")
		expect((Hitbox.test({ x = -20, y = 5, z = 0 }, east, target(), Hitbox.shapes.soldier))).toBe("Body")
	end)

	it("ignores a target behind the shooter", function()
		expect((Hitbox.test({ x = 20, y = 3, z = 0 }, east, target()))).toBeNil()
	end)
end)

describe("ShotRequest", function()
	it("parses a good shot and makes the direction a unit length", function()
		local parsed = ShotRequest.parse(shot(), 10)
		expect(parsed.direction).toEqual({ x = 0, y = 0, z = -1 })
		expect(parsed.origin).toEqual({ x = 1, y = 2, z = 3 })
		expect(parsed.firedAt).toBe(9.9)
	end)

	it("reads aiming, and treats anything but true as not aiming", function()
		expect(ShotRequest.parse(shot({ aiming = true }), 10).aiming).toBe(true)
		expect(ShotRequest.parse(shot({ aiming = "yes" }), 10).aiming).toBe(false)
	end)

	it("rejects a zero direction", function()
		expect(ShotRequest.parse(shot({ direction = { x = 0, y = 0, z = 0 } }), 10)).toBeNil()
	end)

	-- Review Focus 1
	it("clamps an old firing time to 200ms ago", function()
		expect(ShotRequest.parse(shot({ firedAt = 1 }), 10).firedAt).toBeCloseTo(9.8)
	end)

	it("clamps a future firing time to now", function()
		expect(ShotRequest.parse(shot({ firedAt = 50 }), 10).firedAt).toBe(10)
	end)

	it("rejects NaN and huge numbers anywhere in a shot", function()
		local nan = 0 / 0
		expect(ShotRequest.parse(shot({ firedAt = nan }), 10)).toBeNil()
		expect(ShotRequest.parse(shot({ firedAt = math.huge }), 10)).toBeNil()
		expect(ShotRequest.parse(shot({ origin = { x = nan, y = 0, z = 0 } }), 10)).toBeNil()
		expect(ShotRequest.parse(shot({ origin = { x = 1e300, y = 0, z = 0 } }), 10)).toBeNil()
		expect(ShotRequest.parse(shot({ direction = { x = 1e300, y = 0, z = 0 } }), 10)).toBeNil()
	end)

	it("rejects a shot that is not a table", function()
		expect(ShotRequest.parse("shot", 10)).toBeNil()
		expect(ShotRequest.parse(shot({ origin = "here" }), 10)).toBeNil()
		expect(ShotRequest.parse(shot({ firedAt = "now" }), 10)).toBeNil()
	end)

	-- Review Focus 5
	it("rejects an origin more than 6 studs from the rewound shooter", function()
		local rewound = { x = 0, y = 0, z = 0 }
		expect(ShotRequest.originAllowed({ x = 0, y = 5.9, z = 0 }, rewound)).toBe(true)
		expect(ShotRequest.originAllowed({ x = 0, y = 6.1, z = 0 }, rewound)).toBe(false)
	end)

	it("lets a fast shooter's shot start further from their recorded body", function()
		local rewound = { x = 0, y = 0, z = 0 }
		expect(ShotRequest.originSlack(0, 0)).toBe(6)
		-- Sprinting at 30 with no ping, the server trails by about a tenth of a second: 3 studs more.
		expect(ShotRequest.originSlack(30, 0)).toBeCloseTo(9)
		expect(ShotRequest.originAllowed({ x = 8, y = 2, z = 0 }, rewound, ShotRequest.originSlack(30, 0))).toBe(true)
		expect(ShotRequest.originAllowed({ x = 8, y = 2, z = 0 }, rewound, ShotRequest.originSlack(0, 0))).toBe(false)
		-- Ping adds to it, up to a limit, and so does speed.
		expect(ShotRequest.originSlack(30, 0.1)).toBeCloseTo(12)
		expect(ShotRequest.originSlack(30, 5)).toBeCloseTo(15)
		expect(ShotRequest.originSlack(9999, 0)).toBeCloseTo(17)
	end)
end)

describe("Lag compensation times", function()
	it("rewinds targets past the firing time by ping and view delay", function()
		expect(ShotRequest.viewTime(100, 0.05, 100.05)).toBeCloseTo(100 - 0.05 - ShotRequest.VIEW_DELAY)
	end)

	it("never rewinds targets further than the limit", function()
		expect(ShotRequest.viewTime(100, 5, 100)).toBeCloseTo(99.8)
	end)

	it("looks for the shooter one ping after firing, up to now", function()
		expect(ShotRequest.shooterTime(100, 0.05, 101)).toBeCloseTo(100.05)
		expect(ShotRequest.shooterTime(100, 5, 100.1)).toBeCloseTo(100.1)
	end)
end)
