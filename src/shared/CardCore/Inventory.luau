-- Card stacks in save data, keyed "cardId:tier:variant", and the serials of the copies in them.
local Config = require("./Config")

local Inventory = {}

function Inventory.key(cardId: string, tier: string, variant: string): string
	return `{cardId}:{tier}:{variant}`
end

function Inventory.parse(key: string): (string?, string?, string?)
	local cardId, tier, variant = string.match(key, "^([^:]+):([^:]+):([^:]+)$")
	return cardId, tier, variant
end

function Inventory.count(data: any, cardId: string, tier: string, variant: string?): number
	if variant then
		return data.stacks[Inventory.key(cardId, tier, variant)] or 0
	end
	local total = 0
	for key, n in data.stacks do
		local stackCard, stackTier = Inventory.parse(key)
		if stackCard == cardId and stackTier == tier then
			total += n
		end
	end
	return total
end

-- Serials (docs/specs/serials.md). `data.stacks` says how many copies a stack holds. Beside it,
-- `data.serials[key]` says which of them are numbered, as runs of serials in a flat list of pairs
-- ({ from, to, from, to }, sorted, never touching), and how many are starter copies, which never get a number.
-- The rest are waiting for one. A stack can hold a million copies, so nothing here visits copies one by one.
local function record(data: any, key: string, create: boolean): any
	if not data.serials then
		if not create then
			return nil
		end
		data.serials = {}
	end
	local found = data.serials[key]
	if not found and create then
		found = { runs = {}, plain = 0 }
		data.serials[key] = found
	end
	return found
end

local function numbered(runs: { number }): number
	local total = 0
	for index = 1, #runs, 2 do
		total += runs[index + 1] - runs[index] + 1
	end
	return total
end

-- Drops a stack's record once it says nothing.
local function tidy(data: any, key: string)
	local found = record(data, key, false)
	if found and (data.stacks[key] == nil or (#found.runs == 0 and found.plain == 0)) then
		data.serials[key] = nil
	end
end

-- Adds copies that are waiting for a serial.
function Inventory.add(data: any, cardId: string, tier: string, variant: string, n: number)
	local key = Inventory.key(cardId, tier, variant)
	-- A save with a stack past the limit counts as corrupt, so a stack stops there.
	data.stacks[key] = math.min((data.stacks[key] or 0) + n, Config.MaxStackCount)
end

-- Adds starter copies: the free cards every new player gets. They never get a serial, or the first ten people
-- to join would hold 01 to 10 of each for doing nothing.
function Inventory.addPlain(data: any, cardId: string, tier: string, variant: string, n: number)
	local key = Inventory.key(cardId, tier, variant)
	local have = data.stacks[key] or 0
	local now = math.min(have + n, Config.MaxStackCount)
	if now > have then
		data.stacks[key] = now
		record(data, key, true).plain += now - have
	end
end

-- How many of a stack's copies are waiting for a serial.
function Inventory.waiting(data: any, key: string): number
	local have = data.stacks[key] or 0
	local found = record(data, key, false)
	if not found then
		return have
	end
	return math.max(0, have - numbered(found.runs) - found.plain)
end

-- Gives waiting copies the serials from `from` upward, and returns how many it used: never more than are
-- waiting. Numbers the stack already holds are refused whole, because a serial is never held twice.
function Inventory.number(data: any, key: string, from: number, to: number): number
	local used = math.min(to - from + 1, Inventory.waiting(data, key))
	if used <= 0 then
		return 0
	end
	local last = from + used - 1
	local runs = record(data, key, true).runs
	local at = #runs + 1
	for index = 1, #runs, 2 do
		if runs[index] <= last and runs[index + 1] >= from then
			tidy(data, key)
			return 0
		elseif runs[index] > last then
			at = index
			break
		end
	end
	table.insert(runs, at, last)
	table.insert(runs, at, from)
	-- Join it to a neighbour it touches.
	if at + 2 <= #runs and runs[at + 2] == last + 1 then
		runs[at + 1] = runs[at + 3]
		table.remove(runs, at + 2)
		table.remove(runs, at + 2)
	end
	if at > 1 and runs[at - 1] == from - 1 then
		runs[at - 1] = runs[at + 1]
		table.remove(runs, at)
		table.remove(runs, at)
	end
	return used
end

-- The lowest serial in a stack, which is the one a card shows.
function Inventory.lowest(data: any, key: string): number?
	local found = record(data, key, false)
	return found and found.runs[1]
end

-- Spends starter copies first, then copies waiting for a serial, then the highest serials, so a player's lowest
-- numbers are the last to go.
function Inventory.remove(data: any, cardId: string, tier: string, variant: string, n: number): boolean
	local key = Inventory.key(cardId, tier, variant)
	local have = data.stacks[key] or 0
	if have < n then
		return false
	end
	local found = record(data, key, false)
	if found then
		local left = n
		local waiting = Inventory.waiting(data, key)
		local plain = math.min(left, found.plain)
		found.plain -= plain
		left -= plain + math.min(left - plain, waiting)
		local runs = found.runs
		while left > 0 and #runs > 0 do
			local size = runs[#runs] - runs[#runs - 1] + 1
			if size <= left then
				left -= size
				table.remove(runs)
				table.remove(runs)
			else
				runs[#runs] -= left
				left = 0
			end
		end
	end
	data.stacks[key] = if have == n then nil else have - n
	tidy(data, key)
	return true
end

-- Removes exactly this numbered copy, for selling one card. False if the stack doesn't hold it.
function Inventory.take(data: any, key: string, serial: number): boolean
	local found = record(data, key, false)
	if not found then
		return false
	end
	local runs = found.runs
	for index = 1, #runs, 2 do
		local from, to = runs[index], runs[index + 1]
		if serial >= from and serial <= to then
			if from == to then
				table.remove(runs, index)
				table.remove(runs, index)
			elseif serial == from then
				runs[index] = from + 1
			elseif serial == to then
				runs[index + 1] = to - 1
			else
				runs[index + 1] = serial - 1
				table.insert(runs, index + 2, to)
				table.insert(runs, index + 2, serial + 1)
			end
			local have = data.stacks[key]
			data.stacks[key] = if have == 1 then nil else have - 1
			tidy(data, key)
			return true
		end
	end
	return false
end

-- Puts one numbered copy into a stack: a card won at auction, or one coming back unsold. False, changing nothing,
-- if the stack already holds that serial or is full.
function Inventory.give(data: any, key: string, serial: number): boolean
	local have = data.stacks[key] or 0
	if have >= Config.MaxStackCount then
		return false
	end
	-- Number the new copy directly: an older copy waiting for a serial must not be handed this one.
	local waiting = Inventory.waiting(data, key)
	data.stacks[key] = have + 1
	local found = record(data, key, true)
	found.plain += waiting -- hide the waiting copies from number() for a moment
	local used = Inventory.number(data, key, serial, serial)
	found = record(data, key, true)
	found.plain -= waiting
	if used == 0 then
		data.stacks[key] = if have == 0 then nil else have
	end
	tidy(data, key)
	return used == 1
end

function Inventory.ownsCard(data: any, cardId: string): boolean
	for key in data.stacks do
		if Inventory.parse(key) == cardId then
			return true
		end
	end
	return false
end

return Inventory
