-- Whether a bullet flew close past the listener without stopping short of them.
local Flyby = {
	RADIUS = 6, -- studs from the head
}

-- from and to are the bullet's path. Returns how far along the path it passes closest to the
-- listener, and how close, or nil when it stops before reaching them or stays too far away.
function Flyby.pass(from: Vector3, to: Vector3, listener: Vector3): (number?, number?)
	local line = to - from
	local length = line.Magnitude
	if length < 0.01 then
		return nil, nil
	end
	local unit = line / length
	local along = (listener - from):Dot(unit)
	if along <= 0 or along >= length then
		return nil, nil
	end
	local distance = (from + unit * along - listener).Magnitude
	if distance > Flyby.RADIUS then
		return nil, nil
	end
	return along, distance
end

return Flyby
