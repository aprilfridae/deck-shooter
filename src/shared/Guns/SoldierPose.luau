-- Where each part of the soldier's first-person arms goes, relative to the camera. The hands and fingers follow
-- the same arm clips as ever, and the arms bend to reach the hands from shoulders kept out of view.
local ArmPose = require("./ArmPose")
local SoldierArmsData = require("./SoldierArmsData")

local CLIP_SCALE = 0.7 -- the clips' bones are stored larger than they show
local FOREARM_TWIST = 0.7 -- share of the hand's turn the forearm takes, so the wrist doesn't pinch
local SHOULDERS = { Right = Vector3.new(1.12, -1, 0.1), Left = Vector3.new(-1, -1, 0.1) }
local POLES = { Right = Vector3.new(0.6, -1, 0.2), Left = Vector3.new(-0.6, -1, 0.2) }
local PREFIXES = { Right = "R.", Left = "L." }
local DIGITS = {
	{ part = "Thumb", bone = "Pulgar" },
	{ part = "Index", bone = "Indice" },
	{ part = "Middle", bone = "DedoMedio" },
	{ part = "Ring", bone = "Anular" },
	{ part = "Pinky", bone = "Menique" },
}

export type Grip = { wrist: Vector3, along: Vector3, thumb: Vector3 }
export type Fingers = { [string]: { Vector3 } } -- by digit bone: which way each of its three joints points

local function restOf(name: string): CFrame
	return CFrame.new(table.unpack(SoldierArmsData.frames[name]))
end

local function boneOf(bones: any, name: string): CFrame
	local b = bones[name]
	return CFrame.new(b[1] * CLIP_SCALE, b[2] * CLIP_SCALE, b[3] * CLIP_SCALE, b[4], b[5], b[6], b[7])
end

local function palmOf(bones: any, prefix: string): CFrame
	return boneOf(bones, prefix .. "Brazo") * boneOf(bones, prefix .. "Antebrazo") * boneOf(bones, prefix .. "Palma")
end

-- Which way each of a digit's three bones points.
local function digitAims(bones: any, prefix: string, bone: string): { Vector3 }
	local first = boneOf(bones, prefix .. bone)
	local second = first * boneOf(bones, prefix .. bone .. "2")
	local third = second * boneOf(bones, prefix .. bone .. "3")
	return { first.UpVector, second.UpVector, third.UpVector }
end

local function rotationBetween(from: Vector3, to: Vector3): CFrame
	local axis = from:Cross(to)
	if axis.Magnitude < 1e-5 then
		return CFrame.identity
	end
	return CFrame.fromAxisAngle(axis.Unit, math.acos(math.clamp(from:Dot(to), -1, 1)))
end

-- A direction with the part along an axis removed.
local function flat(direction: Vector3, axis: Vector3): Vector3
	return direction - axis * direction:Dot(axis)
end

-- A hand's axes, from the way its fingers point and the line across its knuckles.
local function handAxes(along: Vector3, across: Vector3): CFrame
	local y = along.Unit
	local z = flat(across, y).Unit
	return CFrame.fromMatrix(Vector3.zero, y:Cross(z), y, z)
end

local function makeDigit(sideName: string, digit: any, handRest: CFrame): { any }
	local rests = {}
	for joint = 1, 3 do
		rests[joint] = restOf(sideName .. digit.part .. joint)
	end
	local segments = {}
	local parent = handRest
	for joint, rest in rests do
		local upTo = math.max(joint, 2)
		local tip = rests[upTo].Position - rests[upTo - 1].Position
		segments[joint] = {
			name = sideName .. digit.part .. joint,
			rest = parent:ToObjectSpace(rest),
			along = rest:VectorToObjectSpace(tip.Unit),
		}
		parent = rest
	end
	return segments
end

local function makeSide(sideName: string, reference: any): any
	local prefix = PREFIXES[sideName]
	local upper, lower, hand = restOf(sideName .. "UpperArm"), restOf(sideName .. "LowerArm"), restOf(sideName .. "Hand")
	local shoulder = upper:PointToWorldSpace(Vector3.new(0, SoldierArmsData.shoulder, 0))
	local elbow = lower:PointToWorldSpace(Vector3.new(0, SoldierArmsData.elbow, 0))
	local wrist = hand:PointToWorldSpace(Vector3.new(0, SoldierArmsData.wrist, 0))
	local side: any = {
		name = sideName,
		prefix = prefix,
		shoulder = SHOULDERS[sideName],
		pole = POLES[sideName],
		upperRest = CFrame.new(shoulder) * upper.Rotation,
		foreRest = CFrame.new(elbow) * lower.Rotation,
		elbowRest = elbow,
		wristRest = wrist,
		upperLength = (elbow - shoulder).Magnitude,
		foreLength = (wrist - elbow).Magnitude,
		digits = {},
	}
	side.upperPart = side.upperRest:ToObjectSpace(upper)
	side.forePart = side.foreRest:ToObjectSpace(lower)

	-- How the soldier's hand sits on a clip's palm: matches the knuckles, with the wrists together.
	local palm = palmOf(reference, prefix)
	local function knuckle(bone: string): Vector3
		return palm:PointToObjectSpace(boneOf(reference, prefix .. bone).Position)
	end
	local clipAxes = handAxes(knuckle("DedoMedio"), knuckle("Indice") - knuckle("Menique"))
	local middle = restOf(sideName .. "Middle1").Position
	local across = restOf(sideName .. "Index1").Position - restOf(sideName .. "Pinky1").Position
	local restAxes = handAxes(middle - wrist, across)
	side.handOnPalm = (clipAxes * restAxes:Inverse() * hand).Rotation * CFrame.new(0, -SoldierArmsData.wrist, 0)

	-- The reference's fingers are the grip on guns with no clip.
	for _, digit in DIGITS do
		local aims = digitAims(reference, prefix, digit.bone)
		for index, aim in aims do
			aims[index] = palm:VectorToObjectSpace(aim)
		end
		table.insert(side.digits, { bone = digit.bone, segments = makeDigit(sideName, digit, hand), grip = aims })
	end
	return side
end

-- Aims a bone between two points, keeping its resting twist.
local function aimed(rest: CFrame, restEnd: Vector3, from: Vector3, to: Vector3): CFrame
	local turn = rotationBetween((restEnd - rest.Position).Unit, (to - from).Unit)
	return CFrame.new(from) * turn * rest.Rotation
end

local function poseArm(side: any, hand: CFrame, palm: CFrame, parts: any, shoulder: Vector3?)
	local wrist = palm.Position
	shoulder = shoulder or side.shoulder
	local reach = (wrist - shoulder).Magnitude
	local direction = (wrist - shoulder).Unit
	local longest = side.upperLength + side.foreLength
	if reach > longest then
		-- The shoulder is out of view, so it can come forward instead of the hand falling short.
		shoulder += direction * (reach - longest)
		reach = longest
	end
	local along, out = ArmPose.elbow(side.upperLength, side.foreLength, reach)
	local elbow = shoulder + direction * along + flat(side.pole, direction).Unit * out

	local upper = aimed(side.upperRest, side.elbowRest, shoulder, elbow)
	local fore = aimed(side.foreRest, side.wristRest, elbow, wrist)
	local forearm = (wrist - elbow).Unit
	local fromRight = flat(fore.RightVector, forearm)
	local toRight = flat(hand.RightVector, forearm)
	local twist = math.atan2(fromRight:Cross(toRight):Dot(forearm), fromRight:Dot(toRight))
	fore = CFrame.new(fore.Position) * CFrame.fromAxisAngle(forearm, twist * FOREARM_TWIST) * fore.Rotation

	parts[side.name .. "UpperArm"] = upper * side.upperPart
	parts[side.name .. "LowerArm"] = fore * side.forePart
	parts[side.name .. "Hand"] = hand
end

local function poseDigit(segments: { any }, hand: CFrame, aims: { Vector3 }, parts: any)
	local parent = hand
	for joint, segment in segments do
		local placed = parent * segment.rest
		local turn = rotationBetween(placed:VectorToWorldSpace(segment.along), aims[joint])
		parent = CFrame.new(placed.Position) * turn * placed.Rotation
		parts[segment.name] = parent
	end
end

local SoldierPose = {}

-- reference is a clip's bones, with the hands holding a gun. It lines the soldier's hands up with the clips.
function SoldierPose.new(reference: any): any
	return { right = makeSide("Right", reference), left = makeSide("Left", reference) }
end

-- The palm that a grip on a gun asks for, relative to the camera.
function SoldierPose.palm(gun: CFrame, grip: Grip): CFrame
	local y = gun:VectorToWorldSpace(grip.along).Unit
	local z = -flat(gun:VectorToWorldSpace(grip.thumb), y).Unit
	return CFrame.fromMatrix(gun:PointToWorldSpace(grip.wrist), y:Cross(z), y, z)
end

-- One clip frame, as a frame for each part. offset is the clip's meshOffset.
function SoldierPose.fromBones(pose: any, offset: CFrame, bones: any): { [string]: CFrame }
	local parts = {}
	for _, side in { pose.right, pose.left } do
		local palm = offset * palmOf(bones, side.prefix)
		local hand = palm * side.handOnPalm
		poseArm(side, hand, palm, parts)
		for _, digit in side.digits do
			local aims = digitAims(bones, side.prefix, digit.bone)
			for index, aim in aims do
				aims[index] = offset:VectorToWorldSpace(aim)
			end
			poseDigit(digit.segments, hand, aims, parts)
		end
	end
	return parts
end

-- Both hands on a gun that has no clip.
-- Turns a thumb's segments toward the gun's middle line, more at each joint out to the tip, so it wraps the gun.
local function wrapThumb(aims: { Vector3 }, palm: CFrame, gun: CFrame, amount: number)
	local local_ = gun:PointToObjectSpace(palm.Position)
	local toward = gun:PointToWorldSpace(Vector3.new(0, 0, local_.Z)) - palm.Position
	if toward.Magnitude < 1e-3 then
		return
	end
	toward = toward.Unit
	for index, aim in aims do
		local axis = aim:Cross(toward)
		if axis.Magnitude > 1e-3 then
			local most = math.acos(math.clamp(aim:Dot(toward), -1, 1))
			local angle = math.min(amount * index / #aims, most)
			aims[index] = CFrame.fromAxisAngle(axis.Unit, angle) * aim
		end
	end
end

-- Where a clip frame has each palm, relative to the camera, by side name.
function SoldierPose.clipPalms(offset: CFrame, bones: any): { [string]: CFrame }
	return { Right = offset * palmOf(bones, PREFIXES.Right), Left = offset * palmOf(bones, PREFIXES.Left) }
end

-- shoulders moves either shoulder from its usual place, in camera space, for a gun held differently.
-- wraps curls either thumb around the gun by up to that many radians at the tip; it needs gun.
-- fingers gives either hand another finger shape than the gun grip.
function SoldierPose.fromPalms(
	pose: any,
	right: CFrame,
	left: CFrame,
	shoulders: { [string]: Vector3 }?,
	gun: CFrame?,
	wraps: { [string]: number }?,
	fingers: { [string]: Fingers }?
): { [string]: CFrame }
	local parts = {}
	for side, palm in { [pose.right] = right, [pose.left] = left } do
		local hand = palm * side.handOnPalm
		poseArm(side, hand, palm, parts, shoulders and shoulders[side.name])
		for _, digit in side.digits do
			local shape = fingers and fingers[side.name] and fingers[side.name][digit.bone] or digit.grip
			local aims = {}
			for index, aim in shape do
				aims[index] = palm:VectorToWorldSpace(aim)
			end
			local wrap = wraps and wraps[side.name]
			if wrap and gun and digit.bone == "Pulgar" then
				wrapThumb(aims, palm, gun, wrap)
			end
			poseDigit(digit.segments, hand, aims, parts)
		end
	end
	return parts
end

return SoldierPose
