-- The gun each soldier body holds in third person, placed where its gun pose puts the hand's gun.
-- Uses the model in ReplicatedStorage.GunModels named after the gun, sized to the pose file's gun, so the
-- grip lands in the hand. The magazine and the charging handle (or pump) move on their own in the poses
-- that move them: the model's parts that sit where the pose file's magazine and action meshes sit go with them.
-- A gun the pose file gives a stand-in part for (the Energy Pistol's magazine) gets a plain block for it.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Palette = require(ReplicatedStorage:WaitForChild("Guns"):WaitForChild("Palette"))

local HeldGuns = {}

local BOX_SLACK = 0.05 -- studs a part's centre may sit outside the magazine or action box and still count

export type Value = { number } -- { x, y, z, qx, qy, qz, qw }
export type Pose = { gunOn: string?, gun: Value?, mag: Value?, action: Value?, [string]: any }
export type Poses = {
	gunScale: number?,
	parts: { { name: string, bone: string, min: { number }, max: { number } } },
	poses: { [string]: Pose },
}

type Group = { parts: { BasePart }, offsets: { CFrame } } -- offsets from the handle, at rest
type Held = {
	name: string,
	model: Model,
	body: Group,
	mag: Group,
	action: Group,
	restMag: CFrame, -- where the magazine and action sit on the gun when nothing moves them
	restAction: CFrame,
	muzzle: Vector3, -- the end of the barrel, from the handle
	handle: CFrame?, -- where the gun was last put, while it is shown
}

local folder = Instance.new("Folder")
folder.Name = "HeldGuns"
folder.Parent = workspace

local held: { [Model]: Held } = {}

function HeldGuns.frame(value: Value?): CFrame
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

-- Each part box in the gun's handle space, with the gun at rest.
local function restBoxes(poses: Poses, restMag: CFrame, restAction: CFrame)
	local boxes = {}
	for _, part in poses.parts do
		local frame = if part.bone == "MagProp" then restMag elseif part.bone == "ActionProp" then restAction else CFrame.identity
		local low, high = corners(Vector3.new(table.unpack(part.min)), Vector3.new(table.unpack(part.max)), frame)
		table.insert(boxes, { name = part.name, bone = part.bone, low = low, high = high })
	end
	return boxes
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

local function build(name: string, poses: Poses): Held?
	local source = ReplicatedStorage:FindFirstChild("GunModels")
	source = source and source:FindFirstChild(name)
	if not source then
		return nil
	end
	local stand = poses.poses.Stand or {}
	local restMag = HeldGuns.frame(stand.mag)
	local restAction = HeldGuns.frame(stand.action)
	local boxes = restBoxes(poses, restMag, restAction)

	-- The pose file's whole gun, stand-ins left out, is the size and place the model must fill.
	local low, high = Vector3.one * math.huge, -Vector3.one * math.huge
	for _, box in boxes do
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
	local copy = source:Clone()
	copy.Parent = model
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			quiet(part)
		end
	end
	local box, size = model:GetBoundingBox()
	model.WorldPivot = box
	model:ScaleTo(model:GetScale() * (high.Z - low.Z) / size.Z)
	-- Handle space: the model's middle goes to the middle of the pose file's gun.
	model:PivotTo(CFrame.new((low + high) / 2))

	local result: Held = {
		name = name,
		model = model,
		body = { parts = {}, offsets = {} },
		mag = { parts = {}, offsets = {} },
		action = { parts = {}, offsets = {} },
		restMag = restMag,
		restAction = restAction,
		-- The gun lies along Z. The muzzle is the end further from the grip, most of the way up the gun.
		muzzle = Vector3.new(
			(low.X + high.X) / 2,
			low.Y + (high.Y - low.Y) * 0.7,
			if math.abs(low.Z) > math.abs(high.Z) then low.Z else high.Z
		),
		handle = nil,
	}
	local function add(group: Group, part: BasePart)
		table.insert(group.parts, part)
		table.insert(group.offsets, part.CFrame)
	end
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			local group = result.body
			for _, entry in boxes do
				if entry.bone ~= "GunMount" and not isStandIn(entry.name) and inside(part.Position, entry.low, entry.high) then
					group = if entry.bone == "MagProp" then result.mag else result.action
					break
				end
			end
			add(group, part)
		end
	end
	for _, entry in boxes do
		if isStandIn(entry.name) and entry.bone ~= "GunMount" then
			local models = ReplicatedStorage:FindFirstChild("GunModels")
			local source = models and models:FindFirstChild(entry.name)
			local block: BasePart = if source then source:Clone() else Instance.new("Part")
			block.Name = entry.name
			quiet(block)
			block.CastShadow = false
			block.Color = Palette.DeepNavy
			block.Size = entry.high - entry.low
			block.CFrame = CFrame.new((entry.low + entry.high) / 2)
			block.Parent = model
			add(if entry.bone == "MagProp" then result.mag else result.action, block)
		end
	end
	return result
end

local parts: { BasePart } = {}
local frames: { CFrame } = {}

local function place(group: Group, frame: CFrame)
	for index, part in group.parts do
		table.insert(parts, part)
		table.insert(frames, frame * group.offsets[index])
	end
end

-- Shows, moves or hides the gun one body holds. Call every frame after the body has moved.
-- gunName nil, or a pose with no gun, hides it.
function HeldGuns.show(character: Model, gunName: string?, poses: Poses?, pose: Pose?, visible: boolean)
	local current = held[character]
	if current and current.name ~= gunName then
		current.model:Destroy()
		held[character] = nil
		current = nil
	end
	if not gunName or not poses or not pose or not pose.gun or not visible then
		if current then
			current.model.Parent = nil
			current.handle = nil
		end
		return
	end
	if not current then
		current = build(gunName, poses)
		if not current then
			return
		end
		held[character] = current
	end
	local holder = character:FindFirstChild(pose.gunOn or "RightHand")
	if not holder or not holder:IsA("BasePart") then
		current.model.Parent = nil
		current.handle = nil
		return
	end
	local handle = holder.CFrame * HeldGuns.frame(pose.gun)
	current.handle = handle
	place(current.body, handle)
	place(current.mag, handle * HeldGuns.frame(pose.mag) * current.restMag:Inverse())
	place(current.action, handle * HeldGuns.frame(pose.action) * current.restAction:Inverse())
	workspace:BulkMoveTo(parts, frames, Enum.BulkMoveMode.FireCFrameChanged)
	table.clear(parts)
	table.clear(frames)
	current.model.Parent = folder
end

-- Where the end of the barrel is on the gun this body is showing, or nil if it shows none. Tracers start here.
function HeldGuns.muzzle(character: Model?): Vector3?
	local current = character and held[character]
	if not current or not current.handle then
		return nil
	end
	return current.handle * current.muzzle
end

function HeldGuns.remove(character: Model)
	local current = held[character]
	if current then
		current.model:Destroy()
		held[character] = nil
	end
end

return HeldGuns
