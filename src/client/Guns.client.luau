-- Client side of shooting: sends aim and firing time. The server decides what happens.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local CardHand = require(ReplicatedStorage:WaitForChild("CardCore"):WaitForChild("CardHand"))
local CameraSmooth = require(script.Parent.CameraSmooth)
local CardInHand = require(script.Parent.CardInHand)
local GunConfig = require(ReplicatedStorage:WaitForChild("Guns"):WaitForChild("GunConfig"))
local GunAudio = require(script.Parent.GunAudio)
local GunView = require(script.Parent.GunView)
local Input = require(script.Parent.Input)
local Recoil = require(script.Parent.Recoil)
local Weapon = require(ReplicatedStorage:WaitForChild("Guns"):WaitForChild("Weapon"))
local Zones = require(ReplicatedStorage:WaitForChild("Guns"):WaitForChild("Zones"))

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
local AUTO_RELOAD_DELAY = 0.12 -- lets the shot's kick land before an auto reload starts
local autoReloadAsked = false
-- Swaps show at once, before the server answers: the gun last seen in each slot, and the slot asked for.
local SWAP_WAIT = 1 -- seconds to wait for the server before showing its gun again
local slotGuns: { [string]: string } = {}
local pendingSlot: string? = nil
local pendingAt = 0
local shownGunId: string? = nil
local previous = { fire = false, reload = false, primary = false, sidearm = false, nextClass = false, nextRifle = false }

-- The local count runs ahead while firing. A refused shot is corrected once firing stops.
local function syncGun(now: number)
	local gunId = player:GetAttribute("GunId")
	if not gunId then
		return
	end
	gun = GunConfig.guns[gunId]
	local wasReloading = reloading
	reloading = player:GetAttribute("Reloading") == true
	if reloading and not wasReloading then
		GunAudio.playReload(gunId)
	end
	local serverSlot = player:GetAttribute("GunSlot")
	local class = player:GetAttribute("Class") or ""
	if serverSlot then
		slotGuns[class .. serverSlot] = gunId
	end
	local showId, showSlot = gunId, serverSlot
	if pendingSlot then
		if serverSlot == pendingSlot or now - pendingAt > SWAP_WAIT then
			pendingSlot = nil
		else
			local classInfo = GunConfig.classes[class]
			local guess = slotGuns[class .. pendingSlot]
				or (pendingSlot == "sidearm" and classInfo and classInfo.sidearm)
				or nil
			if guess then
				showId, showSlot = guess, pendingSlot
			end
		end
	end
	if showId ~= shownGunId then
		-- The old gun's shots and reload fade out, so they don't ring on over the new one.
		GunAudio.fadeGuns(showId)
		shownGunId = showId
	end
	GunView.setGun(showId, showSlot)
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
	GunAudio.playShot(player:GetAttribute("GunId"), workspace:GetServerTimeNow() - shotTime)
	Recoil.kick()
	GunView.kick()
end

local function canShoot(): boolean
	-- Not mid-swap: the server still has the old gun out.
	return gun ~= nil and ammo > 0 and not (reloading and not gun.perShell) and pendingSlot == nil
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
	CameraSmooth.apply(dt, camera) -- first, so the gun is drawn from the smoothed camera
	local pitch, yaw = Recoil.advance(dt)
	camera.CFrame *= CFrame.Angles(pitch, yaw, 0)

	-- Dead, or in the Outpost where guns are put away.
	if not isAlive() or not Zones.allowsCombat(Zones.of(player)) then
		GunView.hide()
		player:SetAttribute("AimFov", nil)
		CardHand.putAway(CardInHand)
		return
	end

	local keys = Input.readGun()
	local now = workspace:GetServerTimeNow()
	syncGun(now)
	local cardOut = CardInHand.slot ~= nil
	-- A scoped shot drops the scope until the bolt is worked. Still holding aim scopes back in.
	local cycling = gun ~= nil and now < lastFire + 60 / gun.rpm
	local aiming = keys.aim and gun ~= nil and gun.aimFov ~= nil and not reloading and not cardOut and not cycling
	player:SetAttribute("AimFov", if aiming then gun.aimFov else nil)

	for _, slot in { "primary", "sidearm" } do
		if keys[slot] and not previous[slot] then
			CardHand.putAway(CardInHand)
			swapRemote:FireServer(slot)
			if player:GetAttribute("GunSlot") ~= slot then
				pendingSlot, pendingAt = slot, now
			else
				pendingSlot = nil
			end
		end
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
	if not CardHand.blocksFire(CardInHand, keys.fire) then
		local shotTime = nextShot(pressed, keys.fire, now)
		if shotTime then
			fire(camera, aiming, shotTime)
		elseif pressed and gun and ammo <= 0 and not reloading then
			reloadRemote:FireServer()
		end
	end

	-- A gun that reloads itself asks once, just after the shot that emptied it.
	if gun and gun.autoReload and ammo <= 0 and not reloading and now - lastFire >= AUTO_RELOAD_DELAY then
		if not autoReloadAsked then
			autoReloadAsked = true
			reloadRemote:FireServer()
		end
	elseif reloading or ammo > 0 then
		autoReloadAsked = false
	end

	previous.fire = keys.fire
	previous.reload = keys.reload
	previous.primary = keys.primary
	previous.sidearm = keys.sidearm
	previous.nextClass = keys.nextClass
	previous.nextRifle = keys.nextRifle
	GunView.update(dt, camera, aiming, reloading, player:GetAttribute("MoveMode") == "Sprint", CardInHand.slot ~= nil)
end

player.CharacterAdded:Connect(function()
	Recoil.reset()
	lastFire = -math.huge
end)

-- Runs after the camera, so recoil and the gun follow where it ended up.
RunService:BindToRenderStep("DeckGuns", Enum.RenderPriority.Camera.Value + 1, onFrame)
