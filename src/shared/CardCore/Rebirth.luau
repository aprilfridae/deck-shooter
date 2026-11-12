-- A rebirth trades all of a player's Credits for more luck. Cards, decks and packs are kept.
local Config = require("./Config")

local Rebirth = {}

-- The price of the next rebirth, for a player who has done this many.
function Rebirth.price(rebirths: number): number
	return math.round(Config.RebirthPrice * Config.RebirthGrowth ^ rebirths)
end

function Rebirth.perform(data: any): (boolean, string?)
	if data.credits < Rebirth.price(data.rebirths) then
		return false, "NotEnoughCredits"
	elseif data.market and next(data.market.bids) then
		-- A rebirth trades all your Credits for luck. Credits set aside in a bid would dodge that and come back
		-- afterwards (docs/specs/auction-house.md).
		return false, "BidsOpen"
	end
	data.credits = 0
	data.creditRemainder = 0
	data.rebirths += 1
	return true, nil
end

return Rebirth
