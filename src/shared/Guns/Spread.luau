-- Shot accuracy. The server rolls spread, so a client cannot remove it.
type Point = { x: number, y: number, z: number }

local Spread = {}

-- Movement never changes accuracy. Aiming only matters for a gun with a hipSpread.
function Spread.angle(gun: any, aiming: boolean): number
	return if gun.hipSpread and not aiming then gun.hipSpread else gun.spread
end

local function normalize(x: number, y: number, z: number): Point
	local length = math.sqrt(x * x + y * y + z * z)
	return { x = x / length, y = y / length, z = z / length }
end

local function cross(a: Point, b: Point): (number, number, number)
	return a.y * b.z - a.z * b.y, a.z * b.x - a.x * b.z, a.x * b.y - a.y * b.x
end

-- Picks a direction evenly inside a cone around the given unit direction.
function Spread.apply(direction: Point, degrees: number, rng: () -> number): Point
	if degrees <= 0 then
		return direction
	end
	local reference = if math.abs(direction.y) < 0.9 then { x = 0, y = 1, z = 0 } else { x = 1, y = 0, z = 0 }
	local ux, uy, uz = cross(direction, reference)
	local u = normalize(ux, uy, uz)
	local vx, vy, vz = cross(direction, u)

	local radius = math.tan(math.rad(degrees)) * math.sqrt(rng())
	local spin = 2 * math.pi * rng()
	local a, b = radius * math.cos(spin), radius * math.sin(spin)
	return normalize(direction.x + u.x * a + vx * b, direction.y + u.y * a + vy * b, direction.z + u.z * a + vz * b)
end

return Spread
