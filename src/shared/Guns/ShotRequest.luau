-- Turns an untrusted shot from a client into a clean request. Invalid shots become nil.
local MAX_COORDINATE = 1e5
local MAX_REWIND = 0.2
local MAX_ORIGIN_OFFSET = 6
local MIN_DIRECTION = 1e-6
-- A moving shooter is ahead of where the server has them: their position takes their ping and a few frames to
-- arrive. So the faster they move, the further from their recorded body a shot may start.
local LEAD_BASE = 0.1 -- seconds the server's copy of a player trails them even with no ping
local LEAD_MOST_PING = 0.2
local LEAD_MOST_SPEED = 110 -- the fastest fall

type Point = { x: number, y: number, z: number }

local ShotRequest = {
	VIEW_DELAY = 0.08, -- how far behind the server other players are drawn; tune in play
}

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

-- When the targets the shooter was looking at were in those places on the server.
function ShotRequest.viewTime(firedAt: number, ping: number, serverNow: number): number
	return math.max(firedAt - ping - ShotRequest.VIEW_DELAY, serverNow - MAX_REWIND)
end

-- The shooter's own position reaches the server late, so it is recorded after they fired.
function ShotRequest.shooterTime(firedAt: number, ping: number, serverNow: number): number
	return math.min(firedAt + ping, serverNow)
end

-- How many seconds ahead of the server's copy of them a shooter with this ping can be.
function ShotRequest.lead(ping: number): number
	return LEAD_BASE + math.clamp(ping, 0, LEAD_MOST_PING)
end

-- How far from the shooter's recorded body a shot may start, moving at this speed (studs a second).
function ShotRequest.originSlack(speed: number, ping: number): number
	return MAX_ORIGIN_OFFSET + math.clamp(speed, 0, LEAD_MOST_SPEED) * ShotRequest.lead(ping)
end

function ShotRequest.originDistance(origin: Point, rewound: Point): number
	local dx, dy, dz = origin.x - rewound.x, origin.y - rewound.y, origin.z - rewound.z
	return math.sqrt(dx * dx + dy * dy + dz * dz)
end

function ShotRequest.originAllowed(origin: Point, rewound: Point, slack: number?): boolean
	return ShotRequest.originDistance(origin, rewound) <= (slack or MAX_ORIGIN_OFFSET)
end

return ShotRequest
