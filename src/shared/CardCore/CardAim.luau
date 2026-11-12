-- Which enemy an aimed card hits, and how hard a ground blast throws. Pure: points are { x, y, z } tables.
-- A card's aim is forgiving: it takes whoever is nearest along the line and close enough to it, where a gun
-- needs the bullet itself to land.
local CardAim = {}

export type Point = { x: number, y: number, z: number }

-- A direction a client sent, as a unit vector, or nil if it isn't one. `raw` is anything with X, Y and Z.
function CardAim.direction(x: any, y: any, z: any): Point?
	local function real(part: any): boolean
		return type(part) == "number" and part == part and math.abs(part) ~= math.huge
	end
	if not (real(x) and real(y) and real(z)) then
		return nil
	end
	local length = math.sqrt(x * x + y * y + z * z)
	if length < 1e-3 then
		return nil
	end
	return { x = x / length, y = y / length, z = z / length }
end

-- The index of the target the line hits: within `reach` along it, within `width` of it, and nearest the start.
-- nil if there is none. `direction` is a unit vector.
function CardAim.pick(origin: Point, direction: Point, reach: number, width: number, targets: { Point }): number?
	local best: number? = nil
	local bestAlong = math.huge
	for index, target in targets do
		local dx, dy, dz = target.x - origin.x, target.y - origin.y, target.z - origin.z
		local along = dx * direction.x + dy * direction.y + dz * direction.z
		if along > 0 and along <= reach then
			local px, py, pz = dx - direction.x * along, dy - direction.y * along, dz - direction.z * along
			local off = math.sqrt(px * px + py * py + pz * pz)
			if off <= width and along < bestAlong then
				best, bestAlong = index, along
			end
		end
	end
	return best
end

-- Switchback's card is thrown, and takes this long to cover the distance. The server swaps the two players when
-- it lands, and the client draws it flying for the same time.
-- It is thrown hard: close to a hitscan, with just enough time in the air to be seen turning blue.
CardAim.THROW_SPEED = 500 -- studs a second
CardAim.THROW_LEAST = 0.14 -- seconds: the shortest a throw takes, however close the target
CardAim.THROW_WINDUP = 0.22 -- seconds from using the card to it leaving the hand

function CardAim.flight(length: number): number
	return math.max(length / CardAim.THROW_SPEED, CardAim.THROW_LEAST)
end

-- The speed that carries a body `height` studs straight up against this gravity.
function CardAim.launchSpeed(height: number, gravity: number): number
	return math.sqrt(2 * gravity * height)
end

-- The way a blast at `point` throws a body at `body`: straight away from it, and never downward, so a blast
-- from a ledge above still lifts. Straight up if the two are in the same place.
function CardAim.blastDirection(point: Point, body: Point): Point
	local x, y, z = body.x - point.x, math.max(body.y - point.y, 0), body.z - point.z
	local length = math.sqrt(x * x + y * y + z * z)
	if length < 1e-3 then
		return { x = 0, y = 1, z = 0 }
	end
	return { x = x / length, y = y / length, z = z / length }
end

return CardAim
