-- Card definitions. Stats are listed Field, Redline, Prototype.
-- A Prototype card is about twice a Field one (River, 2026-11-11: "higher rarity = better"); tests/cards_spec
-- holds every stat to between 1.4 and 2 times. Phase Dash was already strong at Prototype, so its lower tiers
-- were made worse instead. Recon Pulse was removed the same day: saves keep its copies, which do nothing.
local Config = require("./Config")
local Tier = require("./Tier")

local Cards = {
	byId = {
		phase_dash = {
			id = "phase_dash",
			name = "Phase Dash",
			category = "mobility",
			set = "set_01",
			stats = { distance = { 8, 12, 16 }, cooldown = { 16, 13, 10 } },
			perk = "camo_after_dash",
			lowerIsBetter = { cooldown = true },
		},
		overclock = {
			id = "overclock",
			name = "Overclock",
			category = "weapon_buff",
			set = "set_01",
			cooldown = 25,
			stats = { fireRateBonus = { 0.15, 0.22, 0.3 }, duration = { 5, 7, 9 } },
		},
		aegis_shell = {
			id = "aegis_shell",
			name = "Aegis Shell",
			category = "defense",
			set = "set_01",
			cooldown = 25,
			stats = { shieldHp = { 52, 78, 104 }, duration = { 3, 4, 5 } },
			perk = "end_knockback",
		},
		-- A tether that swaps your place with the enemy you aim at.
		switchback = {
			id = "switchback",
			name = "Switchback",
			category = "mobility",
			set = "set_01",
			stats = { range = { 40, 60, 80 }, cooldown = { 20, 16, 12 } },
			lowerIsBetter = { cooldown = true },
		},
		-- A blast on the ground you aim at, which throws you away from it. height is how far up it carries you
		-- when it goes off under your feet.
		kickplate = {
			id = "kickplate",
			name = "Kickplate",
			category = "mobility",
			set = "set_01",
			stats = { height = { 24, 36, 48 }, cooldown = { 14, 12, 10 } },
			lowerIsBetter = { cooldown = true },
		},
		-- A bolt that takes speed from the enemy it hits and gives it to you.
		siphon = {
			id = "siphon",
			name = "Siphon",
			category = "debuff",
			set = "set_01",
			cooldown = 18,
			stats = { speedSteal = { 0.15, 0.22, 0.3 }, duration = { 3, 4.5, 6 } },
		},
	} :: { [string]: any },
	ids = {} :: { string },
	sets = {} :: { [string]: { string } },
}

for id, card in Cards.byId do
	table.insert(Cards.ids, id)
	Cards.sets[card.set] = Cards.sets[card.set] or {}
	table.insert(Cards.sets[card.set], id)
end
table.sort(Cards.ids)
for _, ids in Cards.sets do
	table.sort(ids)
end

function Cards.isValid(id: any): boolean
	return type(id) == "string" and Cards.byId[id] ~= nil
end

function Cards.stat(id: string, tier: string, stat: string): number
	return Cards.byId[id].stats[stat][Tier.index(tier) :: number]
end

-- Most cards have one cooldown. A card with a cooldown stat changes it by tier.
function Cards.cooldown(id: string, tier: string): number
	local card = Cards.byId[id]
	return card.cooldown or Cards.stat(id, tier, "cooldown")
end

function Cards.perkScale(tier: string): number
	return Config.PerkPower[tier]
end

return Cards
