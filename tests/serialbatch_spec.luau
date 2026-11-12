local harness = require("./harness")
local Inventory = require("../src/shared/CardCore/Inventory")
local SerialBatch = require("../src/shared/CardCore/SerialBatch")

local describe, it, expect = harness.describe, harness.it, harness.expect

local KEY = Inventory.key("aegis_shell", "Prototype", "Base")

local function save(count: number): any
	local data = { stacks = {}, serials = {} }
	Inventory.add(data, "aegis_shell", "Prototype", "Base", count)
	return data
end

describe("SerialBatch", function()
	it("lists the stacks with copies waiting for a number", function()
		local data = save(5)
		Inventory.number(data, KEY, 1, 2)
		data.serials[KEY].plain = 1
		Inventory.add(data, "overclock", "Field", "Base", 2)
		Inventory.number(data, Inventory.key("overclock", "Field", "Base"), 8, 9)
		Inventory.addPlain(data, "phase_dash", "Field", "Base", 1)
		expect(SerialBatch.wanted(data)).toEqual({ [KEY] = 2 })
	end)

	it("adds up what several players want", function()
		expect(SerialBatch.total({ { a = 2 }, { a = 3, b = 1 } })).toEqual({ a = 5, b = 1 })
	end)

	it("moves the counters on and says where each kind starts", function()
		local stored = { a = 10 }
		local counters, firsts = SerialBatch.reserve(stored, { a = 5, b = 1 })
		expect(counters).toEqual({ a = 15, b = 1 })
		expect(firsts).toEqual({ a = 11, b = 1 })
		expect(stored).toEqual({ a = 10 })
	end)

	it("starts from nothing when the store is empty or damaged", function()
		local counters, firsts = SerialBatch.reserve(nil, { a = 2 })
		expect(counters).toEqual({ a = 2 })
		expect(firsts).toEqual({ a = 1 })
		counters, firsts = SerialBatch.reserve({ a = "junk", b = 4 } :: any, { a = 1 })
		expect(counters.b).toBe(4)
		expect(firsts.a).toBe(1)
	end)

	it("gives each player their own run", function()
		local one, two = save(2), save(3)
		local used, from, to = SerialBatch.apply(one, KEY, 11, 2)
		expect({ used, from, to }).toEqual({ 2, 11, 12 })
		used, from, to = SerialBatch.apply(two, KEY, 13, 3)
		expect({ used, from, to }).toEqual({ 3, 13, 15 })
		expect(one.serials[KEY].runs).toEqual({ 11, 12 })
		expect(two.serials[KEY].runs).toEqual({ 13, 15 })
	end)

	it("skips numbers a player no longer has copies for", function()
		local data = save(1)
		local used, from, to = SerialBatch.apply(data, KEY, 20, 4)
		expect({ used, from, to }).toEqual({ 1, 20, 20 })
		used, from, to = SerialBatch.apply(data, KEY, 30, 4)
		expect(used).toBe(0)
		expect(from).toBe(nil)
		expect(to).toBe(nil)
	end)

	it("hands serials to pulls in the order they were made", function()
		local queue = SerialBatch.queue()
		queue:push(KEY, 1, 1)
		queue:push(KEY, 1, 3)
		queue:push(KEY, 2, 2)
		expect(queue:assign(KEY, 50, 51)).toEqual({
			{ openId = 1, slot = 1, serial = 50 },
			{ openId = 1, slot = 3, serial = 51 },
		})
		expect(queue:assign(KEY, 60, 60)).toEqual({ { openId = 2, slot = 2, serial = 60 } })
		expect(queue:assign(KEY, 70, 70)).toEqual({})
		expect(queue:assign("never:pushed:Base", 1, 5)).toEqual({})
	end)
end)
