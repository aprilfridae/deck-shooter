-- Where a bullet streak is along its path.
local Tracer = {}

-- How far along the path the streak's tail and head are after age seconds, or nil once it has landed.
function Tracer.span(total: number, age: number, speed: number, length: number): (number?, number?)
	local travelled = age * speed
	local tail = travelled - length
	if tail >= total then
		return nil, nil
	end
	return math.max(tail, 0), math.min(travelled, total)
end

return Tracer
