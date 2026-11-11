-- Bends one of a soldier body's arms so its hand part lands on a frame: the turns for its shoulder, elbow and
-- wrist joints. Used where a hand has to be somewhere exact, such as on a magazine during a reload, which a still
-- pose can't do. The same working as tools/fix_pistol_arms.py, which River has seen on the pistol.
--
-- A soldier's arm: the shoulder joint turns any way, the elbow is a hinge about the upper arm's X axis that folds
-- the forearm forward, and the wrist turns any way.
local ArmReach = {}

export type Arm = {
	upper: number, -- shoulder to elbow
	fore: number, -- elbow to wrist
	wristToHand: Vector3, -- from the hand part's middle to the wrist, in the hand's space
	restBend: number, -- how far the elbow is folded with its joint at rest
}

-- Reads an arm's lengths off its joints.
function ArmReach.measure(shoulder: Motor6D, elbow: Motor6D, wrist: Motor6D): Arm
	local restBend = elbow.C0:ToEulerAnglesXYZ()
	return {
		upper = (elbow.C0.Position - shoulder.C1.Position).Magnitude,
		fore = (wrist.C0.Position - elbow.C1.Position).Magnitude,
		wristToHand = wrist.C1.Position,
		restBend = restBend,
	}
end

-- base is the shoulder joint's frame on the torso (the torso's frame times the joint's C0). hand is where the
-- hand part should be. elbowWay is roughly which way the elbow should point, all in the same space.
-- Returns the three joints' Transforms. A hand too far away is reached toward with a straight arm.
function ArmReach.solve(arm: Arm, base: CFrame, hand: CFrame, elbowWay: Vector3): (CFrame, CFrame, CFrame)
	local shoulder = base.Position
	local wrist = hand:PointToWorldSpace(arm.wristToHand)
	local reach = wrist - shoulder
	local distance = math.clamp(reach.Magnitude, math.abs(arm.upper - arm.fore) + 0.05, arm.upper + arm.fore - 0.02)
	local along = if reach.Magnitude > 1e-4 then reach.Unit else -base.UpVector
	wrist = shoulder + along * distance

	local inside = math.acos(math.clamp((arm.upper ^ 2 + arm.fore ^ 2 - distance ^ 2) / (2 * arm.upper * arm.fore), -1, 1))
	local bend = math.pi - inside
	local lead = math.acos(math.clamp((arm.upper ^ 2 + distance ^ 2 - arm.fore ^ 2) / (2 * arm.upper * distance), -1, 1))
	local side = elbowWay - along * elbowWay:Dot(along)
	side = if side.Magnitude > 1e-4 then side.Unit else base.RightVector
	local elbow = shoulder + (along * math.cos(lead) + side * math.sin(lead)) * arm.upper

	-- The upper arm's axes: Y up the arm, Z away from the way the forearm folds.
	local up = (shoulder - elbow).Unit
	local fore = (wrist - elbow).Unit
	local folded = fore - up * fore:Dot(up)
	local back = if folded.Magnitude > 1e-4 then -folded.Unit else base.LookVector * -1
	local upper = CFrame.fromMatrix(Vector3.zero, up:Cross(back), up, back)

	local lower = upper * CFrame.Angles(bend, 0, 0)
	return base.Rotation:Inverse() * upper, CFrame.Angles(bend - arm.restBend, 0, 0), lower:Inverse() * hand.Rotation
end

return ArmReach
