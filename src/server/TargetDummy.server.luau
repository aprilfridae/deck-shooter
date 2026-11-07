-- Standing targets with real health, so guns can be tested alone: a plain Roblox body and a copy of
-- the soldier. Remove with the test room.
local CollectionService = game:GetService("CollectionService")
local PhysicsService = game:GetService("PhysicsService")
local Players = game:GetService("Players")

local GunTargets = require(script.Parent.GunTargets)

local RESPAWN_SECONDS = 3
local POSITION = CFrame.new(-20, 3.2, 10)
local SOLDIER_POSITION = CFrame.new(-12, 3.4, 10)
local POSED_TAG = "PosedBody" -- RemotePoses.client.luau poses these like a player's body
local BODY_GROUP = "BodyMesh" -- from CharacterBody.server.luau
-- A player's character also carries scripts, a glow, sounds and tools.
local STRIP = { Highlight = true, Sound = true, Tool = true, ForceField = true }

local function spawnDummy()
	local description = Instance.new("HumanoidDescription")
	local dummy = Players:CreateHumanoidModelFromDescription(description, Enum.HumanoidRigType.R15)
	dummy.Name = "TargetDummy"
	dummy:PivotTo(POSITION)
	dummy.Parent = workspace

	local target = GunTargets.add(dummy, nil)
	if not target then
		dummy:Destroy()
		return
	end
	-- A nearby player would otherwise run its physics, and the server's push would be lost.
	target.root:SetNetworkOwner(nil)
	target.humanoid.Died:Connect(function()
		task.wait(RESPAWN_SECONDS)
		dummy:Destroy()
		spawnDummy()
	end)
end

-- StarterPlayer.StarterCharacter isn't there while the game runs, so the soldier is copied from the
-- first player who wears it, the first time one spawns.
local soldier: Model? = nil

local function copySoldier(character: Model): Model?
	local archivable = character.Archivable
	character.Archivable = true
	local copy = character:Clone()
	character.Archivable = archivable
	if not copy then
		return nil
	end
	for _, descendant in copy:GetDescendants() do
		if STRIP[descendant.ClassName] or descendant:IsA("LuaSourceContainer") then
			descendant:Destroy()
		end
	end
	return copy
end

-- Only its root touches the world, as on players, so its posed parts can't shove it.
local function spawnSoldier()
	if not soldier then
		return
	end
	local dummy = soldier:Clone()
	dummy.Name = "SoldierDummy"
	while not PhysicsService:IsCollisionGroupRegistered(BODY_GROUP) do
		task.wait()
	end
	for _, part in dummy:GetDescendants() do
		if part:IsA("BasePart") then
			part.Anchored = false
			if part.Name ~= "HumanoidRootPart" then
				part.CollisionGroup = BODY_GROUP
			end
		end
	end
	local humanoid = dummy:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.Health = humanoid.MaxHealth
	end
	dummy:PivotTo(SOLDIER_POSITION)
	dummy.Parent = workspace
	CollectionService:AddTag(dummy, POSED_TAG)

	local target = GunTargets.add(dummy, nil)
	if not target then
		dummy:Destroy()
		return
	end
	target.root:SetNetworkOwner(nil)
	target.humanoid.Died:Connect(function()
		task.wait(RESPAWN_SECONDS)
		dummy:Destroy()
		spawnSoldier()
	end)
end

local function onCharacter(character: Model)
	if soldier or not character:GetAttribute("SoldierRig") then
		return
	end
	-- Let the whole body load before copying it.
	if not character:WaitForChild("HumanoidRootPart", 10) or not character:WaitForChild("Humanoid", 10) then
		return
	end
	task.wait(1)
	if soldier or not character.Parent then
		return
	end
	local copy = copySoldier(character)
	if copy and not soldier then
		soldier = copy
		spawnSoldier()
	end
end

local function onPlayer(player: Player)
	player.CharacterAdded:Connect(onCharacter)
	if player.Character then
		task.spawn(onCharacter, player.Character)
	end
end

spawnDummy()
Players.PlayerAdded:Connect(onPlayer)
for _, player in Players:GetPlayers() do
	task.spawn(onPlayer, player)
end
