--!strict
-- How much of the game's extra drawing a player's machine can take: 3 is everything, 2 is trimmed, 1 is the least.
-- It follows the frame rate: drawn slowly for a while, it steps down; drawn fast for a good while, it steps back
-- up. It never touches what the game is, only how much decoration (motion blur copies, coins, sparks) goes on it.
-- Pure rules; Perf.luau on the client feeds it frames.
local PerfLevel = {}

local HIGH, LOW = 3, 1
local SLOW_FPS = 45 -- slower than this is struggling
local FAST_FPS = 57 -- faster than this has room to spare
local SLOW_FOR = 1.5 -- seconds of struggling before it steps down
local FAST_FOR = 8 -- seconds with room to spare before it steps back up
local SMOOTH = 0.5 -- seconds the frame time is averaged over
local HITCH = 0.25 -- a frame this long is a hitch (loading, a tab switch), not a slow machine: it isn't counted
local REGRET = 15 -- stepping down again this soon after stepping up means the higher level is too much
local SETTLED = 180 -- so it isn't tried again for this long

export type State = {
	level: number,
	frame: number, -- the averaged time a frame takes
	slowFor: number,
	fastFor: number,
	raisedAt: number,
	ceiling: number, -- the highest level it may go to for now
	ceilingUntil: number,
}

-- quality is Roblox's own graphics setting, 1 to 10, or 0 for automatic: a player who has turned it down starts low.
function PerfLevel.new(quality: number?): State
	local level = HIGH
	if quality and quality > 0 then
		level = if quality <= 3 then LOW elseif quality <= 6 then 2 else HIGH
	end
	return {
		level = level,
		frame = 1 / 60,
		slowFor = 0,
		fastFor = 0,
		raisedAt = -math.huge,
		ceiling = HIGH,
		ceilingUntil = -math.huge,
	}
end

-- One frame that took dt seconds, at time now. Returns the level.
function PerfLevel.step(state: State, dt: number, now: number): number
	if dt <= 0 or dt >= HITCH then
		return state.level
	end
	state.frame += (dt - state.frame) * math.min(dt / SMOOTH, 1)
	local fps = 1 / state.frame
	state.slowFor = if fps < SLOW_FPS then state.slowFor + dt else 0
	state.fastFor = if fps > FAST_FPS then state.fastFor + dt else 0
	if now >= state.ceilingUntil then
		state.ceiling = HIGH
	end
	if state.slowFor >= SLOW_FOR and state.level > LOW then
		state.level -= 1
		state.slowFor, state.fastFor = 0, 0
		if now - state.raisedAt < REGRET then
			-- It was only just raised: that level is too much for this machine, so stay under it for a while.
			state.ceiling = state.level
			state.ceilingUntil = now + SETTLED
		end
	elseif state.fastFor >= FAST_FOR and state.level < state.ceiling then
		state.level += 1
		state.slowFor, state.fastFor = 0, 0
		state.raisedAt = now
	end
	return state.level
end

-- The value for a level: all of it at 3, trimmed at 2, the least at 1.
function PerfLevel.pick<T>(level: number, high: T, medium: T, low: T): T
	return if level >= HIGH then high elseif level == 2 then medium else low
end

PerfLevel.HIGH = HIGH
PerfLevel.LOW = LOW

return PerfLevel
