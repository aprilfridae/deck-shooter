-- Jointed hands for the third-person soldier body. The body's own hands are one solid piece each, so nothing
-- could bend. The first-person arms (GunModels.SoldierArms) are the same soldier with every finger segment a
-- part of its own, and their hand sits in exactly the same place as the body's hand part (measured in Play,
-- 2026-11-11). So each body gets a copy of those palms and fingers, placed on its hand parts every frame, and
-- its solid hands are hidden. River chose this over re-exporting the body from Blender.
-- The fingers take SoldierPose's shapes, the same ones first person uses; with none given they hold the gun grip.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Guns = ReplicatedStorage:WaitForChild("Guns")
local ArmClips = require(Guns:WaitForChild("ArmClips"))
local SoldierArmsData = require(Guns:WaitForChild("SoldierArmsData"))
local SoldierPose = require(Guns:WaitForChild("SoldierPose"))

local SIDES = { "Right", "Left" }

export type Shapes = { [string]: SoldierPose.Fingers } -- by side name

type Hands = {
	model: Model,
	meshes: { BasePart },
	groups: { string },
	offsets: { CFrame },
	frames: { CFrame },
	hidden: { BasePart }, -- the body's own solid hands
}

local BodyHands = {}

local solver = SoldierPose.new(ArmClips.M57.idle.frames[1].bones)
local made: { [Model]: Hands } = {}

-- The part a mesh belongs to, from a name like RightIndex1_seg.001_metal.
local function partOf(meshName: string): string
	return string.match(meshName, "^[^_]+") or meshName
end

-- Hands and fingers only: the body has its own arms.
local function isHandPart(group: string): boolean
	return string.find(group, "Arm", 1, true) == nil
end

local function build(character: Model): Hands?
	local models = ReplicatedStorage:FindFirstChild("GunModels")
	local source = models and models:FindFirstChild("SoldierArms")
	if not source then
		return nil
	end
	local model = Instance.new("Model")
	model.Name = "JointedHands"
	local hands: Hands = { model = model, meshes = {}, groups = {}, offsets = {}, frames = {}, hidden = {} }
	for _, mesh in source:GetChildren() do
		local group = partOf(mesh.Name)
		local rest = SoldierArmsData.frames[group]
		if mesh:IsA("BasePart") and rest and isHandPart(group) then
			local copy = mesh:Clone()
			copy.Anchored = true
			copy.CanCollide = false
			copy.CanQuery = false
			copy.CanTouch = false
			copy.Massless = true
			copy.Parent = model
			table.insert(hands.meshes, copy)
			table.insert(hands.groups, group)
			table.insert(hands.offsets, CFrame.new(table.unpack(rest)):ToObjectSpace(mesh.CFrame))
		end
	end
	if #hands.meshes == 0 then
		model:Destroy()
		return nil
	end
	for _, side in SIDES do
		local hand = character:FindFirstChild(side .. "Hand")
		if hand then
			for _, piece in hand:GetDescendants() do
				if piece:IsA("BasePart") then
					table.insert(hands.hidden, piece)
				end
			end
		end
	end
	return hands
end

-- Shows and places a body's jointed hands, or hides them and gives it its solid hands back. Call every frame
-- after the body has moved. shapes gives either hand a finger shape other than the gun grip.
function BodyHands.show(character: Model, visible: boolean, shapes: Shapes?)
	-- A dead body gets its solid hands back: the jointed ones are held in place by this script, not joined to
	-- the body, so they would hang in the air as it fell.
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid and humanoid.Health <= 0 then
		visible = false
	end
	local hands = made[character]
	if not hands then
		if not visible then
			return
		end
		hands = build(character)
		if not hands then
			return
		end
		made[character] = hands
	end
	if not visible then
		if hands.model.Parent then
			hands.model.Parent = nil
			for _, piece in hands.hidden do
				piece.Transparency = 0
			end
		end
		return
	end
	local parts: { [string]: CFrame } = {}
	for _, side in SIDES do
		local hand = character:FindFirstChild(side .. "Hand")
		if hand and hand:IsA("BasePart") then
			for name, frame in SoldierPose.handParts(solver, side, hand.CFrame, shapes and shapes[side]) do
				parts[name] = frame
			end
		end
	end
	local moving, frames = {}, hands.frames
	table.clear(frames)
	for index, mesh in hands.meshes do
		local frame = parts[hands.groups[index]]
		if frame then
			table.insert(moving, mesh)
			table.insert(frames, frame * hands.offsets[index])
		end
	end
	workspace:BulkMoveTo(moving, frames, Enum.BulkMoveMode.FireCFrameChanged)
	-- Inside the character, so the body's outline covers the hands too.
	hands.model.Parent = character
	for _, piece in hands.hidden do
		piece.Transparency = 1
	end
end

function BodyHands.remove(character: Model)
	local hands = made[character]
	if hands then
		hands.model:Destroy()
		made[character] = nil
	end
end

return BodyHands
