-- Turns a player's card stacks into what the Loadout and Profile pages show.
local Cards = require("./Cards")
local Inventory = require("./Inventory")
local Tier = require("./Tier")

local CardIndex = {}

local function namedIds(): { string }
	local ids = table.clone(Cards.ids)
	table.sort(ids, function(a, b)
		return Cards.byId[a].name < Cards.byId[b].name
	end)
	return ids
end

-- Every card at every tier, with the copies owned of each.
function CardIndex.build(stacks: { [string]: number }): any
	local data = { stacks = stacks }
	local index = { cards = {}, owned = 0, total = 0 }
	for _, cardId in namedIds() do
		local card = { cardId = cardId, name = Cards.byId[cardId].name, tiers = {} }
		for _, tier in Tier.order do
			local count = Inventory.count(data, cardId, tier)
			table.insert(card.tiers, { tier = tier, count = count })
			index.total += 1
			if count > 0 then
				index.owned += 1
			end
		end
		table.insert(index.cards, card)
	end
	return index
end

-- Each card and tier the player owns, for choosing a deck.
function CardIndex.owned(stacks: { [string]: number }): { any }
	local owned = {}
	for _, card in CardIndex.build(stacks).cards do
		for _, entry in card.tiers do
			if entry.count > 0 then
				table.insert(owned, { cardId = card.cardId, name = card.name, tier = entry.tier, count = entry.count })
			end
		end
	end
	return owned
end

return CardIndex
