-- Only the root part touches the world. The mesh parts are posed for slides and crouches, and a
-- posed part in the floor would shove the whole character up. The UpperTorso also collides as an
-- arm-span-wide box, which would snag on doors and edges.
local Players = game:GetService("Players")
local PhysicsService = game:GetService("PhysicsService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Collision = require(ReplicatedStorage:WaitForChild("Guns"):WaitForChild("Collision"))

local GROUP = "BodyMesh"

-- Collision.setup may have registered it first.
if not PhysicsService:IsCollisionGroupRegistered(GROUP) then
	PhysicsService:RegisterCollisionGroup(GROUP)
end
PhysicsService:CollisionGroupSetCollidable(GROUP, "Default", false)
-- Your blur copies sit right on your body. Touching it, they threw the player into the air.
PhysicsService:CollisionGroupSetCollidable(GROUP, GROUP, false)
Collision.setup()

local function join(part: Instance)
	if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
		part.CollisionGroup = GROUP
	end
end

local function onCharacter(character: Model)
	for _, child in character:GetChildren() do
		join(child)
	end
	character.ChildAdded:Connect(join)
end

local function onPlayer(player: Player)
	player.CharacterAdded:Connect(onCharacter)
	if player.Character then
		onCharacter(player.Character)
	end
end

Players.PlayerAdded:Connect(onPlayer)
for _, player in Players:GetPlayers() do
	onPlayer(player)
end
