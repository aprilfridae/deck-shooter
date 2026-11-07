-- The player's 3 equipped cards.
local Cards = require("./Cards")
local Inventory = require("./Inventory")
local Tier = require("./Tier")

local Deck = {
	SIZE = 3,
}

function Deck.check(data: any, slots: { any }): (boolean, string?)
	if #slots ~= Deck.SIZE then
		return false, "WrongSize"
	end
	local seen = {}
	for _, slot in slots do
		if not Cards.isValid(slot.cardId) then
			return false, "UnknownCard"
		elseif not Tier.isValid(slot.tier) then
			return false, "InvalidTier"
		elseif seen[slot.cardId] then
			return false, "DuplicateCard"
		elseif Inventory.count(data, slot.cardId, slot.tier) == 0 then
			return false, "NotOwned"
		end
		seen[slot.cardId] = true
	end
	return true, nil
end

-- A copy of the deck with one slot changed, or nil if that card is already in another slot.
function Deck.swap(deck: { any }, slot: number, cardId: string, tier: string): { any }?
	local swapped = {}
	for index, entry in deck do
		if index ~= slot and entry.cardId == cardId then
			return nil
		end
		swapped[index] = { cardId = entry.cardId, tier = entry.tier }
	end
	swapped[slot] = { cardId = cardId, tier = tier }
	return swapped
end

function Deck.set(data: any, slots: { any }): (boolean, string?)
	local ok, code = Deck.check(data, slots)
	if not ok then
		return false, code
	end
	local deck = {}
	for i, slot in slots do
		deck[i] = { cardId = slot.cardId, tier = slot.tier }
	end
	data.deck = deck
	return true, nil
end

return Deck
