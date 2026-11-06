-- Motion blur on your own body, the way the gun gets it: Roblox can't blur one object, so faded
-- copies fill the jump between two held poses. Outpost only, where you can see your body.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local BodyPose = require(ReplicatedStorage:WaitForChild("Movement"):WaitForChild("BodyPose"))
local Guns = ReplicatedStorage:WaitForChild("Guns")
local BodyStyle = require(Guns:WaitForChild("BodyStyle"))
local Zones = require(Guns:WaitForChild("Zones"))

local player = Players.LocalPlayer
local BODY_GROUP = "BodyMesh" -- from CharacterBody.server.luau; it never touches the world
local SETTLE = 0.5
local STRIPPED = { Animator = true, Highlight = true, Sound = true }

type Limb = { source: BasePart, copies: { BasePart }, from: CFrame?, to: CFrame?, poses: { CFrame } }

local folder: Folder? = nil
local root: BasePart? = nil
local limbs: { Limb } = {}
local lastFrame = -1
local smearAt: number? = nil

local function share(copy: number): number
	return copy / (BodyStyle.smearCopies + 1)
end

local function clear()
	if folder then
		folder:Destroy()
	end
	folder, root, smearAt = nil, nil, nil
	table.clear(limbs)
end

-- A faded copy of the whole body. Its meshes are skinned to bones spread across the parts, so a
-- part copied on its own falls back to the modelled pose, arms out.
local function makeGhost(character: Model): Model
	local archivable = character.Archivable
	character.Archivable = true
	local ghost = character:Clone()
	character.Archivable = archivable
	for _, descendant in ghost:GetDescendants() do
		if STRIPPED[descendant.ClassName] or descendant:IsA("LuaSourceContainer") then
			descendant:Destroy()
		end
	end
	for _, part in ghost:GetDescendants() do
		if part:IsA("BasePart") then
			part.Anchored = true
			part.CanCollide = false
			part.CanQuery = false
			part.CanTouch = false
			part.CastShadow = false
			part.CollisionGroup = BODY_GROUP
			part.Transparency = 1
		end
	end
	-- The copy keeps its Humanoid: the skinned meshes fall back to the modelled pose without one.
	-- That Humanoid switches CanCollide back on, so BODY_GROUP is what keeps the copy harmless.
	local humanoid = ghost:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	end
	return ghost
end

local function onCharacter(character: Model)
	clear()
	local humanoid = character:WaitForChild("Humanoid", 5)
	local rootPart = character:WaitForChild("HumanoidRootPart", 5) :: BasePart?
	if not humanoid or not rootPart or not character:WaitForChild("LowerTorso", 5) then
		return
	end
	task.wait(SETTLE) -- the rest of the body is still arriving
	if character.Parent == nil then
		return
	end
	local holder = Instance.new("Folder")
	holder.Name = "BodySmear"
	local ghosts = {}
	for index = 1, BodyStyle.smearCopies do
		ghosts[index] = makeGhost(character)
		ghosts[index].Parent = holder
	end
	for _, part in character:GetChildren() do
		if part:IsA("MeshPart") then
			local copies = {}
			for index, ghost in ghosts do
				copies[index] = ghost:FindFirstChild(part.Name) :: BasePart
			end
			table.insert(limbs, { source = part, copies = copies, poses = {} })
		end
	end
	folder, root = holder, rootPart
end

local function hide()
	smearAt = nil
	for _, limb in limbs do
		for _, copy in limb.copies do
			copy.Transparency = 1
		end
	end
end

-- Reads the pose the body just took, so the copies can spread from the one before it.
RunService.PostSimulation:Connect(function()
	local frame = BodyPose.frame(os.clock())
	if not root or frame == lastFrame then
		return
	end
	lastFrame = frame
	for _, limb in limbs do
		limb.from = limb.to
		limb.to = root.CFrame:ToObjectSpace(limb.source.CFrame)
		if limb.from then
			for index = 1, BodyStyle.smearCopies do
				limb.poses[index] = limb.from:Lerp(limb.to, share(index))
			end
		end
	end
	smearAt = os.clock()
end)

RunService.RenderStepped:Connect(function()
	local shown = root and folder and Zones.of(player) == Zones.Outpost
	if folder then
		folder.Parent = if shown then workspace.CurrentCamera else nil
	end
	if not shown or not smearAt then
		return
	end
	local fade = 1 - (os.clock() - smearAt) / BodyStyle.smearTime
	if fade <= 0 then
		hide()
		return
	end
	for _, limb in limbs do
		for index, copy in limb.copies do
			local pose = limb.poses[index]
			if pose then
				copy.CFrame = root.CFrame * pose
				copy.Transparency = 1 - BodyStyle.smearOpacity * share(index) * fade
			end
		end
	end
end)

player.CharacterAdded:Connect(onCharacter)
player.CharacterRemoving:Connect(clear)
if player.Character then
	task.spawn(onCharacter, player.Character)
end
