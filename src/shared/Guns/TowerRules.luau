-- The rules of a Tower match (docs/specs/matches.md), with no Roblox in them, so they can be tested. Teams are 1
-- and 2. The arenas are numbered 1 to 7 in a line: team 1's home is arena 1 and team 2's is arena 7, and a match
-- starts in arena 4. A round won moves the next one an arena toward the loser's home; winning a round in the
-- other team's home arena (capturing its tower) wins the match. At 7-7 one deciding round is played in a separate
-- tiebreaker arena.
--
-- Not decided by the spec, chosen here (starting values, tune by feel):
--   - When both teams are wiped on the same check, the tower's owner wins.
--   - The 14 seconds a wiping team gets to capture run on past the round clock, so a late wipe still gets its try.
--   - The tiebreaker round lasts 60 seconds, like a home arena.

local TowerRules = {}

TowerRules.ARENAS = 7
TowerRules.START_ARENA = 4
TowerRules.TIEBREAKER = 0 -- the tiebreaker arena's number; it isn't in the line
TowerRules.ROUND_SECONDS = 40
TowerRules.HOME_ROUND_SECONDS = 60
TowerRules.TIEBREAKER_SECONDS = 60
TowerRules.CAPTURE_RANGE = 6 -- studs from the tower a living player can capture it from
TowerRules.WIPE_CAPTURE_SECONDS = 14
TowerRules.MAX_ROUNDS = 15
TowerRules.TIE_AT = 7 -- round wins each that send the match to the tiebreaker

export type State = {
	arena: number, -- 1 to 7, or TIEBREAKER
	wins: { number },
	rounds: number,
	attacker: number, -- the team attacking this round; the other defends and owns the tower at the start
	winner: number?, -- set once the match is over
}

local function other(team: number): number
	return if team == 1 then 2 else 1
end

-- Each team's home arena.
function TowerRules.home(team: number): number
	return if team == 1 then 1 else TowerRules.ARENAS
end

-- A new match. coin is the random first attacker (1 or 2).
function TowerRules.new(coin: number): State
	return { arena = TowerRules.START_ARENA, wins = { 0, 0 }, rounds = 0, attacker = coin }
end

-- The team that owns the tower when a round starts.
function TowerRules.defender(state: State): number
	return other(state.attacker)
end

function TowerRules.roundSeconds(state: State): number
	if state.arena == TowerRules.TIEBREAKER then
		return TowerRules.TIEBREAKER_SECONDS
	elseif state.arena == TowerRules.home(1) or state.arena == TowerRules.home(2) then
		return TowerRules.HOME_ROUND_SECONDS
	end
	return TowerRules.ROUND_SECONDS
end

-- Whether a player of this team can capture the tower now: alive, close enough, and the tower isn't theirs.
function TowerRules.canCapture(team: number, owner: number, alive: boolean, distance: number): boolean
	return alive and team ~= owner and distance <= TowerRules.CAPTURE_RANGE
end

-- Who has won the round, or nil while it goes on.
--   owner: who owns the tower now.
--   alive: players alive on each team.
--   timeUp: the round clock has run out.
--   windowOver: a team that wiped the owner has had its WIPE_CAPTURE_SECONDS and not captured.
-- The owner wins when time runs out or when it wipes the other team. A team that wipes the owner must capture in
-- the window; once it does it is the owner and the other team is already wiped, so it wins at once.
function TowerRules.roundResult(owner: number, alive: { number }, timeUp: boolean, windowOver: boolean): number?
	if alive[other(owner)] <= 0 then
		return owner -- the owner has wiped the others, or both went together
	elseif alive[owner] <= 0 then
		return if windowOver then owner else nil -- the others are trying to capture
	elseif timeUp then
		return owner
	end
	return nil
end

-- Whether the capture window is open: the owner is wiped and the others are still up.
function TowerRules.capturing(owner: number, alive: { number }): boolean
	return alive[owner] <= 0 and alive[other(owner)] > 0
end

-- Scores a round and sets up the next. Returns the match winner once there is one. coin is a random team (1 or 2)
-- for the tiebreaker's roles.
function TowerRules.finishRound(state: State, winner: number, coin: number): number?
	local loser = other(winner)
	local played = state.arena
	state.wins[winner] += 1
	state.rounds += 1
	if played == TowerRules.home(loser) or played == TowerRules.TIEBREAKER then
		state.winner = winner -- took the tower in the other team's home, or won the decider
	elseif state.rounds >= TowerRules.MAX_ROUNDS then
		state.winner = if state.wins[1] > state.wins[2] then 1 elseif state.wins[2] > state.wins[1] then 2 else winner
	end
	if state.winner then
		return state.winner
	end
	if state.wins[1] == TowerRules.TIE_AT and state.wins[2] == TowerRules.TIE_AT then
		state.arena = TowerRules.TIEBREAKER
		state.attacker = coin
	else
		state.arena += if loser == 2 then 1 else -1 -- toward the loser's home
		state.attacker = winner -- the last round's winner attacks
	end
	return nil
end

return TowerRules
