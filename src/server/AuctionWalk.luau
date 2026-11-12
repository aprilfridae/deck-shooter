-- A walkthrough of one auction for River to run in Studio, because the market has no screen yet
-- (docs/specs/auction-house.md). During Play, in the command bar with the Server view selected:
--
--   game.ServerStorage.AuctionWalk:Fire()
--
-- CardCore.server.luau makes that event in Studio. Requiring this module from the command bar wouldn't work: it
-- would get its own copies of the server modules, with no players loaded in them.
--
-- It uses the real requests in AuctionServer on the first player's own save. Studio only.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local CardCore = ReplicatedStorage:WaitForChild("CardCore")
local Auction = require(CardCore.Auction)
local Inventory = require(CardCore.Inventory)
local AuctionServer = require(script.Parent.AuctionServer)
local AuctionStore = require(script.Parent.AuctionStore)
local PlayerCards = require(script.Parent.PlayerCards)

local STAND_IN = 0 -- a made-up buyer with no save
local BUY_NOW = 10

local function say(text: string)
	print(`[AuctionWalk] {text}`)
end

local function holds(data: any, key: string, serial: number): boolean
	local found = data.serials[key]
	for index = 1, if found then #found.runs else 0, 2 do
		if serial >= found.runs[index] and serial <= found.runs[index + 1] then
			return true
		end
	end
	return false
end

-- The player's lowest-numbered card that the rules allow them to list.
local function pick(data: any): any?
	local best
	for key, found in data.serials do
		local serial = found.runs[1]
		local cardId, tier, variant = Inventory.parse(key)
		if serial and cardId and (not best or serial < best.serial) then
			local req = { cardId = cardId, tier = tier, variant = variant, serial = serial, startBid = 1, hours = 1 }
			if Auction.canList(data, req) then
				best = req
			end
		end
	end
	return best
end

return function()
	if not RunService:IsStudio() then
		warn("[AuctionWalk] Studio only.")
		return
	end
	local player = PlayerCards.loaded()[1]
	local data = player and PlayerCards.get(player)
	if not data then
		warn("[AuctionWalk] No loaded player. Press Play first.")
		return
	end
	local card = pick(data)
	if not card then
		warn("[AuctionWalk] No numbered card you can list. Open a pack, wait for its serials, and try again.")
		return
	end
	local key = Inventory.key(card.cardId, card.tier, card.variant)
	local name = `{card.cardId} {card.tier} {card.variant} #{card.serial}`
	say(`Using {name}. Step 2 removes this card from your save and gives you {BUY_NOW} Credits from a made-up buyer.`)

	say("STEP 1: list it, then cancel it.")
	local listed = AuctionServer.list(player, data, card)
	say(`  list: ok={listed.ok} code={listed.code}`)
	if not listed.ok then
		return
	end
	local _, record = AuctionStore.read(listed.id)
	say(`  record exists: {record ~= nil}, seller {record and record.sellerName}, start bid {record and record.startBid}`)
	say(`  in your collection now: {holds(data, key, card.serial)} (expect false)`)
	local cancelled = AuctionServer.cancel(player, data, listed.id)
	say(`  cancel: ok={cancelled.ok} code={cancelled.code}`)
	say(`  back in your collection: {holds(data, key, card.serial)} (expect true)`)
	if not holds(data, key, card.serial) then
		warn("[AuctionWalk] The card did not come back. Stopping.")
		return
	end

	say(`STEP 2: list it with Buy Now at {BUY_NOW}, and a made-up buyer takes it.`)
	local sale = table.clone(card)
	sale.buyNow = BUY_NOW
	local before = data.credits
	local second = AuctionServer.list(player, data, sale)
	say(`  list: ok={second.ok} code={second.code}`)
	if not second.ok then
		return
	end
	-- The buyer has no save, so its bid goes straight onto the record. A real bid goes through AuctionServer.bid.
	local _, bought = AuctionStore.change(second.id, function(current)
		return if current then Auction.accept(current, STAND_IN, "Stand-in", BUY_NOW, DateTime.now().UnixTimestamp) else nil
	end)
	say(`  record: bidder {bought and bought.bidderName}, bid {bought and bought.bid}, ended {bought ~= nil and Auction.ended(bought, DateTime.now().UnixTimestamp)}`)
	AuctionServer.check(player, second.id)
	say(`  your Credits: {before} -> {data.credits} (expect +{BUY_NOW})`)
	say(`  in your collection now: {holds(data, key, card.serial)} (expect false)`)
	say(`  still listed in your save: {data.market.listed[second.id] ~= nil} (expect false)`)
	-- Nobody will ever collect for the stand-in, so clear its record away.
	AuctionStore.remove(second.id)
	say("Done.")
end
