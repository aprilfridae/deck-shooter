-- The gun each soldier body holds in third person, placed where its gun pose puts the hand's gun.
-- PoseGun builds the model and moves the magazine and the charging handle (or pump) in the poses that move them.
local PoseGun = require(script.Parent.PoseGun)

local HeldGuns = {}

export type Value = PoseGun.Value
export type Pose = { gunOn: string?, gun: Value?, mag: Value?, action: Value?, [string]: any }
export type Poses = {
	gunScale: number?,
	parts: { PoseGun.PartBox },
	poses: { [string]: Pose },
}

local folder = Instance.new("Folder")
folder.Name = "HeldGuns"
folder.Parent = workspace

local held: { [Model]: PoseGun.Gun } = {}

HeldGuns.frame = PoseGun.frame

local function build(name: string, poses: Poses): PoseGun.Gun?
	local stand = poses.poses.Stand or {}
	return PoseGun.build(name, poses.parts, PoseGun.frame(stand.mag), PoseGun.frame(stand.action))
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
		return
	end
	local handle = holder.CFrame * PoseGun.frame(pose.gun)
	PoseGun.place(current, handle, PoseGun.frame(pose.mag), PoseGun.frame(pose.action), folder)
end

function HeldGuns.remove(character: Model)
	local current = held[character]
	if current then
		current.model:Destroy()
		held[character] = nil
	end
end

return HeldGuns
