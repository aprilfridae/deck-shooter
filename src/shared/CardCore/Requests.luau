-- Turns untrusted client input into clean requests. Anything invalid becomes nil.
local Cards = require("./Cards")
local Config = require("./Config")
local Deck = require("./Deck")
local Tier = require("./Tier")

local Requests = {}

function Requests.parseFuse(raw: any): any
	if type(raw) ~= "table" or not Cards.isValid(raw.cardId) or not Tier.isValid(raw.tier) then
		return nil
	end
	return {
		cardId = raw.cardId,
		tier = raw.tier,
		useCatalyst = raw.useCatalyst == true,
		includeVariants = raw.includeVariants == true,
	}
end

function Requests.parseLoadout(raw: any): any
	if type(raw) ~= "table" or type(raw.class) ~= "string" or type(raw.rifle) ~= "string" then
		return nil
	end
	if not Config.Classes[raw.class] or not Config.Rifles[raw.rifle] then
		return nil
	end
	return { class = raw.class, rifle = raw.rifle }
end

function Requests.parseDeck(raw: any): { any }?
	if type(raw) ~= "table" then
		return nil
	end
	local size = 0
	for key in raw do
		if type(key) ~= "number" then
			return nil
		end
		size += 1
	end
	if size ~= Deck.SIZE then
		return nil
	end

	local slots = {}
	for i = 1, Deck.SIZE do
		local slot = raw[i]
		if type(slot) ~= "table" or not Cards.isValid(slot.cardId) or not Tier.isValid(slot.tier) then
			return nil
		end
		slots[i] = { cardId = slot.cardId, tier = slot.tier }
	end
	return slots
end

return Requests
