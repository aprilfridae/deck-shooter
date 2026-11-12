-- Runs auctions on the server: the requests players make and the checks that settle each player's side
-- (docs/specs/auction-house.md). The rules are in CardCore.Auction and the shared parts in AuctionStore.
--
-- The one ordering rule, which every path below follows:
--   a change that TAKES from a player (a card into a listing, Credits into a bid) is written to the data store
--   before the shared record is told;
--   a change that GIVES to a player (a won card, a sale's Credits, a card coming home) is written before the
--   record is marked done for that side.
-- Break it and a server dying at the wrong moment copies or loses things.
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CardCore = ReplicatedStorage:WaitForChild("CardCore")
local Auction = require(CardCore.Auction)
local Cards = require(CardCore.Cards)
local Inventory = require(CardCore.Inventory)
local Requests = require(CardCore.Requests)
local AuctionStore = require(script.Parent.AuctionStore)
local PlayerCards = require(script.Parent.PlayerCards)

local LOAD_SPACING = 0.5 -- seconds between a loading save's checks
local ENDED_STEP = 5 -- seconds between looks for auctions whose time is up
local ENDED_RETRY = 30 -- seconds before an ended auction is checked again
local BACKSTOP = 300 -- seconds between checks of everything, in case an announcement was missed
local BROWSE_FRESH = 10 -- seconds a card's window is reused for

-- Auctions a request of this player's is in the middle of. A check must leave these alone: while a bid waits on
-- the data store the record still names someone else, and a check would hand back Credits that are about to win.
-- Never saved: after a crash no request can be in flight, so a load checks everything.
local busy: { [Player]: { [string]: boolean } } = {}
local checking: { [Player]: { [string]: boolean } } = {}
local tried: { [Player]: { [string]: number } } = {}
local windows: { [string]: { at: number, auctions: { any } } } = {}

local AuctionServer = {}

local function now(): number
	return DateTime.now().UnixTimestamp
end

local function flags(of: { [Player]: { [string]: any } }, player: Player): { [string]: any }
	local mine = of[player]
	if not mine then
		mine = {}
		of[player] = mine
	end
	return mine
end

-- Runs a request with its auction marked busy, and always unmarks it, even if the request errors.
local function whileBusy(player: Player, id: string, request: () -> any): any
	flags(busy, player)[id] = true
	local ok, answer = pcall(request)
	flags(busy, player)[id] = nil
	if not ok then
		warn(`[CardCore] auction request failed: {answer}`)
		return { ok = false, code = "Failed" }
	end
	return answer
end

-- Marks one side done on the record, once that side's save is written, and deletes the record when both are.
local function markDone(id: string, side: "seller" | "winner"): boolean
	local ok, after = AuctionStore.change(id, function(stored)
		return if stored then (Auction.finish(stored, side)) else nil
	end)
	if not ok then
		return false
	end
	if after then
		local _, delete = Auction.finish(after, side)
		if delete then
			AuctionStore.remove(id)
		end
	end
	return true
end

-- Compares one of this player's market entries with its record and does whatever is due.
function AuctionServer.check(player: Player, id: string)
	if flags(busy, player)[id] or flags(checking, player)[id] then
		return
	end
	flags(checking, player)[id] = true
	local ok, problem = pcall(function()
		local ready, record = AuctionStore.read(id) -- yields
		local data = PlayerCards.get(player)
		-- A failed read decides nothing. A request that began during the read owns this auction now.
		if not ready or not data or flags(busy, player)[id] then
			return
		end
		local market = data.market
		if not market.listed[id] and not market.bids[id] then
			-- Only a note is left: the card was collected but the record wasn't marked. Finish that.
			if market.settled[id] and (not record or record.winnerDone or (PlayerCards.saveAndWait(player) and markDone(id, "winner"))) then
				Auction.cleared(data, id)
			end
			return
		end

		local did = Auction.settle(data, player.UserId, id, record, now())
		if did == "Publish" then
			-- TAKES: the listing is already in the save from the request that made it, or this is a fresh load.
			local listed = market.listed[id]
			local made = Auction.record(id, player.UserId, player.Name, listed)
			if PlayerCards.saveAndWait(player) and AuctionStore.create(made) then
				listed.live = true
				AuctionStore.show(made)
				AuctionStore.announce(id)
			end
		elseif did == "Paid" or did == "Returned" then
			-- GIVES: save first, then mark.
			PlayerCards.changed(player)
			if record then
				AuctionStore.hide(record)
				if PlayerCards.saveAndWait(player) then
					markDone(id, "seller")
				end
			end
		elseif did == "Collected" then
			-- GIVES: save first, then mark. The save's note covers the gap between the two.
			PlayerCards.changed(player)
			if PlayerCards.saveAndWait(player) and markDone(id, "winner") then
				Auction.cleared(data, id)
			end
		elseif did == "Refunded" or did == "Done" then
			PlayerCards.changed(player)
		end
	end)
	flags(checking, player)[id] = nil
	if not ok then
		warn(`[CardCore] auction check failed: {problem}`)
	end
end

local function entries(data: any): { string }
	local ids = {}
	for id in data.market.listed do
		table.insert(ids, id)
	end
	for id in data.market.bids do
		table.insert(ids, id)
	end
	for id in data.market.settled do
		if not data.market.bids[id] then
			table.insert(ids, id)
		end
	end
	return ids
end

-- ListCard. TAKES: card into the save's listing, save written, then the record is created.
function AuctionServer.list(player: Player, data: any, raw: any): any
	local req = Requests.parseListing(raw)
	if not req then
		return { ok = false, code = "BadRequest" }
	end
	local allowed, code = Auction.canList(data, req)
	if not allowed then
		return { ok = false, code = code }
	end
	local id = HttpService:GenerateGUID(false)
	return whileBusy(player, id, function()
		local listed = Auction.list(data, id, req, now())
		PlayerCards.changed(player)
		if not PlayerCards.saveAndWait(player) then
			-- Nothing shared knows about this listing yet, so it can simply be undone.
			data.market.listed[id] = nil
			Inventory.give(data, Inventory.key(req.cardId, req.tier, req.variant), req.serial)
			PlayerCards.changed(player)
			return { ok = false, code = "SaveFailed" }
		end
		local record = Auction.record(id, player.UserId, player.Name, listed)
		-- If this fails the listing stays in the save, not yet live, and a later check publishes it.
		if AuctionStore.create(record) then
			listed.live = true
			AuctionStore.show(record)
			AuctionStore.announce(id)
		end
		return { ok = true, id = id }
	end)
end

-- PlaceBid. TAKES: Credits into the save's bid, save written, then the record is asked to accept it.
function AuctionServer.bid(player: Player, data: any, raw: any): any
	local req = Requests.parseBid(raw)
	if not req then
		return { ok = false, code = "BadRequest" }
	end
	local id = req.id
	if flags(busy, player)[id] then
		return { ok = false, code = "Busy" }
	end
	return whileBusy(player, id, function()
		local ready, record = AuctionStore.read(id)
		if not ready then
			return { ok = false, code = "Unavailable" }
		elseif not record then
			return { ok = false, code = "Gone" }
		end
		local allowed, code = Auction.canBid(data, player.UserId, record, req.amount, now())
		if not allowed then
			return { ok = false, code = code, min = Auction.minBid(record) }
		end
		local price = Auction.price(record, req.amount)
		local before = data.market.bids[id]
		local heldBefore = if before then before.amount else 0
		Auction.hold(data, id, price, record.endsAt)
		PlayerCards.changed(player)
		if not PlayerCards.saveAndWait(player) then
			-- The record hasn't heard of this bid, so the Credits can simply go back.
			data.credits += price - heldBefore
			data.market.bids[id] = before
			PlayerCards.changed(player)
			return { ok = false, code = "SaveFailed" }
		end

		local name = player.Name
		local changed, stored = AuctionStore.change(id, function(current)
			return if current then Auction.accept(current, player.UserId, name, req.amount, now()) else nil
		end)
		if not changed then
			-- Nobody knows whether the record took the bid. The Credits stay set aside and a check decides.
			return { ok = false, code = "Unavailable" }
		end
		local won = stored ~= nil and stored.bidder == player.UserId and stored.bid == price
		if not won then
			-- Someone got in first. settle sees the record names another bidder and hands the Credits back.
			Auction.settle(data, player.UserId, id, stored, now())
			PlayerCards.changed(player)
			return { ok = false, code = "TooLow", min = if stored then Auction.minBid(stored) else nil }
		end
		data.market.bids[id].endsAt = stored.endsAt
		AuctionStore.show(stored)
		AuctionStore.announce(id)
		return { ok = true, price = price, ended = Auction.ended(stored, now()) }
	end)
end

-- CancelListing. The record is cancelled first; the card comes home through the ordinary check.
function AuctionServer.cancel(player: Player, _data: any, raw: any): any
	local id = Requests.parseAuctionId(raw)
	if not id then
		return { ok = false, code = "BadRequest" }
	end
	local changed, stored = AuctionStore.change(id, function(current)
		return if current then Auction.cancel(current, player.UserId, now()) else nil
	end)
	if not changed then
		return { ok = false, code = "Unavailable" }
	elseif not stored or stored.seller ~= player.UserId or not stored.cancelled then
		return { ok = false, code = "CantCancel" }
	end
	AuctionStore.hide(stored)
	AuctionStore.announce(id)
	AuctionServer.check(player, id)
	return { ok = true }
end

local function browse(_player: Player, _data: any, raw: any): any
	if not Cards.isValid(raw) then
		return { ok = false, code = "BadRequest" }
	end
	local window = windows[raw]
	if not window or os.clock() - window.at >= BROWSE_FRESH then
		local found = AuctionStore.browse(raw)
		if not found then
			return { ok = false, code = "Unavailable" }
		end
		window = { at = os.clock(), auctions = found }
		windows[raw] = window
	end
	return { ok = true, auctions = window.auctions, now = now() }
end

local function checkAll(player: Player, spacing: number)
	local data = PlayerCards.get(player)
	if not data then
		return
	end
	for _, id in entries(data) do
		if PlayerCards.get(player) ~= data then
			return -- they left
		end
		AuctionServer.check(player, id)
		task.wait(spacing)
	end
end

-- Checks auctions whose time is up, and everything now and then in case an announcement was missed.
local function watch()
	local lastSweep = os.clock()
	while true do
		task.wait(ENDED_STEP)
		local sweep = os.clock() - lastSweep >= BACKSTOP
		if sweep then
			lastSweep = os.clock()
		end
		local time = now()
		for _, player in PlayerCards.loaded() do
			local data = PlayerCards.get(player)
			if data then
				local last = flags(tried, player)
				for _, id in entries(data) do
					local entry = data.market.listed[id] or data.market.bids[id]
					local due = entry == nil or entry.endsAt <= time
					if sweep or (due and os.clock() - (last[id] or -math.huge) >= ENDED_RETRY) then
						last[id] = os.clock()
						task.spawn(AuctionServer.check, player, id)
					end
				end
			end
		end
	end
end

function AuctionServer.start(remote: (string, (Player, any, any) -> any) -> ())
	remote("ListCard", AuctionServer.list)
	remote("PlaceBid", AuctionServer.bid)
	remote("CancelListing", AuctionServer.cancel)
	remote("BrowseAuctions", browse)
	remote("MyAuctions", function(_, data)
		return { ok = true, listed = data.market.listed, bids = data.market.bids, now = now() }
	end)

	AuctionStore.start()
	AuctionStore.heard:Connect(function(id: string)
		for _, player in PlayerCards.loaded() do
			local data = PlayerCards.get(player)
			if data and (data.market.listed[id] or data.market.bids[id]) then
				task.spawn(AuctionServer.check, player, id)
			end
		end
	end)
	PlayerCards.profileLoaded:Connect(function(player: Player)
		task.spawn(checkAll, player, LOAD_SPACING)
	end)
	Players.PlayerRemoving:Connect(function(player: Player)
		busy[player], checking[player], tried[player] = nil, nil, nil
	end)
	task.spawn(watch)
end

return AuctionServer
