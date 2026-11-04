-- Shot accuracy. The server rolls spread, so a client cannot remove it.
local SPRINT_PENALTY = 1.4
local AIR_PENALTY = 1.7

type Point = { x: number, y: number, z: number }

local Spread = {}

function Spread.angle(gun: any, stance: { aiming: boolean, sprinting: boolean, airborne: boolean }): number
	local angle = if stance.aiming then gun.aimSpread else gun.hipSpread
	if stance.sprinting then
		angle *= SPRINT_PENALTY
	end
	if stance.airborne then
		angle *= AIR_PENALTY
	end
	return angle
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
