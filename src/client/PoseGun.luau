-- A gun model posed from the pose files, for third person (HeldGuns) and first person (GunView).
-- Clones the model in ReplicatedStorage.GunModels named after the gun and sizes it to the pose file's gun, so the
-- grip lands in the hand. The model's parts that sit where the pose file's magazine and action (charging handle,
-- bolt or pump) meshes sit move with those. A part the pose file gives as a stand-in (the Energy Pistol's
-- magazine) becomes a plain block.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Palette = require(ReplicatedStorage:WaitForChild("Guns"):WaitForChild("Palette"))

local PoseGun = {}

local BOX_SLACK = 0.05 -- studs a part's centre may sit outside the magazine or action box and still count

export type Value = { number } -- { x, y, z, qx, qy, qz, qw }
export type PartBox = { name: string, bone: string, min: { number }, max: { number } }
type Group = { parts: { BasePart }, offsets: { CFrame } } -- offsets from the handle, at rest
export type Gun = {
	name: string,
	model: Model,
	body: Group,
	mag: Group,
	action: Group,
	restMag: CFrame, -- where the magazine and action sit on the gun when nothing moves them
	restAction: CFrame,
}

function PoseGun.frame(value: Value?): CFrame
	if not value then
		return CFrame.identity
	end
	return CFrame.new(value[1], value[2], value[3], value[4], value[5], value[6], value[7])
end

local function isStandIn(name: string): boolean
	return string.find(name, "StandIn", 1, true) ~= nil
end

local function corners(low: Vector3, high: Vector3, frame: CFrame): (Vector3, Vector3)
	local lo = Vector3.one * math.huge
	local hi = -lo
	for _, x in { low.X, high.X } do
		for _, y in { low.Y, high.Y } do
			for _, z in { low.Z, high.Z } do
				local point = frame * Vector3.new(x, y, z)
				lo = lo:Min(point)
				hi = hi:Max(point)
			end
		end
	end
	return lo, hi
end

local function inside(point: Vector3, low: Vector3, high: Vector3): boolean
	local slack = Vector3.one * BOX_SLACK
	local lo, hi = low - slack, high + slack
	return point.X >= lo.X and point.Y >= lo.Y and point.Z >= lo.Z and point.X <= hi.X and point.Y <= hi.Y and point.Z <= hi.Z
end

local function quiet(part: BasePart)
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Massless = true
end

-- restMag and restAction: the magazine and action frames (from the gun) in a pose where they sit home.
function PoseGun.build(name: string, boxes: { PartBox }, restMag: CFrame, restAction: CFrame): Gun?
	local source = ReplicatedStorage:FindFirstChild("GunModels")
	source = source and source:FindFirstChild(name)
	if not source then
		return nil
	end
	-- Each part box in the gun's handle space, with the gun at rest.
	local rest = {}
	for _, box in boxes do
		local frame = if box.bone == "MagProp" then restMag elseif box.bone == "ActionProp" then restAction else CFrame.identity
		local low, high = corners(Vector3.new(table.unpack(box.min)), Vector3.new(table.unpack(box.max)), frame)
		table.insert(rest, { name = box.name, bone = box.bone, low = low, high = high })
	end

	-- The pose file's whole gun, stand-ins left out, is the size and place the model must fill.
	local low, high = Vector3.one * math.huge, -Vector3.one * math.huge
	for _, box in rest do
		if not isStandIn(box.name) then
			low = low:Min(box.low)
			high = high:Max(box.high)
		end
	end
	if low.X > high.X then
		return nil
	end

	local model = Instance.new("Model")
	model.Name = name
	source:Clone().Parent = model
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			quiet(part)
			part.CastShadow = false
		end
	end
	local box, size = model:GetBoundingBox()
	model.WorldPivot = box
	model:ScaleTo(model:GetScale() * (high.Z - low.Z) / size.Z)
	-- Handle space: the model's middle goes to the middle of the pose file's gun.
	model:PivotTo(CFrame.new((low + high) / 2))

	local gun: Gun = {
		name = name,
		model = model,
		body = { parts = {}, offsets = {} },
		mag = { parts = {}, offsets = {} },
		action = { parts = {}, offsets = {} },
		restMag = restMag,
		restAction = restAction,
	}
	local function add(group: Group, part: BasePart)
		table.insert(group.parts, part)
		table.insert(group.offsets, part.CFrame)
	end
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			local group = gun.body
			for _, entry in rest do
				if entry.bone ~= "GunMount" and not isStandIn(entry.name) and inside(part.Position, entry.low, entry.high) then
					group = if entry.bone == "MagProp" then gun.mag else gun.action
					break
				end
			end
			add(group, part)
		end
	end
	for _, entry in rest do
		if isStandIn(entry.name) and entry.bone ~= "GunMount" then
			local block = Instance.new("Part")
			block.Name = entry.name
			quiet(block)
			block.CastShadow = false
			block.Color = Palette.DeepNavy
			block.Size = entry.high - entry.low
			block.CFrame = CFrame.new((entry.low + entry.high) / 2)
			block.Parent = model
			add(if entry.bone == "MagProp" then gun.mag else gun.action, block)
		end
	end
	return gun
end

local parts: { BasePart } = {}
local frames: { CFrame } = {}

local function collect(group: Group, frame: CFrame)
	for index, part in group.parts do
		table.insert(parts, part)
		table.insert(frames, frame * group.offsets[index])
	end
end

-- Puts the gun's handle at handle, with the magazine and action at their frames from the gun.
function PoseGun.place(gun: Gun, handle: CFrame, mag: CFrame, action: CFrame, parent: Instance)
	collect(gun.body, handle)
	collect(gun.mag, handle * mag * gun.restMag:Inverse())
	collect(gun.action, handle * action * gun.restAction:Inverse())
	workspace:BulkMoveTo(parts, frames, Enum.BulkMoveMode.FireCFrameChanged)
	table.clear(parts)
	table.clear(frames)
	gun.model.Parent = parent
end

return PoseGun
