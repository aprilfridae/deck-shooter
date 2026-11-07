-- The soldier's own arms, hands and fingers in first person. Uses the SoldierArms model in
-- ReplicatedStorage.GunModels: the exported pieces, each a MeshPart named <Part>_<material> (SoldierRig lists them).
-- Each piece rides its arm part or finger: camera * pose * the piece's offset from that part.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BodyStyle = require(ReplicatedStorage:WaitForChild("Guns"):WaitForChild("BodyStyle"))
local SoldierRig = require(ReplicatedStorage:WaitForChild("Guns"):WaitForChild("SoldierRig"))

local SoldierArms = {}

local model: Model? = nil
local pieces: { BasePart } = {}
local partOf: { string } = {}
local offsets: { CFrame } = {}
local frames: { CFrame } = {}
local moved: { BasePart } = {}

local function source(): Instance?
	local folder = ReplicatedStorage:FindFirstChild("GunModels")
	return folder and folder:FindFirstChild("SoldierArms")
end

-- True once the SoldierArms model has been imported.
function SoldierArms.ready(): boolean
	return source() ~= nil
end

local function frameOf(value: { number }): CFrame
	return CFrame.new(value[1], value[2], value[3], value[4], value[5], value[6], value[7])
end

local function build(): Model?
	local from = source()
	if not from then
		return nil
	end
	local copy = Instance.new("Model")
	copy.Name = "SoldierArms"
	from:Clone().Parent = copy
	for _, part in copy:GetDescendants() do
		if part:IsA("BasePart") then
			local entry = SoldierRig.arms[part.Name]
			if entry then
				part.Anchored = true
				part.CanCollide = false
				part.CanQuery = false
				part.CanTouch = false
				part.CastShadow = false
				part.Material = BodyStyle.material
				local colour = SoldierRig.colors[entry.material]
				if colour then
					part.Color = Color3.fromRGB(colour[1], colour[2], colour[3])
				end
				table.insert(pieces, part)
				table.insert(partOf, entry.part)
				table.insert(offsets, frameOf(entry.offset))
			else
				part.Transparency = 1 -- not one of the arm pieces
			end
		end
	end
	return copy
end

-- Shows the arms in one frame's pose. base is the camera (with any shake); bones are relative to it.
function SoldierArms.place(camera: Camera, base: CFrame, bones: { [string]: { number } })
	model = model or build()
	if not model then
		return
	end
	table.clear(moved)
	table.clear(frames)
	for index, piece in pieces do
		local value = bones[partOf[index]]
		if value then
			table.insert(moved, piece)
			table.insert(frames, base * frameOf(value) * offsets[index])
		end
	end
	workspace:BulkMoveTo(moved, frames, Enum.BulkMoveMode.FireCFrameChanged)
	model.Parent = camera
end

function SoldierArms.hide()
	if model then
		model.Parent = nil
	end
end

return SoldierArms
