-- The saved player record.
local Config = require("./Config")
local Inventory = require("./Inventory")

export type DeckSlot = { cardId: string, tier: string }
export type SaveData = {
	version: number,
	credits: number,
	creditRemainder: number,
	stacks: { [string]: number },
	deck: { DeckSlot },
	gunLevels: { number },
	catalysts: number,
}

local SaveData = {
	CURRENT_VERSION = 1,
}

function SaveData.new(): SaveData
	local data: SaveData = {
		version = SaveData.CURRENT_VERSION,
		credits = 0,
		creditRemainder = 0,
		stacks = {},
		deck = {},
		gunLevels = { 0, 0 },
		catalysts = 0,
	}
	for _, cardId in Config.StarterDeck do
		Inventory.add(data, cardId, "Field", "Base", 1)
		table.insert(data.deck, { cardId = cardId, tier = "Field" })
	end
	return data
end

return SaveData
