-- The timing and layout of the pull reveal.
local Inventory = require("./Inventory")
local Tier = require("./Tier")
local Variant = require("./Variant")

local PullMotion = {
	TEAR_TIME = 0.5, -- seconds
	FLIP_TIME = 0.28,
	QUICK_ROW = 0.05, -- seconds between rows of a quick list
	RARE_QUEUE = 3, -- Auto Open pulls that can wait to be shown
}

local TIER_BUILD = { Field = 0.2, BlackSite = 0.5, Prototype = 0.9 }
local VARIANT_BUILD = { Base = 0, Chromatic = 0.3, Redacted = 0.6 }
local ZERO_DAY_BUILD = 2
local FAN_STEP = 0.15 -- of the unit
local FAN_TILT = 6 -- degrees

-- Seconds a face-down card shakes before turning. A longer shake means a better card.
function PullMotion.buildTime(card: any): number
	if card.variant == Variant.ZeroDay then
		return ZERO_DAY_BUILD
	end
	return TIER_BUILD[card.tier] + VARIANT_BUILD[card.variant]
end

-- Auto Open can pull rares faster than they can be shown, so only a few wait. Never a Zero-Day.
function PullMotion.keepsRare(waiting: number, card: any): boolean
	return waiting < PullMotion.RARE_QUEUE or card.variant == Variant.ZeroDay
end

-- Where card 1, 2 or 3 sits: its distance from the middle and its tilt.
function PullMotion.fan(index: number): (number, number)
	local steps = index - 2
	return steps * FAN_STEP, steps * FAN_TILT
end

local function rank(entry: any): number
	return table.find(Variant.order, entry.variant) * 10 + table.find(Tier.order, entry.tier)
end

-- A pile's stack counts as a list, rarest first.
function PullMotion.quickList(cards: { [string]: number }): { any }
	local list = {}
	for key, count in cards do
		local cardId, tier, variant = Inventory.parse(key)
		table.insert(list, { cardId = cardId, tier = tier, variant = variant, count = count })
	end
	table.sort(list, function(a: any, b: any): boolean
		local rankA, rankB = rank(a), rank(b)
		if rankA ~= rankB then
			return rankA > rankB
		end
		return a.count > b.count
	end)
	return list
end

return PullMotion
