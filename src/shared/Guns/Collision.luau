-- Collision groups for parts that stop feet but not bullets: the Relay map's invisible railings
-- and window panes. Roblox ignores CanQuery = false on a part that collides, so these parts sit
-- in their own group instead, and raycasts for shots and edges use a group that passes them.
local PhysicsService = game:GetService("PhysicsService")
local RunService = game:GetService("RunService")

local Collision = {
	walkOnly = "WalkOnly", -- railings and panes
	shots = "Shots", -- set on the RaycastParams of shots and the edge check
	body = "BodyMesh", -- the character's posed mesh parts (CharacterBody.server.luau)
}

local function register(name: string)
	if not PhysicsService:IsCollisionGroupRegistered(name) then
		PhysicsService:RegisterCollisionGroup(name)
	end
end

-- Server only: registers the groups, which then replicate. Safe to call more than once.
function Collision.setup()
	if not RunService:IsServer() then
		return
	end
	register(Collision.walkOnly)
	register(Collision.shots)
	register(Collision.body)
	PhysicsService:CollisionGroupSetCollidable(Collision.shots, Collision.walkOnly, false)
	PhysicsService:CollisionGroupSetCollidable(Collision.body, Collision.walkOnly, false)
end

-- Makes a part stop feet only.
function Collision.feetOnly(part: BasePart)
	part.CollisionGroup = Collision.walkOnly
end

-- Makes a raycast pass through parts that stop feet only. Groups replicate from the server, so
-- until they arrive the cast keeps the default group.
function Collision.forShots(params: RaycastParams): RaycastParams
	if PhysicsService:IsCollisionGroupRegistered(Collision.shots) then
		params.CollisionGroup = Collision.shots
	end
	return params
end

return Collision
