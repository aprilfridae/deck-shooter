-- Deck Power Rating. Uses card tiers and gun levels only, never skill or win rate.
local Config = require("./Config")

local Dpr = {}

function Dpr.compute(deck: { any }, gunLevels: { number }): number
	local total = 0
	for _, slot in deck do
		total += Config.TierPower[slot.tier]
	end
	for _, level in gunLevels do
		total += Config.GunPointsPerLevel * level
	end
	return total
end

return Dpr
