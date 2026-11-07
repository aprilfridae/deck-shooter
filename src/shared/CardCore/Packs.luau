-- Packs: what a roll gives and what a pack holds. The odds live in Config.
local Cards = require("./Cards")
local Config = require("./Config")
local Tier = require("./Tier")
local Variant = require("./Variant")

export type Outcomes = { { name: string, chance: number } } -- commonest first

local Packs = {
	ids = { "Field", "BlackSite", "Prototype", "ZeroDay" }, -- commonest first
	CARDS_PER_PACK = 3,
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

return Packs
