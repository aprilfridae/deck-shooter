-- Loosens an animation so no two plays go alike: its tempo runs a touch ahead of itself and behind, and whatever
-- plays it drifts a little. The same idea as the deck flourish's tempo and sway (CardFlourish), for the guns.
-- `life` is a clock that started somewhere random for this play.
local Loosen = {}

local TEMPO = 0.035 -- seconds an animation runs ahead of or behind itself
local MOVE = 0.012 -- studs it drifts
local TURN = math.rad(2) -- and how far it turns

local function smooth(t: number): number
	return t * t * (3 - 2 * t)
end

local function through(at: number, from: number, to: number): number
	return smooth(math.clamp((at - from) / (to - from), 0, 1))
end

-- A slow wander between -1 and 1 that never repeats itself. Each `which` wanders its own way.
function Loosen.wander(life: number, which: number): number
	return 0.55 * math.sin(life * 2.1 + which * 1.3)
		+ 0.3 * math.sin(life * 4.9 + which * 2.9)
		+ 0.15 * math.sin(life * 9.7 + which * 4.1)
end

-- An animation's time with its tempo loosened. It starts and ends on time, and never runs backwards.
function Loosen.tempo(elapsed: number, length: number, life: number): number
	if length <= 0 or elapsed <= 0 or elapsed >= length then
		return elapsed
	end
	local fadeIn, fadeOut = math.min(0.3, length * 0.3), math.min(0.5, length * 0.4)
	local share = through(elapsed, 0, fadeIn) * (1 - through(elapsed, length - fadeOut, length))
	return elapsed + TEMPO * Loosen.wander(life, 13) * share
end

-- How something held at `pivot` has drifted and turned about it. `share` is how much of the drift shows, 0 to 1.
function Loosen.drift(pivot: Vector3, life: number, share: number): CFrame
	local wander = Loosen.wander
	local move = Vector3.new(wander(life, 1), wander(life, 2), wander(life, 3)) * (MOVE * share)
	local turn = TURN * share
	return CFrame.new(pivot + move)
		* CFrame.Angles(wander(life, 4) * turn, wander(life, 5) * turn, wander(life, 6) * turn)
		* CFrame.new(-pivot)
end

return Loosen
