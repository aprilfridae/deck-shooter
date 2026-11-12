-- The rules for handing out serials in batches (docs/specs/serials.md). A server asks the shared counter once
-- for everything its players are waiting on, then shares the numbers out. Pure: the server module does the asking.
local Inventory = require("./Inventory")

local SerialBatch = {}

-- The copies in this save that are waiting for a serial, by stack. Stacks with none are left out.
function SerialBatch.wanted(data: any): { [string]: number }
	local wants = {}
	for key in data.stacks do
		local waiting = Inventory.waiting(data, key)
		if waiting > 0 then
			wants[key] = waiting
		end
	end
	return wants
end

function SerialBatch.total(wants: { { [string]: number } }): { [string]: number }
	local total = {}
	for _, want in wants do
		for key, count in want do
			total[key] = (total[key] or 0) + count
		end
	end
	return total
end

-- Takes `total` numbers of each kind from the stored counters. Returns the counters to store and the first
-- serial of each kind. The stored table is left alone, because UpdateAsync may call this more than once.
function SerialBatch.reserve(stored: { [string]: number }?, total: { [string]: number }): ({ [string]: number }, { [string]: number })
	local counters = {}
	if type(stored) == "table" then
		for key, last in stored do
			if type(key) == "string" and type(last) == "number" then
				counters[key] = last
			end
		end
	end
	local firsts = {}
	for key, count in total do
		local last = counters[key] or 0
		firsts[key] = last + 1
		counters[key] = last + count
	end
	return counters, firsts
end

-- Numbers up to `share` of this save's waiting copies from `first`. Returns how many it used and the first and
-- last serial it gave. A player who fused or sold in the meantime has fewer waiting; the rest are skipped.
function SerialBatch.apply(data: any, key: string, first: number, share: number): (number, number?, number?)
	local used = Inventory.number(data, key, first, first + share - 1)
	if used == 0 then
		return 0, nil, nil
	end
	return used, first, first + used - 1
end

-- One player's pulls that are waiting to be told their serials, oldest first, so the pull reveal can show each
-- card's own number.
function SerialBatch.queue(): any
	local waiting: { [string]: { { openId: number, slot: number } } } = {}
	local queue = {}

	function queue:push(key: string, openId: number, slot: number)
		waiting[key] = waiting[key] or {}
		table.insert(waiting[key], { openId = openId, slot = slot })
	end

	function queue:assign(key: string, from: number, to: number): { { openId: number, slot: number, serial: number } }
		local given = {}
		local pulls = waiting[key]
		if not pulls then
			return given
		end
		local serial = from
		while serial <= to and #pulls > 0 do
			local pull = table.remove(pulls, 1) :: any
			table.insert(given, { openId = pull.openId, slot = pull.slot, serial = serial })
			serial += 1
		end
		if #pulls == 0 then
			waiting[key] = nil
		end
		return given
	end

	return queue
end

return SerialBatch
