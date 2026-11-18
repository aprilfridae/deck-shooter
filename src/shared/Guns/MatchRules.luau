-- The rules of a match, with no Roblox in them, so they can be tested (docs/specs/matches.md).
-- Teams are numbered 1 and 2. A side is what the server knows about a team at a moment: how many of its players
-- are alive, their total health, and how many are still in the match at all.

export type Side = { alive: number, health: number, present: number }
export type ModeRules = {
	winsNeeded: number, -- round wins that take the match
	roundSeconds: number, -- the longest a round lasts
	betweenSeconds: number, -- the break between rounds, to change class or rifle
	countdownSeconds: number, -- frozen at the spawns before each round
	maxRounds: number, -- scored rounds at most (a replayed tie doesn't count)
}

local MatchRules = {}

MatchRules.Elimination = {
	winsNeeded = 5,
	roundSeconds = 90,
	betweenSeconds = 8,
	countdownSeconds = 3,
	maxRounds = 9,
} :: ModeRules

-- Team sizes each queue fills. The other combinations are settings for later.
MatchRules.QUEUES = {
	{ id = "Elimination1", mode = "Elimination", size = 1 },
	{ id = "Elimination2", mode = "Elimination", size = 2 },
	{ id = "Elimination3", mode = "Elimination", size = 3 },
}

function MatchRules.queue(id: any): { id: string, mode: string, size: number }?
	for _, queue in MatchRules.QUEUES do
		if queue.id == id then
			return queue
		end
	end
	return nil
end

-- Who has won the round, if anyone yet.
--   "Playing": nobody yet.
--   1 or 2: that team wins.
--   "Replay": an exact tie, replayed without a score.
-- A wipe ends it at once; both wiped on the same check is a tie. At the time limit, more alive wins, then more
-- total health.
function MatchRules.roundResult(a: Side, b: Side, timeUp: boolean): number | string
	local aOut, bOut = a.alive <= 0, b.alive <= 0
	if aOut and bOut then
		return "Replay"
	elseif bOut then
		return 1
	elseif aOut then
		return 2
	elseif not timeUp then
		return "Playing"
	elseif a.alive ~= b.alive then
		return if a.alive > b.alive then 1 else 2
	elseif a.health ~= b.health then
		return if a.health > b.health then 1 else 2
	end
	return "Replay"
end

-- A team with nobody left in the match forfeits it. Returns the winner, or nil while both teams have someone.
function MatchRules.forfeit(a: Side, b: Side): number?
	if a.present <= 0 and b.present <= 0 then
		return nil -- nobody to give it to; the server just ends the match
	elseif a.present <= 0 then
		return 2
	elseif b.present <= 0 then
		return 1
	end
	return nil
end

-- The match winner once one team has enough round wins, or after the round limit the one with more.
function MatchRules.matchWinner(rules: ModeRules, wins: { number }, scored: number): number?
	if wins[1] >= rules.winsNeeded then
		return 1
	elseif wins[2] >= rules.winsNeeded then
		return 2
	elseif scored >= rules.maxRounds and wins[1] ~= wins[2] then
		return if wins[1] > wins[2] then 1 else 2
	end
	return nil
end

-- Catalysts each winner gets for a match. Only a match won on rounds pays: a forfeit could be farmed by a friend
-- leaving at once, and a Studio test against stand-ins isn't a match.
MatchRules.CATALYSTS_PER_WIN = 1
function MatchRules.catalystsFor(rules: ModeRules, wins: { number }, winner: number?, withStandIns: boolean): number
	if not winner or winner == 0 or withStandIns or wins[winner] < rules.winsNeeded then
		return 0
	end
	return MatchRules.CATALYSTS_PER_WIN
end

-- Splits queued players into two teams of `size`, first come first served, alternating so friends who joined
-- together aren't all stacked on one side. Returns nil until there are enough.
function MatchRules.split<T>(waiting: { T }, size: number): ({ T }?, { T }?)
	if #waiting < size * 2 then
		return nil
	end
	local one, two = {}, {}
	for index = 1, size * 2 do
		table.insert(if index % 2 == 1 then one else two, waiting[index])
	end
	return one, two
end

return MatchRules
