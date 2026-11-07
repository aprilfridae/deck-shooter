-- Turns a player's card stacks into what the Loadout and Profile pages show.
local Cards = require("./Cards")
local Deck = require("./Deck")
local Inventory = require("./Inventory")
local Tier = require("./Tier")
local Variant = require("./Variant")

local CardIndex = {}

local function namedIds(): { string }
	local ids = table.clone(Cards.ids)
	table.sort(ids, function(a, b)
		return Cards.byId[a].name < Cards.byId[b].name
	end)
	return ids
end

-- The rarest variant owned of this card and tier, which is the one the menus show.
function CardIndex.variant(stacks: { [string]: number }, cardId: string, tier: string): string
	local data = { stacks = stacks }
	for index = #Variant.order, 1, -1 do
		local variant = Variant.order[index]
		if Inventory.count(data, cardId, tier, variant) > 0 then
			return variant
		end
	end
	return Variant.Base
end

-- Every card at every tier, with the copies owned of each.
function CardIndex.build(stacks: { [string]: number }): any
	local data = { stacks = stacks }
	local index = { cards = {}, owned = 0, total = 0 }
	for _, cardId in namedIds() do
		local card = { cardId = cardId, name = Cards.byId[cardId].name, tiers = {} }
		for _, tier in Tier.order do
			local count = Inventory.count(data, cardId, tier)
			table.insert(card.tiers, { tier = tier, count = count, variant = CardIndex.variant(stacks, cardId, tier) })
			index.total += 1
			if count > 0 then
				index.owned += 1
			end
		end
		table.insert(index.cards, card)
	end
	return index
end

-- Whether a card can go in this deck slot: Open, Equipped, InDeck or Unowned.
function CardIndex.choice(deck: { any }, slot: number, cardId: string, tier: string, count: number): string
	if count == 0 then
		return "Unowned"
	elseif deck[slot].cardId == cardId and deck[slot].tier == tier then
		return "Equipped"
	end
	return if Deck.swap(deck, slot, cardId, tier) then "Open" else "InDeck"
end

return CardIndex
