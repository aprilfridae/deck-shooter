-- The first-person arms. Bends the arm bones so each hand reaches its spot on the held gun.
local Palette = require(game:GetService("ReplicatedStorage"):WaitForChild("Guns"):WaitForChild("Palette"))
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ArmPose = require(ReplicatedStorage.Guns.ArmPose)

local ARM_SCALE = 0.7
local OFFSET = CFrame.new(0.3, -1.9, 0.1) -- from the camera, puts the shoulders below the view
local RIGHT_ELBOW = Vector3.new(0.6, -1, 0.2)
local LEFT_ELBOW = Vector3.new(-0.6, -1, 0.2)
local FINGER_CURL = math.rad(40)
local THUMB_CURL = math.rad(20)
local FOREARM_TWIST = 0.7 -- share of the hand's turn the forearm takes, so the wrist doesn't pinch
local FINGERS = { "Indice", "DedoMedio", "Anular", "Menique" }
-- A faint glowing outline round the arms. It lights nothing else.
local SKIN_COLOR = Palette.DeepNavy
local GLOW_COLOR = Palette.DataCyan
local GLOW_FILL = 0.82 -- how see-through the glow is over the arm itself
local GLOW_EDGE = 0.3 -- and the outline
local FINGER_JITTER = 1.2 -- degrees at every finger and thumb joint
-- Each bone twitches on its own, by up to this many degrees. They add up down the arm.
local JITTER_BONES = {
	{ name = "R.Brazo", degrees = 0.4 },
	{ name = "L.Brazo", degrees = 0.4 },
	{ name = "R.Antebrazo", degrees = 0.4 },
	{ name = "L.Antebrazo", degrees = 0.4 },
	{ name = "R.Palma", degrees = 1 },
	{ name = "L.Palma", degrees = 1 },
}

for _, side in { "R.", "L." } do
	for _, digit in { "Pulgar", table.unpack(FINGERS) } do
		for _, joint in { "", "2", "3" } do
			table.insert(JITTER_BONES, { name = side .. digit .. joint, degrees = FINGER_JITTER })
		end
	end
end

export type Grip = { wrist: Vector3, along: Vector3, thumb: Vector3 }

local rig: any = nil
local meshOffset = OFFSET
local jitterStep = -1

local function rotationBetween(from: Vector3, to: Vector3): CFrame
	local axis = from:Cross(to)
	if axis.Magnitude < 1e-5 then
		return CFrame.identity
	end
	return CFrame.fromAxisAngle(axis.Unit, math.acos(math.clamp(from:Dot(to), -1, 1)))
end

local function restOf(mesh: BasePart, bone: Bone): CFrame
	return mesh.CFrame:ToObjectSpace(bone.WorldCFrame)
end

local function makeSide(mesh: BasePart, prefix: string, curlSign: number, pole: Vector3)
	local function bone(name: string): Bone
		return mesh:FindFirstChild(prefix .. name, true) :: Bone
	end
	local upper, fore, palm = bone("Brazo"), bone("Antebrazo"), bone("Palma")
	local side: any = {
		upper = upper,
		fore = fore,
		palm = palm,
		upperRest = restOf(mesh, upper),
		foreRest = restOf(mesh, fore),
		palmRest = restOf(mesh, palm),
		pole = pole,
		digits = {},
	}
	side.upperLength = (side.foreRest.Position - side.upperRest.Position).Magnitude
	side.foreLength = (side.palmRest.Position - side.foreRest.Position).Magnitude

	local function addDigit(name: string, curl: number)
		local root = bone(name)
		local joints = {}
		for _, suffix in { "2", "3" } do
			local joint = bone(name .. suffix)
			table.insert(joints, { bone = joint, rest = joint.CFrame })
		end
		local turn = CFrame.Angles(0, 0, curl * curlSign)
		table.insert(side.digits, { root = root, rest = restOf(mesh, root), joints = joints, turn = turn })
	end
	for _, name in FINGERS do
		addDigit(name, FINGER_CURL)
	end
	addDigit("Pulgar", THUMB_CURL)
	return side
end

local function makeRig(lit: boolean?): any
	local folder = ReplicatedStorage:FindFirstChild("GunModels")
	local source = folder and folder:FindFirstChild("Arms")
	if not source then
		return nil
	end
	local model = source:Clone()
	model.Name = "ViewArms"
	local mesh = model:FindFirstChildWhichIsA("MeshPart", true)
	if not mesh then
		return nil
	end
	model.PrimaryPart = mesh
	model:ScaleTo(ARM_SCALE)
	mesh.Anchored = true
	mesh.CanCollide = false
	mesh.CanQuery = false
	mesh.CanTouch = false
	mesh.CastShadow = false
	-- Plain colour for now, until the arms get their texture.
	local skin = mesh:FindFirstChildWhichIsA("SurfaceAppearance")
	if skin then
		skin:Destroy()
	end
	mesh.TextureID = ""
	mesh.Material = Enum.Material.SmoothPlastic
	mesh.Color = SKIN_COLOR
	local bones = {}
	for _, bone in mesh:GetDescendants() do
		if bone:IsA("Bone") then
			bones[bone.Name] = bone
		end
	end
	if lit then
		local outline = Instance.new("Highlight")
		outline.OutlineColor = GLOW_COLOR
		outline.FillColor = GLOW_COLOR
		outline.FillTransparency = GLOW_FILL
		outline.OutlineTransparency = GLOW_EDGE
		outline.DepthMode = Enum.HighlightDepthMode.Occluded
		outline.Parent = model
	end
	return {
		model = model,
		mesh = mesh,
		bones = bones,
		right = makeSide(mesh, "R.", -1, RIGHT_ELBOW),
		left = makeSide(mesh, "L.", 1, LEFT_ELBOW),
	}
end

-- Aims a bone between two points, keeping its resting twist.
local function aimed(rest: CFrame, restEnd: Vector3, from: Vector3, to: Vector3): CFrame
	local turn = rotationBetween((restEnd - rest.Position).Unit, (to - from).Unit)
	return CFrame.new(from) * turn * rest.Rotation
end

-- A direction with the part along an axis removed.
local function flat(direction: Vector3, axis: Vector3): Vector3
	return direction - axis * direction:Dot(axis)
end

local function poseSide(side: any, gun: CFrame, grip: Grip)
	local shoulder = side.upperRest.Position
	local toWrist = gun:PointToWorldSpace(grip.wrist) - shoulder
	local reach = toWrist.Magnitude
	local direction = toWrist.Unit
	local along, out = ArmPose.elbow(side.upperLength, side.foreLength, reach)
	local bend = side.pole - direction * side.pole:Dot(direction)
	local elbow = shoulder + direction * along + bend.Unit * out
	local hand = shoulder + direction * math.min(reach, side.upperLength + side.foreLength)

	local upper = aimed(side.upperRest, side.foreRest.Position, shoulder, elbow)
	local fore = aimed(side.foreRest, side.palmRest.Position, elbow, hand)

	local y = gun:VectorToWorldSpace(grip.along).Unit
	local thumb = gun:VectorToWorldSpace(grip.thumb)
	local z = -(thumb - y * thumb:Dot(y)).Unit
	local palm = CFrame.fromMatrix(hand, y:Cross(z), y, z)

	local forearm = (hand - elbow).Unit
	local fromRight = flat(fore.RightVector, forearm)
	local toRight = flat(palm.RightVector, forearm)
	local twist = math.atan2(fromRight:Cross(toRight):Dot(forearm), fromRight:Dot(toRight))
	fore = CFrame.new(fore.Position) * CFrame.fromAxisAngle(forearm, twist * FOREARM_TWIST) * fore.Rotation

	side.upper.CFrame = upper
	side.fore.CFrame = upper:ToObjectSpace(fore)
	side.palm.CFrame = fore:ToObjectSpace(palm)

	local carry = palm * side.palmRest:Inverse()
	for _, digit in side.digits do
		digit.root.CFrame = carry * digit.rest * digit.turn
		for _, joint in digit.joints do
			joint.bone.CFrame = joint.rest * digit.turn
		end
	end
end

local ViewArms = {}

-- Bends the arms. gun is the held gun relative to the camera.
function ViewArms.pose(gun: CFrame, right: Grip, left: Grip)
	rig = rig or makeRig(true)
	if rig then
		meshOffset = OFFSET
		local inMesh = OFFSET:ToObjectSpace(gun)
		poseSide(rig.right, inMesh, right)
		poseSide(rig.left, inMesh, left)
	end
end

-- Each bone is { x, y, z, qx, qy, qz, qw } relative to its parent, at full model size.
local function setBones(target: any, bones: { [string]: { number } })
	for name, b in bones do
		target.bones[name].CFrame =
			CFrame.new(b[1] * ARM_SCALE, b[2] * ARM_SCALE, b[3] * ARM_SCALE, b[4], b[5], b[6], b[7])
	end
end

-- Shows one exported frame.
function ViewArms.showFrame(offset: CFrame, bones: { [string]: { number } })
	rig = rig or makeRig(true)
	if rig then
		meshOffset = offset
		setBones(rig, bones)
	end
end

-- A faded copy of the arms for the motion blur, or nil if the arms model is missing.
function ViewArms.makeGhost(): any
	return makeRig()
end

function ViewArms.poseGhost(ghost: any, bones: { [string]: { number } })
	setBones(ghost, bones)
end

function ViewArms.placeGhost(ghost: any, camera: Camera, offset: CFrame, transparency: number)
	ghost.mesh.Transparency = transparency
	ghost.mesh.CFrame = camera.CFrame * offset
	ghost.model.Parent = camera
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
	for seed, joint in JITTER_BONES do
		rig.bones[joint.name].Transform = ViewArms.shaken(step, seed, 0, math.rad(joint.degrees) * strength)
	end
end

function ViewArms.place(camera: Camera)
	if rig then
		rig.mesh.CFrame = camera.CFrame * meshOffset
		rig.model.Parent = camera
	end
end

function ViewArms.hide()
	if rig then
		rig.model.Parent = nil
	end
end

return ViewArms
