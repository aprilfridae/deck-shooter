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

local function makeCopy(source: BasePart): BasePart
	local copy = source:Clone()
	copy:ClearAllChildren()
	copy.Anchored = true
	copy.CanCollide = false
	copy.CanQuery = false
	copy.CanTouch = false
	copy.CastShadow = false
	copy.Color = BodyStyle.skin
	copy.Material = BodyStyle.material
	copy.Transparency = 1
	return copy
end

local function onCharacter(character: Model)
	clear()
	local humanoid = character:WaitForChild("Humanoid", 5)
	local rootPart = character:WaitForChild("HumanoidRootPart", 5) :: BasePart?
	if not humanoid or not rootPart or not character:WaitForChild("LowerTorso", 5) then
		return
	end
	local holder = Instance.new("Folder")
	holder.Name = "BodySmear"
	for _, part in character:GetChildren() do
		if part:IsA("MeshPart") then
			local copies = {}
			for index = 1, BodyStyle.smearCopies do
				copies[index] = makeCopy(part)
				copies[index].Parent = holder
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
