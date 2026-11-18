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

-- Flashpoint's card is flicked, not thrown hard: slow enough to see it coming and turn away.
function CardAim.flashFlight(length: number, speed: number, least: number): number
	return math.max(length / speed, least)
end

-- How much of Flashpoint's blindness reaches someone `distance` from the burst: all of it within `full` of the
-- radius, falling off in a straight line to `edge` at the radius, and none beyond.
function CardAim.flashReach(distance: number, radius: number, full: number, edge: number): number
	if distance > radius then
		return 0
	end
	local share = distance / radius
	if share <= full then
		return 1
	end
	return 1 + (edge - 1) * (share - full) / (1 - full)
end

-- And how much of that someone gets for the way they are facing: `facing` is the dot product of where they look
-- and the way to the burst. Looking at it, or near it, takes it all; with their back to it they get a third.
function CardAim.flashFacing(facing: number): number
	local share = math.clamp((facing + 0.2) / 0.7, 0, 1)
	return 0.33 + 0.67 * share * share * (3 - 2 * share)
end

-- Where Rewind goes back to: the oldest point of the path that is no more than `seconds` old. `path` is oldest
-- first, each with its time. nil if there isn't `least` seconds of path yet.
function CardAim.rewindPoint(path: { { at: number } }, now: number, seconds: number, least: number): number?
	for index, point in path do
		if now - point.at <= seconds then
			return if now - point.at >= least then index else nil
		end
	end
	return nil
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
