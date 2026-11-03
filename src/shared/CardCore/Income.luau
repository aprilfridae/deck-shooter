-- Collection income. Pays only while the server ticks it, so nothing accrues offline.
local Cards = require("./Cards")
local Config = require("./Config")
local Inventory = require("./Inventory")
local Variant = require("./Variant")

local Income = {}

local function cardRate(data: any, cardId: string, tier: string): number
	local base = Config.IncomePerSecond[tier]
	local capLeft = Config.SoftCapCopies
	local total = 0
	-- Rarest first: VariantIncome rises along Variant.order, so the
	-- best-paying copies take the full-rate slots.
	for i = #Variant.order, 1, -1 do
		local variant = Variant.order[i]
		local copies = Inventory.count(data, cardId, tier, variant)
		local full = math.min(copies, capLeft)
		local rate = base * Config.VariantIncome[variant]
		total += rate * full + rate * Config.SoftCapRate * (copies - full)
		capLeft -= full
	end
	return total
end

function Income.ratePerSecond(data: any, boost: number?): number
	local total = 0
	for _, cardId in Cards.ids do
		for tier in Config.IncomePerSecond do
			total += cardRate(data, cardId, tier)
		end
	end

	local bonus = 1
	for _, ids in Cards.sets do
		local complete = true
		for _, cardId in ids do
			complete = complete and Inventory.ownsCard(data, cardId)
		end
		if complete then
			bonus += Config.SetBonus
		end
	end

	return total * bonus * (boost or 1)
end

function Income.accrue(data: any, dt: number, boost: number?)
	if not (dt > 0) then -- also catches NaN
		return
	end
	local seconds = math.min(dt, Config.MaxTickSeconds)
	local earned = data.creditRemainder + Income.ratePerSecond(data, boost) * seconds
	local whole = math.floor(earned)
	data.credits += whole
	data.creditRemainder = earned - whole
end

return Income
