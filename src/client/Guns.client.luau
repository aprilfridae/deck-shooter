-- Client side of shooting: sends aim and firing time. The server decides what happens.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local GunConfig = require(ReplicatedStorage:WaitForChild("Guns"):WaitForChild("GunConfig"))
local GunAudio = require(script.Parent.GunAudio)
local GunView = require(script.Parent.GunView)
local Input = require(script.Parent.Input)
local Recoil = require(script.Parent.Recoil)
local Weapon = require(ReplicatedStorage:WaitForChild("Guns"):WaitForChild("Weapon"))

local remotes = ReplicatedStorage:WaitForChild("GunRemotes")
local fireRemote = remotes:WaitForChild("Fire") :: RemoteEvent
local reloadRemote = remotes:WaitForChild("Reload") :: RemoteEvent
local swapRemote = remotes:WaitForChild("Swap") :: RemoteEvent
local loadoutRemote = remotes:WaitForChild("SetLoadout") :: RemoteEvent

local AMMO_RESYNC_SECONDS = 0.3

local player = Players.LocalPlayer
local gun: any = nil
local ammo = 0
local serverAmmo = 0
local reloading = false
local lastFire = -math.huge
local previous = { fire = false, reload = false, primary = false, sidearm = false, nextClass = false, nextRifle = false }

-- The local count runs ahead while firing. A refused shot is corrected once firing stops.
local function syncGun(now: number)
	local gunId = player:GetAttribute("GunId")
	if not gunId then
		return
	end
	gun = GunConfig.guns[gunId]
	reloading = player:GetAttribute("Reloading") == true
	GunView.setSlot(player:GetAttribute("GunSlot"))
	local latest = player:GetAttribute("Ammo")
	if latest ~= serverAmmo or now - lastFire > AMMO_RESYNC_SECONDS then
		ammo = latest
		serverAmmo = latest
	end
end

local function isAlive(): boolean
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	return humanoid ~= nil and humanoid.Health > 0
end

local function point(vector: Vector3)
	return { x = vector.X, y = vector.Y, z = vector.Z }
end

local function fire(camera: Camera, aiming: boolean, shotTime: number)
	lastFire = shotTime
	ammo -= 1
	local pitch, yaw = Recoil.aimOffset(gun)
	fireRemote:FireServer({
		origin = point(camera.CFrame.Position),
		direction = point((camera.CFrame * CFrame.Angles(pitch, yaw, 0)).LookVector),
		firedAt = shotTime,
		aiming = aiming,
	})
	local gunId = player:GetAttribute("GunId")
	if gun.automatic then
		GunAudio.holdShot(gunId, 1 + (player:GetAttribute("FireRateBonus") or 0))
	else
		GunAudio.playShot(gunId)
	end
	Recoil.kick()
	GunView.kick()
end

local function canShoot(): boolean
	return gun ~= nil and ammo > 0 and not (reloading and not gun.perShell)
end

local function nextShot(pressed: boolean, held: boolean, now: number): number?
	if not canShoot() or not (pressed or (held and gun.automatic)) then
		return nil
	end
	local bonus = player:GetAttribute("FireRateBonus") or 0
	return Weapon.nextShotTime(lastFire, 60 / gun.rpm / (1 + bonus), now)
end

-- Test room only: Phase 4 replaces this with the between-round screen.
local function cycleLoadout(nextClass: boolean, nextRifle: boolean)
	local class = player:GetAttribute("Class")
	local rifle = player:GetAttribute("Rifle")
	if not class or not rifle then
		return
	end
	if nextClass then
		local order = GunConfig.classOrder
		class = order[(table.find(order, class) or 0) % #order + 1]
	end
	if nextRifle then
		local rifles = GunConfig.classes.Assault.primaries
		rifle = rifles[(table.find(rifles, rifle) or 0) % #rifles + 1]
	end
	loadoutRemote:FireServer({ class = class, rifle = rifle })
end

local function onFrame(dt: number)
	local camera = workspace.CurrentCamera
	local pitch, yaw = Recoil.advance(dt)
	camera.CFrame *= CFrame.Angles(pitch, yaw, 0)

	if not isAlive() then
		GunView.hide()
		GunAudio.releaseShot()
		player:SetAttribute("AimFov", nil)
		return
	end

	local keys = Input.readGun()
	local now = workspace:GetServerTimeNow()
	syncGun(now)
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
	local nextClass = keys.nextClass and not previous.nextClass
	local nextRifle = keys.nextRifle and not previous.nextRifle
	if nextClass or nextRifle then
		cycleLoadout(nextClass, nextRifle)
	end

	local pressed = keys.fire and not previous.fire
	if not climbing then
		local shotTime = nextShot(pressed, keys.fire, now)
		if shotTime then
			fire(camera, aiming, shotTime)
		elseif pressed and gun and ammo <= 0 and not reloading then
			reloadRemote:FireServer()
		end
	end

	if not keys.fire or climbing or not canShoot() or not gun.automatic then
		GunAudio.releaseShot()
	end

	previous.fire = keys.fire
	previous.reload = keys.reload
	previous.primary = keys.primary
	previous.sidearm = keys.sidearm
	previous.nextClass = keys.nextClass
	previous.nextRifle = keys.nextRifle
	GunView.update(dt, camera, aiming, reloading)
end

player.CharacterAdded:Connect(function()
	Recoil.reset()
	lastFire = -math.huge
end)

-- Runs after the camera, so recoil and the gun follow where it ended up.
RunService:BindToRenderStep("DeckGuns", Enum.RenderPriority.Camera.Value + 1, onFrame)
