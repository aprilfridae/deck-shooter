-- Split's doubles: a copy of a player's body that sprints off holding their gun. It is a gun target like any body,
-- posed by every client like the soldier dummy (the PosedBody tag), but when it is shot down or its time is up it
-- glitches away (KillDerez, told by the abilities' Fx remote), pays nothing and shows in no kill feed.
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local MoveConfig = require(ReplicatedStorage:WaitForChild("Movement"):WaitForChild("MoveConfig"))
local GunTargets = require(script.Parent.GunTargets)

local POSED_TAG = "PosedBody" -- RemotePoses.client.luau poses these like a player's body
-- A player's character also carries scripts, a glow, sounds and tools.
local STRIP = { Highlight = true, Sound = true, Tool = true, ForceField = true }
local KEEP = { SoldierRig = true } -- the attributes a copy keeps: this one picks its hitbox

local Decoys = {}

type Live = { target: GunTargets.Target, way: Vector3, gone: boolean, fx: (Model) -> (), linger: number }
local live: { [Model]: Live } = {}

local function copyBody(body: Model): Model?
	local archivable = body.Archivable
	body.Archivable = true
	local copy = body:Clone()
	body.Archivable = archivable
	if not copy then
		return nil
	end
	for _, descendant in copy:GetDescendants() do
		if STRIP[descendant.ClassName] or descendant:IsA("LuaSourceContainer") then
			descendant:Destroy()
		end
	end
	for name in copy:GetAttributes() do
		if not KEEP[name] then
			copy:SetAttribute(name, nil)
		end
	end
	return copy
end

-- Makes `owner`'s double at `at` (where its root goes, facing the way it runs), holding gun `gunId`. fx tells
-- clients it's gone, so they glitch it away. Returns the double's target, or nil if there's no body to copy.
function Decoys.spawn(owner: Player, body: Model, at: CFrame, gunId: string?, health: number, fx: (Model) -> (), linger: number): GunTargets.Target?
	local model = copyBody(body)
	if not model then
		return nil
	end
	model.Name = owner.Name
	model:SetAttribute("GunId", gunId)
	model:SetAttribute("MovePose", "Normal")
	model:SetAttribute("Decoy", true)
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local root = model:FindFirstChild("HumanoidRootPart")
	if not humanoid or not root or not root:IsA("BasePart") then
		model:Destroy()
		return nil
	end
	humanoid.BreakJointsOnDeath = false -- it glitches away whole
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.WalkSpeed = MoveConfig.SprintSpeed
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			part.Anchored = false
		end
	end
	model:PivotTo(at)
	model.Parent = workspace
	CollectionService:AddTag(model, POSED_TAG)
	local target = GunTargets.add(model, nil)
	if not target then
		model:Destroy()
		return nil
	end
	root:SetNetworkOwner(nil)
	target.decoy = true
	target.owner = owner
	target.health = health
	target.humanoid.Health = health
	model:SetAttribute("Health", health)
	local way = Vector3.new(at.LookVector.X, 0, at.LookVector.Z)
	way = if way.Magnitude > 0.01 then way.Unit else Vector3.zAxis
	live[model] = { target = target, way = way, gone = false, fx = fx, linger = linger }
	humanoid:Move(way, false)
	return target
end

-- The double glitches away: shot down or out of time. Safe to call twice.
function Decoys.vanish(target: GunTargets.Target)
	local model = target.model
	local entry = live[model]
	if not entry or entry.gone then
		return
	end
	entry.gone = true
	target.health = 0
	target.humanoid:Move(Vector3.zero, false)
	target.root.Anchored = true -- it stands where it was while it comes apart
	entry.fx(model)
	task.delay(entry.linger, function()
		live[model] = nil
		model:Destroy()
	end)
end

function Decoys.isDecoy(target: GunTargets.Target): boolean
	return target.decoy == true
end

-- Keeps every double running the way it set off: a Humanoid told to Move keeps going, but one that's been bumped
-- round is set straight again, and one that has fallen out of the world is cleared away.
RunService.Heartbeat:Connect(function()
	for model, entry in live do
		if not entry.gone then
			if not model.Parent or entry.target.root.Position.Y < workspace.FallenPartsDestroyHeight + 50 then
				Decoys.vanish(entry.target)
			else
				entry.target.humanoid:Move(entry.way, false)
			end
		end
	end
end)

return Decoys
