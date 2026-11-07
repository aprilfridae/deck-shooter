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
	CURRENT_VERSION = 4,
}

function SaveData.new(): SaveData
	local data: SaveData = {
		version = SaveData.CURRENT_VERSION,
		credits = 0,
		creditRemainder = 0,
		stacks = {},
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
		Inventory.add(data, cardId, "Field", "Base", 1)
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
					Inventory.add(data, cardId, Tier.Field, Variant.Base, 1)
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
	data.stacks = cleanStacks(raw.stacks)
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
	if type(raw.class) == "string" and Config.Classes[raw.class] then
		data.class = raw.class
	end
	if type(raw.rifle) == "string" and Config.Rifles[raw.rifle] then
		data.rifle = raw.rifle
	end
	data.settings = Settings.clean(raw.settings)
	data.commentsOff = raw.commentsOff == true
	cleanPacks(data, raw.packs)
	if isCount(raw.rebirths, Config.MaxStackCount) then
		data.rebirths = raw.rebirths
	end
	if isCount(raw.openAllCredits, Config.MaxStackCount) then
		data.openAllCredits = raw.openAllCredits
	end
	data.receipts = cleanReceipts(raw.receipts)
	data.deck = cleanDeck(data, raw.deck)
	return data, nil
end

return SaveData
