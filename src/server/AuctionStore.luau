-- The parts of the auction house every server shares (docs/specs/auction-house.md):
--   records        one per auction in a data store, changed only through UpdateAsync so two bids can't both win
--   the window     a sorted map per card of short summaries, for browsing. It is not the truth: an auction that
--                  drops out of it still ends and settles correctly
--   announcements  a message to every server when an auction changes, so the players in it are checked at once
-- Every call yields, and answers false or nil on failure after a warning. None of them throws.
local DataStoreService = game:GetService("DataStoreService")
local MemoryStoreService = game:GetService("MemoryStoreService")
local MessagingService = game:GetService("MessagingService")

local ProfileStore = require(script.Parent.vendor.ProfileStore)

local STORE = "Auctions_v1"
local TOPIC = "Auctions"
local WINDOW_PREFIX = "Auctions_"
local WINDOW_LINGER = 300 -- seconds a summary outlives its auction's end
local WINDOW_LEAST = 60 -- the shortest a summary may be kept
local WINDOW_PAGE = 200 -- the most one read returns

local heard = Instance.new("BindableEvent")

local AuctionStore = {
	heard = heard.Event, -- fires with an auction's id on every server, the announcing one included
}

-- Without data store access (Studio with API access off) saves live in memory, so auctions do too. With access,
-- saves are real and so is everything here.
local memoryRecords: { [string]: any } = {}
local memoryWindows: { [string]: { [string]: any } } = {}
local function inMemory(): boolean
	local state = ProfileStore.DataStoreState
	return state == "NoAccess" or state == "NoInternet"
end

local function attempt(what: string, call: () -> ()): boolean
	local ok, problem = pcall(call)
	if not ok then
		warn(`[CardCore] auction {what} failed: {problem}`)
	end
	return ok
end

local function records(): DataStore
	return DataStoreService:GetDataStore(STORE)
end

-- ok, and the record, or nil if there is none.
function AuctionStore.read(id: string): (boolean, any?)
	if inMemory() then
		return true, memoryRecords[id]
	end
	local found
	local ok = attempt("read", function()
		found = records():GetAsync(id)
	end)
	return ok, found
end

-- Changes a record through `transform`, which is given the record as stored (nil if none) and returns the new one,
-- or nil to leave it alone. It may be called more than once, so it must not change what it is given.
-- Answers ok and the record as stored afterwards.
function AuctionStore.change(id: string, transform: (any?) -> any?): (boolean, any?)
	if inMemory() then
		local changed = transform(memoryRecords[id])
		if changed ~= nil then
			memoryRecords[id] = changed
		end
		return true, memoryRecords[id]
	end
	local after
	local ok = attempt("change", function()
		records():UpdateAsync(id, function(stored)
			local changed = transform(stored)
			after = if changed ~= nil then changed else stored
			return changed
		end)
	end)
	return ok, after
end

-- Creates a record only if its id is free. True if the record is there afterwards and is this one, so creating it
-- again after a crash is harmless.
function AuctionStore.create(record: any): boolean
	local ok, after = AuctionStore.change(record.id, function(stored)
		return if stored == nil then record else nil
	end)
	return ok and after ~= nil and after.seller == record.seller and after.serial == record.serial
end

function AuctionStore.remove(id: string): boolean
	if inMemory() then
		memoryRecords[id] = nil
		return true
	end
	return attempt("remove", function()
		records():RemoveAsync(id)
	end)
end

local function summary(record: any): any
	return {
		id = record.id,
		cardId = record.cardId,
		tier = record.tier,
		variant = record.variant,
		serial = record.serial,
		price = record.bid or record.startBid,
		bids = record.bid ~= nil,
		buyNow = record.buyNow,
		endsAt = record.endsAt,
		sellerName = record.sellerName,
	}
end

-- Puts an auction in its card's window, or refreshes it after a bid.
function AuctionStore.show(record: any)
	if inMemory() then
		memoryWindows[record.cardId] = memoryWindows[record.cardId] or {}
		memoryWindows[record.cardId][record.id] = summary(record)
		return
	end
	local keep = math.max(WINDOW_LEAST, record.endsAt - DateTime.now().UnixTimestamp + WINDOW_LINGER)
	attempt("show", function()
		MemoryStoreService:GetSortedMap(WINDOW_PREFIX .. record.cardId):SetAsync(record.id, summary(record), keep, record.endsAt)
	end)
end

function AuctionStore.hide(record: any)
	if inMemory() then
		if memoryWindows[record.cardId] then
			memoryWindows[record.cardId][record.id] = nil
		end
		return
	end
	attempt("hide", function()
		MemoryStoreService:GetSortedMap(WINDOW_PREFIX .. record.cardId):RemoveAsync(record.id)
	end)
end

-- A card's auctions, soonest to end first, or nil if the window couldn't be read.
function AuctionStore.browse(cardId: string): { any }?
	local found = {}
	if inMemory() then
		for _, entry in memoryWindows[cardId] or {} do
			table.insert(found, entry)
		end
		table.sort(found, function(a, b)
			return a.endsAt < b.endsAt
		end)
		return found
	end
	local ok = attempt("browse", function()
		local page = MemoryStoreService:GetSortedMap(WINDOW_PREFIX .. cardId):GetRangeAsync(Enum.SortDirection.Ascending, WINDOW_PAGE)
		for _, item in page do
			table.insert(found, item.value)
		end
	end)
	return if ok then found else nil
end

-- Tells every server this auction changed.
function AuctionStore.announce(id: string)
	if inMemory() then
		heard:Fire(id)
		return
	end
	local ok = attempt("announce", function()
		MessagingService:PublishAsync(TOPIC, id)
	end)
	if not ok then
		heard:Fire(id) -- this server's own players are still checked at once
	end
end

function AuctionStore.start()
	if inMemory() then
		return
	end
	task.spawn(attempt, "subscribe", function()
		MessagingService:SubscribeAsync(TOPIC, function(message)
			if type(message.Data) == "string" then
				heard:Fire(message.Data)
			end
		end)
	end)
end

return AuctionStore
