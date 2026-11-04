-- Ray tests against a character's rewound position: a sphere for the head and
-- a vertical cylinder for the body. Plain numbers, measured from the root part.
local HEAD_HEIGHT = 2
local HEAD_RADIUS = 0.8
local BODY_RADIUS = 1.1
local BODY_TOP = 1.2
local BODY_BOTTOM = -3

local POSE_DROP = { Normal = 0, Crouch = 1.5, Slide = 2.5 }

type Point = { x: number, y: number, z: number }

local Hitbox = {}

-- Returns the distance along the ray to a sphere, or nil.
local function raySphere(origin: Point, direction: Point, cx: number, cy: number, cz: number): number?
	local ox, oy, oz = origin.x - cx, origin.y - cy, origin.z - cz
	local b = ox * direction.x + oy * direction.y + oz * direction.z
	local c = ox * ox + oy * oy + oz * oz - HEAD_RADIUS * HEAD_RADIUS
	local discriminant = b * b - c
	if discriminant < 0 then
		return nil
	end
	local root = math.sqrt(discriminant)
	local near, far = -b - root, -b + root
	if far < 0 then
		return nil
	end
	return math.max(near, 0)
end

-- Returns the distance along the ray to a vertical cylinder, or nil.
local function rayCylinder(origin: Point, direction: Point, cx: number, cz: number, bottom: number, top: number): number?
	local enter, leave = -math.huge, math.huge

	local ox, oz = origin.x - cx, origin.z - cz
	local a = direction.x * direction.x + direction.z * direction.z
	local c = ox * ox + oz * oz - BODY_RADIUS * BODY_RADIUS
	if a > 1e-9 then
		local b = ox * direction.x + oz * direction.z
		local discriminant = b * b - a * c
		if discriminant < 0 then
			return nil
		end
		local root = math.sqrt(discriminant)
		enter, leave = (-b - root) / a, (-b + root) / a
	elseif c > 0 then
		return nil
	end

	if math.abs(direction.y) > 1e-9 then
		local t1, t2 = (bottom - origin.y) / direction.y, (top - origin.y) / direction.y
		enter = math.max(enter, math.min(t1, t2))
		leave = math.min(leave, math.max(t1, t2))
	elseif origin.y < bottom or origin.y > top then
		return nil
	end

	if enter > leave or leave < 0 then
		return nil
	end
	return math.max(enter, 0)
end

-- direction must be unit length. Returns "Head" or "Body" and the distance, or nil.
function Hitbox.test(origin: Point, direction: Point, target: any): (string?, number?)
	local drop = POSE_DROP[target.pose] or 0
	local head = raySphere(origin, direction, target.x, target.y + HEAD_HEIGHT - drop, target.z)
	local body = rayCylinder(
		origin,
		direction,
		target.x,
		target.z,
		target.y + BODY_BOTTOM,
		target.y + BODY_TOP - drop
	)
	if head and (not body or head <= body) then
		return "Head", head
	elseif body then
		return "Body", body
	end
	return nil, nil
end

return Hitbox
