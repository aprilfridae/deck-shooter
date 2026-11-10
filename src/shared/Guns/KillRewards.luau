--!strict
-- What a kill pays, and the lines the killer sees for it. Pure rules: the server works out what happened in a shot
-- and asks here what it's worth. See docs/specs/kill-rewards.md.
local KillRewards = {}

-- Starting numbers, to tune. Credits.
local KILL = 500
local HEADSHOT = 100
local ONE_SHOT = 100
local LONG_SHOT = 150
local COLLATERAL = 250
local LONG_SHOT_FROM = 150 -- studs
local TRADE_GAP = 20 -- seconds before the same victim pays the same killer again
-- Kills without dying, and what reaching each pays.
local STREAKS = {
	{ kills = 3, id = "spree", name = "KILLING SPREE", amount = 200 },
	{ kills = 5, id = "rampage", name = "RAMPAGE", amount = 400 },
	{ kills = 10, id = "unstoppable", name = "UNSTOPPABLE", amount = 1000 },
}

-- One target killed by a shot.
export type Kill = {
	victim: any, -- who it was: the same value every time for the same player or bot
	pays: boolean, -- players and bots pay; the test dummy doesn't
	head: boolean, -- the killing bullet hit the head
	fullHealth: boolean, -- it was at full health before the shot
	bullets: number, -- how many bullets of the shot hit it
	distance: number, -- studs from the shooter
}
-- A line of the pop-up. amount is nil when the kill didn't pay.
export type Line = { id: string, name: string, amount: number? }
-- What the server remembers about a killer while they're in the game.
export type Record = { streak: number, paidAt: { [any]: number } }

function KillRewards.newRecord(): Record
	return { streak = 0, paidAt = {} }
end

-- The killer died (or left): the streak starts again.
function KillRewards.died(record: Record)
	record.streak = 0
end

-- The lines for one shot's kills, in the order they're shown, and the Credits they add up to. Updates the record.
function KillRewards.forShot(kills: { Kill }, collateral: boolean, record: Record, now: number): ({ Line }, number)
	local lines: { Line } = {}
	local total = 0
	local anyPaid = false
	local function add(id: string, name: string, amount: number, paid: boolean)
		table.insert(lines, { id = id, name = name, amount = if paid then amount else nil })
		if paid then
			total += amount
		end
	end
	for _, kill in kills do
		-- The same victim pays the same killer only once in a while, so two players can't trade kills for Credits.
		local last = record.paidAt[kill.victim]
		local paid = kill.pays and (last == nil or now - last >= TRADE_GAP)
		if paid then
			record.paidAt[kill.victim] = now
			anyPaid = true
		end
		add("kill", "KILL", KILL, paid)
		if kill.head then
			add("headshot", "HEADSHOT", HEADSHOT, paid)
		end
		if kill.fullHealth and kill.bullets == 1 then
			add("oneShot", "ONE SHOT ONE KILL", ONE_SHOT, paid)
		end
		if kill.distance >= LONG_SHOT_FROM then
			add("longShot", "LONG SHOT", LONG_SHOT, paid)
		end
		if paid then
			-- Only kills that pay count toward a streak.
			record.streak += 1
			for _, streak in STREAKS do
				if record.streak == streak.kills then
					add(streak.id, streak.name, streak.amount, true)
				end
			end
		end
	end
	if collateral and #kills >= 2 then
		add("collateral", "COLLATERAL", COLLATERAL, anyPaid)
	end
	return lines, total
end

KillRewards.KILL = KILL
KillRewards.HEADSHOT = HEADSHOT
KillRewards.ONE_SHOT = ONE_SHOT
KillRewards.LONG_SHOT = LONG_SHOT
KillRewards.COLLATERAL = COLLATERAL
KillRewards.LONG_SHOT_FROM = LONG_SHOT_FROM
KillRewards.TRADE_GAP = TRADE_GAP
KillRewards.STREAKS = STREAKS

return KillRewards
