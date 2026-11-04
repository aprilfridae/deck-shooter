-- Rules for using equipped cards. Pure: the caller supplies the time.
local Cards = require("./Cards")
local Config = require("./Config")
local Deck = require("./Deck")

export type Slot = { cardId: string, tier: string, readyAt: number }

local Ability = {}

function Ability.new(deck: { any }?): { Slot }
	local slots = {}
	for i, equipped in deck or {} do
		slots[i] = { cardId = equipped.cardId, tier = equipped.tier, readyAt = -math.huge }
	end
	return slots
end

-- Turns an untrusted slot from a client into a real one, or nil.
function Ability.parseSlot(raw: any): number?
	if type(raw) ~= "number" or raw ~= raw or raw < 1 or raw > Deck.SIZE or math.floor(raw) ~= raw then
		return nil
	end
	return raw
end

function Ability.ready(slots: { Slot }, index: number, now: number): Slot?
	local slot = slots[index]
	return if slot and now >= slot.readyAt then slot else nil
end

function Ability.spend(slot: Slot, now: number)
	slot.readyAt = now + Cards.cooldown(slot.cardId, slot.tier)
end

function Ability.camoSeconds(tier: string): number
	return Config.DashCamoSeconds * Cards.perkScale(tier)
end

function Ability.teamRevealSeconds(tier: string): number
	return Cards.stat("recon_pulse", tier, "revealTime") * Cards.perkScale(tier)
end

function Ability.pushSpeed(tier: string): number
	return Config.PushSpeed * Cards.perkScale(tier)
end

return Ability
