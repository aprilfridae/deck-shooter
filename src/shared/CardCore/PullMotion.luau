-- The timing and layout of the pull reveal.
local Inventory = require("./Inventory")
local Tier = require("./Tier")
local Variant = require("./Variant")

local PullMotion = {
	ARRIVE_TIME = 0.7, -- seconds
	RIP_TIME = 0.6,
	RISE_TIME = 0.45,
	SPREAD_TIME = 0.35,
	TURN_TIME = 0.35,
	FLIP_TIME = 0.28,
	QUICK_ROW = 0.05, -- seconds between rows of a quick list
	RARE_QUEUE = 3, -- Auto Open pulls that can wait to be shown
}

local TIER_BUILD = { Field = 0.2, BlackSite = 0.5, Prototype = 0.9 }
local VARIANT_BUILD = { Base = 0, Chromatic = 0.3, Redacted = 0.6 }
local ZERO_DAY_BUILD = 2
local FAN_STEP = 1.06 -- card widths
local FAN_TILT = 3 -- degrees
local PEEL_SPAN = 0.4 -- of the rip each strip piece takes
local TIER_FLASH = { Field = 0, BlackSite = 0.25, Prototype = 0.35 }
local VARIANT_FLASH = { Base = 0, Chromatic = 0.1, Redacted = 0.15 }
local ZERO_DAY_FLASH = 0.7

local function rank(entry: any): number
	return table.find(Variant.order, entry.variant) * 10 + table.find(Tier.order, entry.tier)
end

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

-- When each step of the opening starts, in seconds from the pack appearing.
function PullMotion.phases(cards: { any }): any
	local wait = 0
	for _, card in cards do
		wait = math.max(wait, PullMotion.buildTime(card))
	end
	local rip = PullMotion.ARRIVE_TIME
	local rise = rip + PullMotion.RIP_TIME
	local spread = rise + PullMotion.RISE_TIME
	local build = spread + PullMotion.SPREAD_TIME
	local flip = build + wait
	return { rip = rip, rise = rise, spread = spread, build = build, flip = flip, rest = flip + PullMotion.TURN_TIME }
end

-- How far one piece of the strip has peeled, from 0 to 1, when the rip is this far along.
function PullMotion.peel(progress: number, index: number, count: number): number
	local start = (index - 1) / count * (1 - PEEL_SPAN)
	return math.clamp((progress - start) / PEEL_SPAN, 0, 1)
end

function PullMotion.best(cards: { any }): any
	local best = cards[1]
	for _, card in cards do
		if rank(card) > rank(best) then
			best = card
		end
	end
	return best
end

-- The cards left to right, with the best in the middle of a full pack.
function PullMotion.fanOrder(cards: { any }): { any }
	local order = table.clone(cards)
	table.sort(order, function(a: any, b: any): boolean
		return rank(a) < rank(b)
	end)
	if #order == 3 then
		order[2], order[3] = order[3], order[2]
	end
	return order
end

-- How strong the flash is when this card turns over, from 0 to 1.
function PullMotion.flash(card: any): number
	if card.variant == Variant.ZeroDay then
		return ZERO_DAY_FLASH
	end
	return TIER_FLASH[card.tier] + VARIANT_FLASH[card.variant]
end

-- Where card 1, 2 or 3 sits: its distance from the middle, in card widths, and its tilt.
function PullMotion.fan(index: number): (number, number)
	local steps = index - 2
	return steps * FAN_STEP, steps * FAN_TILT
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
