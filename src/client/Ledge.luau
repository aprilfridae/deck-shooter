-- Finds an edge in front of the character that it could parry off.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Movement = ReplicatedStorage:WaitForChild("Movement")
local Parry = require(Movement:WaitForChild("Parry"))
local MoveConfig = require(Movement:WaitForChild("MoveConfig"))

local REACHES = { 1.5, 2.5, 3.5 } -- studs ahead of the character's centre
local STAND_ROOM = 5.5
local LANDING_INSET = 1
local LANDING_LIFT = 0.1

export type Found = { height: number, landing: Vector3 }

local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Exclude
params.RespectCanCollide = true

local function isSolidScenery(part: Instance): boolean
	if not part:IsA("BasePart") or not part.Anchored then
		return false
	end
	local model = part:FindFirstAncestorOfClass("Model")
	return not (model and model:FindFirstChildOfClass("Humanoid"))
end

local function isBlocked(from: Vector3, to: Vector3): boolean
	local path = to - from
	return path.Magnitude > 0 and workspace:Raycast(from, path, params) ~= nil
end

local function canReach(root: BasePart, top: Vector3, landing: Vector3): boolean
	local above = Vector3.new(root.Position.X, landing.Y, root.Position.Z)
	return not isBlocked(top + Vector3.new(0, LANDING_LIFT, 0), top + Vector3.new(0, STAND_ROOM, 0))
		and not (above.Y > root.Position.Y and isBlocked(root.Position, above))
		and not isBlocked(above, landing)
end

local Ledge = {}

-- rootHeight is how far the root part sits above the feet.
function Ledge.find(character: Model, root: BasePart, forward: Vector3, rootHeight: number): Found?
	params.FilterDescendantsInstances = { character }
	local feetY = root.Position.Y - rootHeight
	local start = feetY + MoveConfig.ParryMaxHeight + 1
	local down = Vector3.new(0, feetY - start - 0.5, 0)

	for _, reach in REACHES do
		local ahead = root.Position + forward * reach
		local hit = workspace:Raycast(Vector3.new(ahead.X, start, ahead.Z), down, params)
		if hit then
			local height = hit.Position.Y - feetY
			if Parry.allows(height) then
				local landing = hit.Position + forward * LANDING_INSET + Vector3.new(0, rootHeight + LANDING_LIFT, 0)
				if
					not Parry.isFlat(hit.Normal.Y)
					or not isSolidScenery(hit.Instance)
					or not canReach(root, hit.Position, landing)
				then
					return nil
				end
				return { height = height, landing = landing }
			end
		end
	end
	return nil
end

return Ledge
