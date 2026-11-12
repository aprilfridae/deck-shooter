-- The saved player record.
local Cards = require("./Cards")
local Config = require("./Config")
local Deck = require("./Deck")
local Inventory = require("./Inventory")
local Packs = require("./Packs")
local Settings = require("./Settings")
local Tier = require("./Tier")
local Variant = require("./Variant")

local DECK_SIZE = Deck.SIZE

export type DeckSlot = { cardId: string, tier: string }
export type SaveData = {
	version: number,
	credits: number,
	creditRemainder: number,
	stacks: { [string]: number },
	serials: { [string]: { runs: { number }, plain: number } }, -- see Inventory
	-- What this player has in the market: cards up for auction, Credits set aside in bids, and auctions whose
	-- card has been collected. See Auction.luau.
	market: { listed: { [string]: any }, bids: { [string]: any }, settled: { [string]: boolean } },
	deck: { DeckSlot },
	gunLevels: { number },
	catalysts: number,
	class: string,
	rifle: string,
	settings: Settings.Settings,
	commentsOff: boolean,
	packs: { [string]: number },
	rebirths: number,
	openAllCredits: number, -- Open All purchases waiting for a pile
	receipts: { string },
}

local SaveData = {
	CURRENT_VERSION = 6,
	SERIALS_VERSION = 5, -- the first version with serials. Older saves are reset.
}

function SaveData.new(): SaveData
	local data: SaveData = {
		version = SaveData.CURRENT_VERSION,
		credits = 0,
		creditRemainder = 0,
		stacks = {},
		serials = {},
		market = { listed = {}, bids = {}, settled = {} },
		deck = {},
		gunLevels = { 0, 0 },
		catalysts = 0,
		class = Config.DefaultClass,
		rifle = Config.DefaultRifle,
		settings = Settings.new(),
		commentsOff = false,
		packs = {},
		rebirths = 0,
		openAllCredits = 0,
		receipts = {},
	}
	for _, pack in Packs.ids do
		data.packs[pack] = 0
	end
	for _, cardId in Config.StarterDeck do
		Inventory.addPlain(data, cardId, "Field", "Base", 1)
		table.insert(data.deck, { cardId = cardId, tier = "Field" })
	end
	return data
end

local function isCount(n: any, max: number): boolean
	return type(n) == "number" and n >= 0 and n <= max and n == math.floor(n)
end

local function cleanStacks(raw: any): { [string]: number }
	local stacks = {}
	if type(raw) ~= "table" then
		return stacks
	end
	for key, n in raw do
		if type(key) == "string" and isCount(n, Config.MaxStackCount) and n > 0 then
			local cardId, tier, variant = Inventory.parse(key)
			-- Unknown card ids stay, so a removed card can come back.
			if cardId and Tier.isValid(tier) and Variant.isValid(variant) then
				stacks[key] = n
			end
		end
	end
	return stacks
end

-- A stack's runs, or nil if anything about them is wrong: a serial must never be held twice, so damaged runs
-- are dropped whole and their copies go back to waiting for a number.
local function cleanRuns(raw: any): ({ number }?, number)
	if type(raw) ~= "table" or #raw % 2 ~= 0 then
		return nil, 0
	end
	local runs, total, last = {}, 0, 0
	for index = 1, #raw, 2 do
		local from, to = raw[index], raw[index + 1]
		local whole = type(from) == "number" and type(to) == "number" and from == math.floor(from) and to == math.floor(to)
		if not whole or from <= last or to < from then
			return nil, 0
		end
		table.insert(runs, from)
		table.insert(runs, to)
		total += to - from + 1
		last = to
	end
	return runs, total
end

local function cleanSerials(data: SaveData, raw: any)
	if type(raw) ~= "table" then
		return
	end
	for key, entry in raw do
		local have = data.stacks[key]
		if have and type(entry) == "table" then
			local runs, total = cleanRuns(entry.runs)
			local plain = entry.plain
			if runs and isCount(plain, have) and total + plain <= have and total + plain > 0 then
				data.serials[key] = { runs = runs, plain = plain }
			end
		end
	end
end

local function isWhole(n: any, min: number, max: number): boolean
	return type(n) == "number" and n == math.floor(n) and n >= min and n <= max
end

-- Market entries hold real cards and Credits, so every well-formed one is kept, however many there are. A damaged
-- one is dropped: what it held can't be trusted.
local function cleanMarket(data: SaveData, raw: any)
	if type(raw) ~= "table" then
		return
	end
	if type(raw.listed) == "table" then
		for id, entry in raw.listed do
			local good = type(id) == "string"
				and type(entry) == "table"
				and type(entry.cardId) == "string"
				and Tier.isValid(entry.tier)
				and Variant.isValid(entry.variant)
				and isWhole(entry.serial, 1, math.huge)
				and isWhole(entry.startBid, 1, Config.MaxCredits)
				and (entry.buyNow == nil or (isWhole(entry.buyNow, 1, Config.MaxCredits) and entry.buyNow > entry.startBid))
				and type(entry.endsAt) == "number"
			if good then
				data.market.listed[id] = {
					cardId = entry.cardId,
					tier = entry.tier,
					variant = entry.variant,
					serial = entry.serial,
					startBid = entry.startBid,
					buyNow = entry.buyNow,
					endsAt = entry.endsAt,
					live = entry.live == true,
				}
			end
		end
	end
	if type(raw.bids) == "table" then
		for id, entry in raw.bids do
			if type(id) == "string" and type(entry) == "table" and isWhole(entry.amount, 1, Config.MaxCredits) and type(entry.endsAt) == "number" then
				data.market.bids[id] = { amount = entry.amount, endsAt = entry.endsAt }
			end
		end
	end
	if type(raw.settled) == "table" then
		for id, done in raw.settled do
			if type(id) == "string" and done == true then
				data.market.settled[id] = true
			end
		end
	end
end

local function cleanPacks(data: SaveData, raw: any)
	if type(raw) ~= "table" then
		return
	end
	for _, pack in Packs.ids do
		if isCount(raw[pack], Config.MaxStackCount) then
			data.packs[pack] = raw[pack]
		end
	end
end

local function cleanReceipts(raw: any): { string }
	local receipts = {}
	if type(raw) ~= "table" then
		return receipts
	end
	for _, receipt in raw do
		if type(receipt) == "string" then
			table.insert(receipts, receipt)
		end
	end
	while #receipts > Config.ReceiptMemory do
		table.remove(receipts, 1)
	end
	return receipts
end

local function bestOwnedTier(data: SaveData, cardId: string): string?
	for i = #Tier.order, 1, -1 do
		if Inventory.count(data, cardId, Tier.order[i]) > 0 then
			return Tier.order[i]
		end
	end
	return nil
end

-- Builds a legal deck, keeping each slot's card and position where it can.
local function cleanDeck(data: SaveData, raw: any): { DeckSlot }
	local deck: { [number]: DeckSlot } = {}
	local used: { [string]: boolean } = {}
	local rawDeck = if type(raw) == "table" then raw else {}

	for i = 1, DECK_SIZE do
		local slot = rawDeck[i]
		local cardId = if type(slot) == "table" then slot.cardId else nil
		if Cards.isValid(cardId) and not used[cardId] then
			local owned = Tier.isValid(slot.tier) and Inventory.count(data, cardId, slot.tier) > 0
			local tier = if owned then slot.tier else bestOwnedTier(data, cardId)
			if tier then
				deck[i] = { cardId = cardId, tier = tier }
				used[cardId] = true
			end
		end
	end

	for i = 1, DECK_SIZE do
		if not deck[i] then
			for _, cardId in Cards.ids do
				local tier = bestOwnedTier(data, cardId)
				if tier and not used[cardId] then
					deck[i] = { cardId = cardId, tier = tier }
					used[cardId] = true
					break
				end
			end
		end
		if not deck[i] then
			for _, cardId in Config.StarterDeck do
				if not used[cardId] then
					Inventory.addPlain(data, cardId, Tier.Field, Variant.Base, 1)
					deck[i] = { cardId = cardId, tier = Tier.Field }
					used[cardId] = true
					break
				end
			end
		end
	end

	return deck
end

-- Returns a clean save. Returns nil and "NewerVersion" for a save from a newer
-- build; the caller must not write that save back.
function SaveData.load(raw: any): (SaveData?, string?)
	if type(raw) ~= "table" then
		return SaveData.new(), nil
	end
	if type(raw.version) == "number" and raw.version > SaveData.CURRENT_VERSION then
		return nil, "NewerVersion"
	end

	local data = SaveData.new()
	-- The fresh start (River, 2026-11-11): a save from before serials keeps nothing that was earned, so every
	-- serial comes from a pull. It happens once, because the save is then written back as the current version,
	-- and it can't be undone.
	local reset = type(raw.version) ~= "number" or raw.version < SaveData.SERIALS_VERSION
	if type(raw.class) == "string" and Config.Classes[raw.class] then
		data.class = raw.class
	end
	if type(raw.rifle) == "string" and Config.Rifles[raw.rifle] then
		data.rifle = raw.rifle
	end
	data.settings = Settings.clean(raw.settings)
	data.commentsOff = raw.commentsOff == true
	if isCount(raw.openAllCredits, Config.MaxStackCount) then
		data.openAllCredits = raw.openAllCredits
	end
	data.receipts = cleanReceipts(raw.receipts)
	if reset then
		return data, nil
	end

	data.stacks = cleanStacks(raw.stacks)
	data.serials = {}
	cleanSerials(data, raw.serials)
	cleanMarket(data, raw.market)
	if isCount(raw.credits, Config.MaxCredits) then
		data.credits = raw.credits
	end
	if type(raw.creditRemainder) == "number" and raw.creditRemainder >= 0 and raw.creditRemainder < 1 then
		data.creditRemainder = raw.creditRemainder
	end
	if isCount(raw.catalysts, Config.MaxStackCount) then
		data.catalysts = raw.catalysts
	end
	if type(raw.gunLevels) == "table" then
		for i = 1, #data.gunLevels do
			if isCount(raw.gunLevels[i], Config.MaxGunLevel) then
				data.gunLevels[i] = raw.gunLevels[i]
			end
		end
	end
	cleanPacks(data, raw.packs)
	if isCount(raw.rebirths, Config.MaxStackCount) then
		data.rebirths = raw.rebirths
	end
	data.deck = cleanDeck(data, raw.deck)
	return data, nil
end

return SaveData
