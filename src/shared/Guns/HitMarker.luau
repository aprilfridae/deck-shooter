-- How the hit marker looks as it ages: it pops up big, snaps to size, then fades.
local HitMarker = {}

local SETTLE_SHARE = 0.4 -- share of its life spent shrinking to size
local FADE_SHARE = 0.5 -- share of its life before it starts to fade

-- The marker's scale and transparency after age seconds, or nil once it's gone.
function HitMarker.look(age: number, life: number, pop: number): (number?, number?)
	local share = age / life
	if share >= 1 then
		return nil, nil
	end
	local left = math.max(1 - share / SETTLE_SHARE, 0)
	local scale = 1 + (pop - 1) * left * left
	return scale, math.max(share - FADE_SHARE, 0) / (1 - FADE_SHARE)
end

return HitMarker
