-- Client side of shooting: sends aim and firing time. The server decides what happens.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local GunConfig = require(ReplicatedStorage:WaitForChild("Guns"):WaitForChild("GunConfig"))
local GunView = require(script.Parent.GunView)
local Input = require(script.Parent.Input)
local Recoil = require(script.Parent.Recoil)

local remotes = ReplicatedStorage:WaitForChild("GunRemotes")
local fireRemote = remotes:WaitForChild("Fire") :: RemoteEvent
local reloadRemote = remotes:WaitForChild("Reload") :: RemoteEvent
local swapRemote = remotes:WaitForChild("Swap") :: RemoteEvent
local ammoRemote = remotes:WaitForChild("AmmoChanged") :: RemoteEvent

local player = Players.LocalPlayer
local gun: any = nil
local ammo = 0
local reloading = false
local lastFire = -math.huge
local previous = { fire = false, reload = false, primary = false, sidearm = false }

local function isAlive(): boolean
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	return humanoid ~= nil and humanoid.Health > 0
end

local function point(vector: Vector3)
	return { x = vector.X, y = vector.Y, z = vector.Z }
end

local function fire(camera: Camera, aiming: boolean, now: number)
	lastFire = now
	ammo -= 1
	fireRemote:FireServer({
		origin = point(camera.CFrame.Position),
		direction = point(camera.CFrame.LookVector),
		firedAt = workspace:GetServerTimeNow(),
		aiming = aiming,
	})
	Recoil.kick(gun.recoil)
	GunView.kick()
end

local function canFire(pressed: boolean, held: boolean, now: number): boolean
	if not gun or ammo <= 0 or (reloading and not gun.perShell) then
		return false
	end
	if not (pressed or (held and gun.automatic)) then
		return false
	end
	return now - lastFire >= 60 / gun.rpm
end

local function onFrame(dt: number)
	local camera = workspace.CurrentCamera
	Recoil.update(dt, camera)

	if not isAlive() then
		GunView.hide()
		player:SetAttribute("AimFov", nil)
		return
	end

	local keys = Input.readGun()
	local now = os.clock()
	local climbing = player:GetAttribute("Climbing") == true
	local aiming = keys.aim and gun ~= nil and not climbing and not reloading
	player:SetAttribute("AimFov", if aiming then gun.aimFov else nil)

	if keys.primary and not previous.primary then
		swapRemote:FireServer("primary")
	end
	if keys.sidearm and not previous.sidearm then
		swapRemote:FireServer("sidearm")
	end
	if keys.reload and not previous.reload then
		reloadRemote:FireServer()
	end

	local pressed = keys.fire and not previous.fire
	if not climbing then
		if canFire(pressed, keys.fire, now) then
			fire(camera, aiming, now)
		elseif pressed and gun and ammo <= 0 and not reloading then
			reloadRemote:FireServer()
		end
	end

	previous.fire = keys.fire
	previous.reload = keys.reload
	previous.primary = keys.primary
	previous.sidearm = keys.sidearm
	GunView.update(dt, camera, aiming, reloading)
end

ammoRemote.OnClientEvent:Connect(function(info)
	gun = GunConfig.guns[info.gunId]
	ammo = info.ammo
	reloading = info.reloading
	GunView.setSlot(info.slot)
end)

player.CharacterAdded:Connect(function()
	Recoil.reset()
	lastFire = -math.huge
end)

-- Runs after the camera, so recoil and the gun follow where it ended up.
RunService:BindToRenderStep("DeckGuns", Enum.RenderPriority.Camera.Value + 1, onFrame)
