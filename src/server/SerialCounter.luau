-- The shared counter that hands out serials (docs/specs/serials.md): one record for the whole game holding the
-- last serial given for every kind of card. UpdateAsync can't lose an update when two servers write at once, which
-- is what keeps a serial from being given twice.
-- If this one record ever becomes a bottleneck, split it per card here. Nothing else knows its shape.
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SerialBatch = require(ReplicatedStorage:WaitForChild("CardCore").SerialBatch)
local ProfileStore = require(script.Parent.vendor.ProfileStore)

local STORE = "SerialCounters_v1"
local KEY = "all"

local memory: { [string]: number } = {} -- stands in for the store when saves aren't real either

local SerialCounter = {}

-- Takes `total` serials of each kind. Returns the first of each, or nil if the store couldn't be reached, in
-- which case nothing was taken and the caller tries again later. Yields.
function SerialCounter.reserve(total: { [string]: number }): { [string]: number }?
	-- Without data store access (Studio with API access off) saves live in memory too, so numbers can as well.
	-- With access, saves are real, and so every number must come from the real counter or it could repeat.
	local state = ProfileStore.DataStoreState
	if state == "NoAccess" or state == "NoInternet" then
		local firsts
		memory, firsts = SerialBatch.reserve(memory, total)
		return firsts
	end

	local firsts: { [string]: number }? = nil
	local ok, problem = pcall(function()
		DataStoreService:GetDataStore(STORE):UpdateAsync(KEY, function(stored)
			-- This can run more than once, so it only reads what it is given.
			local counters
			counters, firsts = SerialBatch.reserve(stored, total)
			return counters
		end)
	end)
	if not ok then
		warn(`[CardCore] serial counter unreachable: {problem}`)
		return nil
	end
	return firsts
end

return SerialCounter
