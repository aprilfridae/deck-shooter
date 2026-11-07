-- Which third-person gun pose a body shows. Pure: the caller passes what every client can see about the body.
-- Poses are the names in BodyPoses (Stand, Walk_Contact, ...). Moving poses step through a four-beat stride
-- (contact, pass, then both again with the legs swapped) one beat per stride length of ground covered.
local GunStance = {}

GunStance.landTime = 0.25 -- seconds the landing pose holds
GunStance.fireTime = 0.17 -- about two held frames at 12 fps
GunStance.moving = 1 -- studs per second; slower than this counts as standing
GunStance.sprinting = 20 -- walk is 16, sprint 24
GunStance.rising = 2 -- vertical studs per second that counts as still going up
GunStance.stride = { walk = 3, sprint = 4.5, crouch = 2 } -- studs of ground per beat

export type Input = {
	reloading: boolean,
	pose: string?, -- the character's MovePose: Normal, Crouch or Slide
	airborne: boolean,
	verticalSpeed: number,
	flatSpeed: number,
	sinceLanded: number,
	sinceShot: number,
	travel: number, -- studs of ground covered so far, for the stride
}
export type Pick = { name: string, mirrored: boolean }

local function beat(travel: number, length: number): number
	return math.floor(travel / length) % 4
end

-- A two-pose stride: contact, pass, contact with the legs swapped, pass with the legs swapped.
local function stride(contact: string, pass: string, travel: number, length: number): Pick
	local index = beat(travel, length)
	return { name = if index % 2 == 0 then contact else pass, mirrored = index >= 2 }
end

function GunStance.pick(input: Input): Pick
	if input.reloading then
		return { name = "Reload", mirrored = false }
	end
	if input.pose == "Slide" then
		return { name = "Slide", mirrored = false }
	end
	if input.airborne then
		return { name = if input.verticalSpeed > GunStance.rising then "Jump_Up" else "Fall", mirrored = false }
	end
	if input.sinceLanded < GunStance.landTime then
		return { name = "Land", mirrored = false }
	end
	if input.sinceShot < GunStance.fireTime then
		return { name = "Fire", mirrored = false }
	end
	local moving = input.flatSpeed > GunStance.moving
	if input.pose == "Crouch" then
		if moving then
			return stride("Crouch_Walk", "Crouch_Idle", input.travel, GunStance.stride.crouch)
		end
		return { name = "Crouch_Idle", mirrored = false }
	end
	if input.flatSpeed >= GunStance.sprinting then
		return stride("Sprint_Contact", "Sprint_Pass", input.travel, GunStance.stride.sprint)
	end
	if moving then
		return stride("Walk_Contact", "Walk_Pass", input.travel, GunStance.stride.walk)
	end
	return { name = "Stand", mirrored = false }
end

-- The legs' joints, with the joint each one swaps with.
GunStance.legSwap = {
	RightHip = "LeftHip",
	RightKnee = "LeftKnee",
	RightAnkle = "LeftAnkle",
	LeftHip = "RightHip",
	LeftKnee = "RightKnee",
	LeftAnkle = "RightAnkle",
}

-- A joint's { x, y, z, qx, qy, qz, qw } seen in a mirror across the body's middle: left becomes right.
function GunStance.mirror(value: { number }): { number }
	return { -value[1], value[2], value[3], value[4], -value[5], -value[6], value[7] }
end

return GunStance
