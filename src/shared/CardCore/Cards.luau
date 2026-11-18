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
		-- The second wave (2026-11-17). None of them does damage.
		-- A card flicked spinning across the room that bursts in a white flash where it lands. Enemies who can see
		-- the burst are blinded for up to `blind` seconds, less the further off they are and the more they had
		-- their back to it.
		flashpoint = {
			id = "flashpoint",
			name = "Flashpoint",
			category = "debuff",
			set = "set_01",
			stats = { blind = { 1.4, 2, 2.6 }, cooldown = { 20, 17, 14 } },
			lowerIsBetter = { cooldown = true },
		},
		-- The card slapped down on the ground ahead stands up as a giant card: cover that stops bullets, cards and
		-- bodies until it is shot down or runs out.
		bulwark = {
			id = "bulwark",
			name = "Bulwark",
			category = "defense",
			set = "set_01",
			cooldown = 24,
			stats = { wallHp = { 150, 225, 300 }, duration = { 6, 8, 10 } },
		},
		-- A copy of you that sprints off the way you look, holding your gun. It can be shot, and glitches away
		-- when it is shot down or its time is up.
		split = {
			id = "split",
			name = "Split",
			category = "deception",
			set = "set_01",
			stats = { duration = { 3, 4.5, 6 }, cooldown = { 22, 19, 15 } },
			lowerIsBetter = { cooldown = true },
		},
		-- Snaps you back to where you were a few seconds ago, and gives back health lost since, up to `heal`.
		rewind = {
			id = "rewind",
			name = "Rewind",
			category = "mobility",
			set = "set_01",
			stats = { heal = { 20, 30, 40 }, cooldown = { 24, 20, 16 } },
			lowerIsBetter = { cooldown = true },
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
