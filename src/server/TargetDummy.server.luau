-- Standing targets with real health, so guns can be tested alone: a plain Roblox body and a copy of
-- the soldier in StarterPlayer.StarterCharacter. Remove with the test room.
local CollectionService = game:GetService("CollectionService")
local PhysicsService = game:GetService("PhysicsService")
local Players = game:GetService("Players")
local StarterPlayer = game:GetService("StarterPlayer")

local GunTargets = require(script.Parent.GunTargets)

local RESPAWN_SECONDS = 3
local POSITION = CFrame.new(-20, 3.2, 10)
local SOLDIER_POSITION = CFrame.new(-12, 3.4, 10)
local POSED_TAG = "PosedBody" -- RemotePoses.client.luau poses these like a player's body
local BODY_GROUP = "BodyMesh" -- from CharacterBody.server.luau

local function -- A copy of the soldier. Only its root touches the world, as on players, so its posed parts can't shove it.
local function spawnSoldier()
	local source = StarterPlayer:FindFirstChild("StarterCharacter")
	if not source or not source:GetAttribute("SoldierRig") then
		return
	end
	local archivable = source.Archivable
	source.Archivable = true
	local dummy = source:Clone() :: Model
	source.Archivable = archivable
	dummy.Name = "SoldierDummy"
	for _, descendant in dummy:GetDescendants() do
		if descendant:IsA("LuaSourceContainer") then
			descendant:Destroy()
		end
	end
	while not PhysicsService:IsCollisionGroupRegistered(BODY_GROUP) do
		task.wait()
	end
	for _, part in dummy:GetDescendants() do
		if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
			part.CollisionGroup = BODY_GROUP
		end
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

spawnDummy()
task.spawn(spawnSoldier)
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
		-- A copy of the soldier. Only its root touches the world, as on players, so its posed parts can't shove it.
local function spawnSoldier()
	local source = StarterPlayer:FindFirstChild("StarterCharacter")
	if not source or not source:GetAttribute("SoldierRig") then
		return
	end
	local archivable = source.Archivable
	source.Archivable = true
	local dummy = source:Clone() :: Model
	source.Archivable = archivable
	dummy.Name = "SoldierDummy"
	for _, descendant in dummy:GetDescendants() do
		if descendant:IsA("LuaSourceContainer") then
			descendant:Destroy()
		end
	end
	while not PhysicsService:IsCollisionGroupRegistered(BODY_GROUP) do
		task.wait()
	end
	for _, part in dummy:GetDescendants() do
		if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
			part.CollisionGroup = BODY_GROUP
		end
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

spawnDummy()
task.spawn(spawnSoldier)
	end)
end

-- A copy of the soldier. Only its root touches the world, as on players, so its posed parts can't shove it.
local function spawnSoldier()
	local source = StarterPlayer:FindFirstChild("StarterCharacter")
	if not source or not source:GetAttribute("SoldierRig") then
		return
	end
	local archivable = source.Archivable
	source.Archivable = true
	local dummy = source:Clone() :: Model
	source.Archivable = archivable
	dummy.Name = "SoldierDummy"
	for _, descendant in dummy:GetDescendants() do
		if descendant:IsA("LuaSourceContainer") then
			descendant:Destroy()
		end
	end
	while not PhysicsService:IsCollisionGroupRegistered(BODY_GROUP) do
		task.wait()
	end
	for _, part in dummy:GetDescendants() do
		if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
			part.CollisionGroup = BODY_GROUP
		end
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

spawnDummy()
task.spawn(spawnSoldier)
