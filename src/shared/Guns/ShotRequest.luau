-- Turns an untrusted shot from a client into a clean request. Invalid shots become nil.
local MAX_COORDINATE = 1e5
local MAX_REWIND = 0.2
local MAX_ORIGIN_OFFSET = 6
local MIN_DIRECTION = 1e-6

type Point = { x: number, y: number, z: number }

local ShotRequest = {}

local function isCoordinate(n: any): boolean
	return type(n) == "number" and n == n and math.abs(n) <= MAX_COORDINATE
end

local function parsePoint(raw: any): Point?
	if type(raw) ~= "table" or not (isCoordinate(raw.x) and isCoordinate(raw.y) and isCoordinate(raw.z)) then
		return nil
	end
	return { x = raw.x, y = raw.y, z = raw.z }
end

function ShotRequest.parse(raw: any, serverNow: number): any
	if type(raw) ~= "table" then
		return nil
	end
	local origin = parsePoint(raw.origin)
	local direction = parsePoint(raw.direction)
	local firedAt = raw.firedAt
	if not origin or not direction or type(firedAt) ~= "number" or firedAt ~= firedAt or math.abs(firedAt) == math.huge then
		return nil
	end

	local length = math.sqrt(direction.x ^ 2 + direction.y ^ 2 + direction.z ^ 2)
	if length < MIN_DIRECTION then
		return nil
	end

	return {
		origin = origin,
		direction = { x = direction.x / length, y = direction.y / length, z = direction.z / length },
		firedAt = math.clamp(firedAt, serverNow - MAX_REWIND, serverNow),
		aiming = raw.aiming == true,
	}
end

function ShotRequest.originAllowed(origin: Point, rewound: Point): boolean
	local dx, dy, dz = origin.x - rewound.x, origin.y - rewound.y, origin.z - rewound.z
	return math.sqrt(dx * dx + dy * dy + dz * dz) <= MAX_ORIGIN_OFFSET
end

return ShotRequest
