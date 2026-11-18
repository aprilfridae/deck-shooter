-- Fuses copies of a card into one copy of the next tier.
-- Every check runs before the first change, so a failed fusion changes nothing.
local Cards = require("./Cards")
local Config = require("./Config")
local Inventory = require("./Inventory")
local Tier = require("./Tier")
local Variant = require("./Variant")

export type FuseRequest = {
	cardId: string,
	tier: string,
	useCatalyst: boolean,
	includeVariants: boolean,
}
export type FuseResult = { cardId: string, tier: string, variant: string }

local Fusion = {}

function Fusion.fuse(data: any, req: FuseRequest, rng: () -> number): (boolean, any)
	if not Cards.isValid(req.cardId) then
		return false, "UnknownCard"
	elseif not Tier.isValid(req.tier) then
		return false, "InvalidTier"
	end
	local nextTier = Tier.next(req.tier)
	if not nextTier then
		return false, "TopTier"
	elseif req.useCatalyst and data.catalysts < 1 then
		return false, "NoCatalyst"
	end

	local needed = if req.useCatalyst then Config.CatalystCopies else Config.CopiesToFuse
	if Inventory.count(data, req.cardId, req.tier) < needed then
		return false, "NotEnoughCopies"
	elseif not req.includeVariants and Inventory.count(data, req.cardId, req.tier, Variant.Base) < needed then
		return false, "VariantsNotConfirmed"
	end
	local fee = Config.FusionFee[req.tier]
	if data.credits < fee then
		return false, "NotEnoughCredits"
	end

	local remaining = needed
	for _, variant in Variant.order do
		local spend = math.min(remaining, Inventory.count(data, req.cardId, req.tier, variant))
		if spend > 0 then
			Inventory.remove(data, req.cardId, req.tier, variant, spend)
			remaining -= spend
		end
	end
	data.credits -= fee
	if req.useCatalyst then
		data.catalysts -= 1
	end

	local result = { cardId = req.cardId, tier = nextTier, variant = Variant.roll(rng) }
	Inventory.add(data, result.cardId, result.tier, result.variant, 1)

	if Inventory.count(data, req.cardId, req.tier) == 0 then
		for _, slot in data.deck do
			if slot.cardId == req.cardId and slot.tier == req.tier then
				slot.tier = nextTier
			end
		end
	end

	return true, result
end

export type Offer = {
	nextTier: string,
	needed: number, -- copies a fusion spends
	have: number, -- copies at this tier, all variants
	fee: number,
	enough: boolean, -- copies
	affordable: boolean,
	spendsVariants: boolean, -- there aren't enough Base copies, so variants would go too
}

-- What fusing this card and tier would take, for the button that offers it, or nil at the top tier.
-- Catalysts aren't offered: nothing gives them yet.
function Fusion.offer(stacks: { [string]: number }, credits: number, cardId: string, tier: string): Offer?
	local nextTier = Tier.next(tier)
	if not nextTier or not Cards.isValid(cardId) then
		return nil
	end
	local data = { stacks = stacks }
	local needed = Config.CopiesToFuse
	local fee = Config.FusionFee[tier]
	local have = Inventory.count(data, cardId, tier)
	return {
		nextTier = nextTier,
		needed = needed,
		have = have,
		fee = fee,
		enough = have >= needed,
		affordable = credits >= fee,
		spendsVariants = Inventory.count(data, cardId, tier, Variant.Base) < needed,
	}
end

return Fusion
