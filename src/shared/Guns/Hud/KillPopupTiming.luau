--!strict
-- How the kill pop-ups move: each line punches in a little too big and settles, holds, and fades; the newest is on
-- top; a total counts up above them and clears when things go quiet. Pure numbers, drawn by KillPopups.luau.
local KillPopupTiming = {}

local PUNCH = 1.25 -- how big a line starts
local PUNCH_TIME = 0.12
local HOLD = 2
local FADE = 0.3
local LIFE = PUNCH_TIME + HOLD + FADE
local MOST = 5 -- lines showing at once
local COUNT_TIME = 0.35 -- seconds the total takes to count up
local QUIET = 2.5 -- seconds with nothing new before the total clears
local STAGGER = 0.07 -- seconds between one shot's lines appearing, so they land one after another

-- A line `age` seconds after it appeared: its size, how see-through it is (0 solid, 1 gone), and whether it's
-- still there at all. Before it has appeared (a staggered line) it's not shown yet but is still to come.
function KillPopupTiming.line(age: number): (number, number, boolean)
	if age < 0 then
		return PUNCH, 1, true
	elseif age >= LIFE then
		return 1, 1, false
	end
	local settle = math.clamp(age / PUNCH_TIME, 0, 1)
	local scale = PUNCH + (1 - PUNCH) * (1 - (1 - settle) ^ 3)
	local fade = math.clamp((age - PUNCH_TIME - HOLD) / FADE, 0, 1)
	-- It fades in over the punch as well, so it doesn't pop.
	return scale, math.max(fade, 1 - settle), true
end

-- The total shown `age` seconds after it last changed, counting from what it showed to what it's now worth.
function KillPopupTiming.total(from: number, to: number, age: number): number
	local share = math.clamp(age / COUNT_TIME, 0, 1)
	return math.floor(from + (to - from) * (1 - (1 - share) ^ 2) + 0.5)
end

-- Whether the total has been quiet long enough to clear.
function KillPopupTiming.cleared(age: number): boolean
	return age >= QUIET
end

KillPopupTiming.LIFE = LIFE
KillPopupTiming.MOST = MOST
KillPopupTiming.STAGGER = STAGGER
KillPopupTiming.PUNCH = PUNCH

return KillPopupTiming
