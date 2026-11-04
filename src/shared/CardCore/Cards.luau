-- Card definitions. Stats are listed Field, Black-Site, Prototype.
local Config = require("./Config")
local Tier = require("./Tier")

local Cards = {
	byId = {
		phase_dash = {
			id = "phase_dash",
			name = "Phase Dash",
			category = "mobility",
			set = "set_01",
			stats = { distance = { 13, 14.5, 16 }, cooldown = { 12, 11, 10 } },
			perk = "camo_after_dash",
			lowerIsBetter = { cooldown = true },
		},
		overclock = {
			id = "overclock",
			name = "Overclock",
			category = "weapon_buff",
			set = "set_01",
			cooldown = 25,
			stats = { fireRateBonus = { 0.15, 0.17, 0.18 }, duration = { 5, 5.5, 6 } },
		},
		recon_pulse = {
			id = "recon_pulse",
			name = "Recon Pulse",
			category = "intel",
			set = "set_01",
			cooldown = 20,
			stats = { radius = { 40, 45, 50 }, revealTime = { 2, 2.3, 2.5 } },
			perk = "team_sees_marks",
		},
		aegis_shell = {
			id = "aegis_shell",
			name = "Aegis Shell",
			category = "defense",
			set = "set_01",
			cooldown = 25,
			stats = { shieldHp = { 52, 58, 64 }, duration = { 3, 3.5, 3.75 } },
			perk = "break_knockback",
		},
		arc_mine = {
			id = "arc_mine",
			name = "Arc Mine",
			category = "area_denial",
			set = "set_01",
			cooldown = 30,
			stats = { damage = { 60, 68, 75 }, slowPct = { 0.25, 0.28, 0.30 }, slowSeconds = { 1.5, 1.5, 1.875 } },
			perk = "hidden_until_triggered",
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
