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

return Fusion
