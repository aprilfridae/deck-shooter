-- A grey block held in view. Art comes later.
local PRIMARY_SIZE = Vector3.new(0.3, 0.4, 2.4)
local SIDEARM_SIZE = Vector3.new(0.25, 0.35, 1)
local HIP = CFrame.new(0.9, -0.8, -2)
local AIMED = CFrame.new(0, -0.55, -2)
local RELOAD_DIP = CFrame.new(0, -0.7, 0) * CFrame.Angles(math.rad(-25), 0, 0)
local KICK_BACK = 0.25
local EASE = 14

local block: Part? = nil
local held = HIP
local kick = 0

local function makeBlock(): Part
	local part = Instance.new("Part")
	part.Name = "GunView"
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Color = Color3.fromRGB(70, 70, 75)
	part.Size = PRIMARY_SIZE
	return part
end

local GunView = {}

function GunView.setSlot(slot: string)
	block = block or makeBlock()
	block.Size = if slot == "sidearm" then SIDEARM_SIZE else PRIMARY_SIZE
end

function GunView.kick()
	kick = 1
end

function GunView.update(dt: number, camera: Camera, aiming: boolean, reloading: boolean)
	block = block or makeBlock()
	local goal = if aiming then AIMED else HIP
	if reloading then
		goal *= RELOAD_DIP
	end
	local ease = 1 - math.exp(-dt * EASE)
	held = held:Lerp(goal, ease)
	kick *= math.exp(-dt * EASE)
	block.CFrame = camera.CFrame * held * CFrame.new(0, 0, KICK_BACK * kick)
	block.Parent = camera
end

function GunView.hide()
	if block then
		block.Parent = nil
	end
end

return GunView
