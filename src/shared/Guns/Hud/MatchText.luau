-- The words the match HUD shows (MatchHud.client.luau), worked out from the match's state so they can be tested.
-- The fonts have no commas or apostrophes.
local MatchText = {}

-- Seconds left as M:SS, never below 0:00.
function MatchText.clock(seconds: number): string
	local whole = math.max(math.ceil(seconds), 0)
	return string.format("%d:%02d", whole // 60, whole % 60)
end

export type State = {
	phase: string?, -- Countdown, Playing, Between, Over
	round: number,
	roundWinner: number?, -- 0 for a tie that's replayed
	winner: number?, -- 0 when the match ended with nobody left
	mine: number, -- the player's team
	left: number, -- seconds left in the phase
}

-- The big word in the middle of the screen, or "" for none.
function MatchText.banner(state: State): string
	local phase = state.phase
	if phase == "Countdown" then
		return if state.left > 0.5 then tostring(math.ceil(state.left - 0.5)) else "FIGHT"
	elseif phase == "Between" then
		if state.roundWinner == 0 then
			return "TIE"
		end
		return if state.roundWinner == state.mine then "ROUND WON" else "ROUND LOST"
	elseif phase == "Over" then
		if state.winner == nil or state.winner == 0 then
			return "MATCH OVER"
		end
		return if state.winner == state.mine then "VICTORY" else "DEFEAT"
	end
	return ""
end

-- The small line under the score.
function MatchText.line(state: State): string
	local phase = state.phase
	if phase == "Countdown" or phase == "Playing" then
		return `ROUND {state.round}`
	elseif phase == "Between" then
		return if state.roundWinner == 0 then "NOBODY SCORES. THE ROUND IS REPLAYED" else "NEXT ROUND SOON"
	elseif phase == "Over" then
		return "BACK TO THE OUTPOST"
	end
	return ""
end

return MatchText
