-- The first-person arms: the soldier's own arms and jointed hands, placed part by part from SoldierPose.
local BodyStyle = require(game:GetService("ReplicatedStorage"):WaitForChild("Guns"):WaitForChild("BodyStyle"))
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ArmClips = require(ReplicatedStorage.Guns.ArmClips)
local ArmPose = require(ReplicatedStorage.Guns.ArmPose)
local SoldierArmsData = require(ReplicatedStorage.Guns.SoldierArmsData)
local SoldierPose = require(ReplicatedStorage.Guns.SoldierPose)

local FINGER_JITTER = 1.2 -- degrees at every finger and thumb joint
local ARM_JITTER = 0.4
local HAND_JITTER = 1
local GHOST_MIN_MOVE = 0.06 -- studs a part must be from the real one for its blur copy to show

export type Grip = SoldierPose.Grip

local solver = SoldierPose.new(ArmClips.M57.idle.frames[1].bones)
local jitterDegrees: { [string]: number } = {}
for name in SoldierArmsData.frames do
	local isHand = string.find(name, "Hand", 1, true) ~= nil
	local isArm = string.find(name, "Arm", 1, true) ~= nil
	jitterDegrees[name] = if isHand then HAND_JITTER elseif isArm then ARM_JITTER else FINGER_JITTER
end

local rig: any = nil
local jitterStep = -1

-- The part a mesh belongs to, from a name like RightIndex1_seg.001_metal.
local function partOf(meshName: string): string
	return string.match(meshName, "^[^_]+") or meshName
end

local function makeRig(lit: boolean?): any
	local folder = ReplicatedStorage:FindFirstChild("GunModels")
	local source = folder and folder:FindFirstChild("SoldierArms")
	if not source then
		return nil
	end
	local model = source:Clone()
	model.Name = "ViewArms"
	local meshes, groups, offsets = {}, {}, {}
	for _, mesh in model:GetChildren() do
		local rest = SoldierArmsData.frames[partOf(mesh.Name)]
		if mesh:IsA("BasePart") and rest then
			mesh.Anchored = true
			mesh.CanCollide = false
			mesh.CanQuery = false
			mesh.CanTouch = false
			mesh.CastShadow = false
			table.insert(meshes, mesh)
			table.insert(groups, partOf(mesh.Name))
			table.insert(offsets, CFrame.new(table.unpack(rest)):ToObjectSpace(mesh.CFrame))
		end
	end
	if lit then
		local outline = Instance.new("Highlight")
		outline.OutlineColor = BodyStyle.glow
		outline.FillColor = BodyStyle.glow
		outline.FillTransparency = BodyStyle.glowFill
		outline.OutlineTransparency = BodyStyle.glowEdge
		outline.DepthMode = BodyStyle.depthMode
		outline.Parent = model
	end
	return {
		model = model,
		meshes = meshes,
		groups = groups,
		offsets = offsets,
		frames = table.create(#meshes),
		jitter = {},
		parts = nil,
	}
end

-- view is where the arms hang from: the camera, or the camera with the gun's sway on it.
local function placeRig(target: any, camera: Camera, view: CFrame?)
	view = view or camera.CFrame
	for index, group in target.groups do
		local shake = target.jitter[group] or CFrame.identity
		target.frames[index] = view * target.parts[group] * shake * target.offsets[index]
	end
	target.model.Parent = camera
	workspace:BulkMoveTo(target.meshes, target.frames, Enum.BulkMoveMode.FireCFrameChanged)
end

local ViewArms = {}

-- Bends the arms. gun is the held gun relative to the camera.
-- rightGun and leftGun, if given, are where each hand holds instead, such as while the gun spins.
function ViewArms.pose(
	gun: CFrame,
	right: Grip,
	left: Grip,
	shoulders: { [string]: Vector3 }?,
	wraps: { [string]: number }?,
	rightGun: CFrame?,
	leftGun: CFrame?
)
	rig = rig or makeRig(true)
	if rig then
		local rightPalm = SoldierPose.palm(rightGun or gun, right)
		local leftPalm = SoldierPose.palm(leftGun or gun, left)
		rig.parts = SoldierPose.fromPalms(solver, rightPalm, leftPalm, shoulders, gun, wraps)
	end
end

-- Holds the deck of cards: each palm sits on the frame it's given, relative to the camera, with its fingers in the
-- shape given.
function ViewArms.holdCards(right: CFrame, left: CFrame, fingers: { [string]: SoldierPose.Fingers })
	rig = rig or makeRig(true)
	if rig then
		rig.parts = SoldierPose.fromPalms(solver, right, left, nil, nil, nil, fingers)
	end
end

-- Shows one exported frame.
function ViewArms.showFrame(offset: CFrame, bones: { [string]: { number } })
	rig = rig or makeRig(true)
	if rig then
		rig.parts = SoldierPose.fromBones(solver, offset, bones)
	end
end

-- A faded copy of the arms for the motion blur, or nil if the arms model is missing.
function ViewArms.makeGhost(): any
	return makeRig()
end

function ViewArms.poseGhost(ghost: any, offset: CFrame, bones: { [string]: { number } })
	ghost.parts = SoldierPose.fromBones(solver, offset, bones)
end

function ViewArms.placeGhost(ghost: any, camera: Camera, transparency: number, view: CFrame?)
	-- A part that has hardly moved gets no blur: a see-through copy sitting right on top of the real part only
	-- makes it flicker.
	for index, mesh in ghost.meshes do
		local group = ghost.groups[index]
		local real = rig and rig.parts and rig.parts[group]
		local still = real and (ghost.parts[group].Position - real.Position).Magnitude < GHOST_MIN_MOVE
		mesh.Transparency = if still then 1 else transparency
	end
	placeRig(ghost, camera, view)
end

function ViewArms.hideGhost(ghost: any)
	ghost.model.Parent = nil
end

function ViewArms.removeGhost(ghost: any)
	ghost.model:Destroy()
end

-- A small offset that holds for one step, for the hand-animated jitter.
function ViewArms.shaken(step: number, seed: number, move: number, turn: number): CFrame
	local x, y, z, pitch, yaw, roll = ArmPose.shake(step, seed)
	return CFrame.new(x * move, y * move, z * move) * CFrame.Angles(pitch * turn, yaw * turn, roll * turn)
end

-- Twitches the arms and hands, on top of whatever pose they're in.
function ViewArms.jitter(step: number, strength: number)
	if not rig or step == jitterStep then
		return
	end
	jitterStep = step
	local seed = 0
	for name, degrees in jitterDegrees do
		seed += 1
		rig.jitter[name] = ViewArms.shaken(step, seed, 0, math.rad(degrees) * strength)
	end
end

function ViewArms.place(camera: Camera, view: CFrame?)
	if rig and rig.parts then
		placeRig(rig, camera, view)
	end
end

function ViewArms.hide()
	if rig then
		rig.model.Parent = nil
	end
end

return ViewArms
