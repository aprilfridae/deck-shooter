-- Packs: what a roll gives and what a pack holds. The odds live in Config.
local Cards = require("./Cards")
local Config = require("./Config")
local Inventory = require("./Inventory")
local Tier = require("./Tier")
local Variant = require("./Variant")

export type Outcomes = { { name: string, chance: number } } -- commonest first

local Packs = {
	ids = { "Field", "BlackSite", "Prototype", "ZeroDay" }, -- commonest first
	CARDS_PER_PACK = 3,
	ROLL_SECONDS = 3,
	OPEN_SECONDS = 2, -- Auto Open's pace
}

local ZERO_DAY_PACK = "ZeroDay"

function Packs.isValid(pack: any): boolean
	return type(pack) == "string" and table.find(Packs.ids, pack) ~= nil
end

function Packs.luck(rebirths: number): number
	return 1 + Config.LuckPerRebirth * rebirths
end

-- Luck raises everything but the first outcome, which takes what's left. If the raised outcomes
-- reach 100%, they're cut back evenly and the first gets nothing.
function Packs.scale(outcomes: Outcomes, luck: number): Outcomes
	local scaled: Outcomes = table.clone(outcomes)
	if #outcomes == 1 then
		return scaled
	end
	local rare = 0
	for index = 2, #outcomes do
		rare += outcomes[index].chance * luck
	end
	local shrink = math.max(rare, 1)
	for index = 2, #outcomes do
		scaled[index] = { name = outcomes[index].name, chance = outcomes[index].chance * luck / shrink }
	end
	scaled[1] = { name = outcomes[1].name, chance = if rare >= 1 then 0 else 1 - rare }
	return scaled
end

function Packs.packOdds(luck: number): Outcomes
	local odds = Config.PackOdds
	return Packs.scale({
		{ name = "Field", chance = 0 },
		{ name = "BlackSite", chance = odds.BlackSite },
		{ name = "Prototype", chance = odds.Prototype },
		{ name = "ZeroDay", chance = odds.ZeroDay },
	}, luck)
end

function Packs.tierOdds(pack: string, slot: number, luck: number): Outcomes
	local key = if pack == ZERO_DAY_PACK and slot == 1 then "ZeroDayFirst" else pack
	local outcomes: Outcomes = {}
	for index, row in Config.PackTierOdds[key] do
		outcomes[index] = { name = row[1], chance = row[2] }
	end
	return Packs.scale(outcomes, luck)
end

function Packs.variantOdds(pack: string, slot: number, luck: number): Outcomes
	if pack == ZERO_DAY_PACK and slot == 1 then
		return { { name = Variant.ZeroDay, chance = 1 } }
	end
	local odds = Config.VariantOdds
	return Packs.scale({
		{ name = Variant.Base, chance = 0 },
		{ name = Variant.Chromatic, chance = odds.Chromatic },
		{ name = Variant.Redacted, chance = odds.Redacted },
		{ name = Variant.ZeroDay, chance = Config.PackVariantOdds[pack] or odds.ZeroDay },
	}, luck)
end

-- Low rolls land on the rarest outcomes, and anything left over on the commonest.
function Packs.pick(outcomes: Outcomes, rng: () -> number): string
	local roll = rng()
	local reached = 0
	for index = #outcomes, 2, -1 do
		reached += outcomes[index].chance
		if roll < reached then
			return outcomes[index].name
		end
	end
	return outcomes[1].name
end

local function pickCard(rng: () -> number): string
	local count = #Cards.ids
	return Cards.ids[math.min(count, math.floor(rng() * count) + 1)]
end

function Packs.rollPack(luck: number, rng: () -> number): string
	return Packs.pick(Packs.packOdds(luck), rng)
end

function Packs.rollCard(pack: string, slot: number, luck: number, rng: () -> number): any
	local tier = Packs.pick(Packs.tierOdds(pack, slot, luck), rng)
	local variant = Packs.pick(Packs.variantOdds(pack, slot, luck), rng)
	return { cardId = pickCard(rng), tier = tier, variant = variant }
end

function Packs.isRare(card: any): boolean
	return card.tier == Tier.Prototype or card.variant ~= Variant.Base
end

function Packs.canRoll(lastRollAt: number?, now: number): boolean
	return lastRollAt == nil or now - lastRollAt >= Packs.ROLL_SECONDS
end

function Packs.pile(data: any): number
	local total = 0
	for _, pack in Packs.ids do
		total += data.packs[pack]
	end
	return total
end

function Packs.nextToOpen(data: any): string?
	for _, pack in Packs.ids do
		if data.packs[pack] > 0 then
			return pack
		end
	end
	return nil
end

function Packs.roll(data: any, rng: () -> number): (boolean, string)
	local pack = Packs.rollPack(Packs.luck(data.rebirths), rng)
	if data.packs[pack] >= Config.MaxStackCount then
		return false, "PileFull"
	end
	data.packs[pack] += 1
	return true, pack
end

function Packs.open(data: any, pack: string, rng: () -> number): (boolean, any)
	if (data.packs[pack] or 0) < 1 then
		return false, "NoPacks"
	end
	data.packs[pack] -= 1
	local luck = Packs.luck(data.rebirths)
	local cards = {}
	for slot = 1, Packs.CARDS_PER_PACK do
		local card = Packs.rollCard(pack, slot, luck, rng)
		Inventory.add(data, card.cardId, card.tier, card.variant, 1)
		cards[slot] = card
	end
	return true, cards
end

-- Stack keys by card, tier and variant, so a big pile doesn't build a string for every card.
local function stackKeys(): any
	local keys = {}
	for _, cardId in Cards.ids do
		keys[cardId] = {}
		for _, tier in Tier.order do
			keys[cardId][tier] = {}
			for _, variant in Variant.order do
				keys[cardId][tier][variant] = Inventory.key(cardId, tier, variant)
			end
		end
	end
	return keys
end

-- Opens everything at once. A pile can hold millions of cards, so this counts them by stack.
function Packs.openAll(data: any, rng: () -> number): { opened: number, cards: { [string]: number } }
	local luck = Packs.luck(data.rebirths)
	local keys = stackKeys()
	local counts: { [string]: number } = {}
	local opened = 0
	for _, pack in Packs.ids do
		local count = data.packs[pack]
		for slot = 1, Packs.CARDS_PER_PACK do
			local tiers = Packs.tierOdds(pack, slot, luck)
			local variants = Packs.variantOdds(pack, slot, luck)
			for _ = 1, count do
				local tier = Packs.pick(tiers, rng)
				local variant = Packs.pick(variants, rng)
				local key = keys[pickCard(rng)][tier][variant]
				counts[key] = (counts[key] or 0) + 1
			end
		end
		opened += count
		data.packs[pack] = 0
	end
	for key, count in counts do
		local cardId, tier, variant = Inventory.parse(key)
		Inventory.add(data, cardId :: string, tier :: string, variant :: string, count)
	end
	return { opened = opened, cards = counts }
end

-- Pays out an Open All purchase once. With nothing to open, the purchase waits in openAllCredits,
-- because Auto Open can empty the pile while the prompt is up.
function Packs.redeem(data: any, purchaseId: string, rng: () -> number): (string, any?)
	if table.find(data.receipts, purchaseId) then
		return "Repeat", nil
	end
	table.insert(data.receipts, purchaseId)
	while #data.receipts > Config.ReceiptMemory do
		table.remove(data.receipts, 1)
	end
	if Packs.pile(data) == 0 then
		data.openAllCredits += 1
		return "Banked", nil
	end
	return "Opened", Packs.openAll(data, rng)
end

function Packs.useCredit(data: any, rng: () -> number): (boolean, any)
	if data.openAllCredits < 1 then
		return false, "NoCredit"
	elseif Packs.pile(data) == 0 then
		return false, "NoPacks"
	end
	data.openAllCredits -= 1
	return true, Packs.openAll(data, rng)
end

return Packs
