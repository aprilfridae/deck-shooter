-- The radio's playlist rules. Pure: the caller supplies the dice and the time into the track.
-- Every track plays once, in a random order, before any repeats, and a new shuffle never opens with the track
-- that just ended. What has played is kept, so "previous" can walk back through it.
local Radio = {}

Radio.RESTART_AFTER = 3 -- seconds into a track after which "previous" restarts it instead of going back

export type State = {
	count: number, -- how many tracks there are
	order: { number }, -- every track played or lined up, oldest first
	at: number, -- where in order the radio is; 0 before the first track
}

function Radio.new(count: number): State
	return { count = count, order = {}, at = 0 }
end

-- Lines up one more pass through every track. roll(n) gives a whole number from 1 to n.
local function shuffleOn(state: State, roll: (number) -> number)
	local deck = table.create(state.count)
	for track = 1, state.count do
		deck[track] = track
	end
	for index = state.count, 2, -1 do
		local other = roll(index)
		deck[index], deck[other] = deck[other], deck[index]
	end
	local last = state.order[#state.order]
	if state.count > 1 and deck[1] == last then
		local other = roll(state.count - 1) + 1
		deck[1], deck[other] = deck[other], deck[1]
	end
	for _, track in deck do
		table.insert(state.order, track)
	end
end

-- The track playing now, or nil before the first.
function Radio.current(state: State): number?
	return state.order[state.at]
end

-- Moves on and returns the track to play, or nil if there are no tracks.
function Radio.next(state: State, roll: (number) -> number): number?
	if state.count <= 0 then
		return nil
	end
	if state.at >= #state.order then
		shuffleOn(state, roll)
	end
	state.at += 1
	return state.order[state.at]
end

-- Goes back. elapsed is how far into the current track the radio is. Returns the track to play from its
-- start: the same one if it was well under way or there's nothing before it, else the one before.
function Radio.previous(state: State, elapsed: number): number?
	if state.at <= 0 then
		return nil
	end
	if elapsed <= Radio.RESTART_AFTER and state.at > 1 then
		state.at -= 1
	end
	return state.order[state.at]
end

return Radio
