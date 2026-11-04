-- Ammo, fire rate and reloading for a player's two guns. Pure: the caller supplies the time.
local GunConfig = require("./GunConfig")

local FIRE_RATE_TOLERANCE = 0.05 -- share of the interval, for network timing
local SHOT_CATCH_UP_SECONDS = 0.05 -- later than this, a shot starts a new rhythm

export type Slot = {
	gunId: string,
	gun: any,
	ammo: number,
	lastShot: number,
	reloadDoneAt: number?,
}
export type Loadout = {
	slots: { primary: Slot, sidearm: Slot },
	active: string,
	fireRateBonus: number,
}

local Weapon = {}

local function newSlot(gunId: string): Slot
	local gun = GunConfig.guns[gunId]
	return { gunId = gunId, gun = gun, ammo = gun.mag, lastShot = -math.huge, reloadDoneAt = nil }
end

-- True when neither gun has been fired, so changing loadout gives nothing away.
function Weapon.isUntouched(loadout: Loadout): boolean
	for _, slot in { loadout.slots.primary, loadout.slots.sidearm } do
		if slot.ammo < slot.gun.mag or slot.reloadDoneAt then
			return false
		end
	end
	return true
end

function Weapon.newLoadout(class: string, rifle: string?): Loadout
	local guns = GunConfig.classes[class]
	local primary = if rifle and table.find(guns.primaries, rifle) then rifle else guns.primaries[1]
	return {
		slots = { primary = newSlot(primary), sidearm = newSlot(guns.sidearm) },
		active = "primary",
		fireRateBonus = 0,
	}
end

local function activeSlot(loadout: Loadout): Slot
	return (loadout.slots :: any)[loadout.active]
end

function Weapon.active(loadout: Loadout): Slot
	return activeSlot(loadout)
end

function Weapon.ammo(loadout: Loadout): number
	return activeSlot(loadout).ammo
end

local function finishReload(slot: Slot, now: number)
	local doneAt = slot.reloadDoneAt
	while doneAt and now >= doneAt do
		if slot.gun.perShell then
			slot.ammo += 1
			doneAt = if slot.ammo < slot.gun.mag then doneAt + slot.gun.reload else nil
		else
			slot.ammo = slot.gun.mag
			doneAt = nil
		end
	end
	slot.reloadDoneAt = doneAt
end

function Weapon.update(loadout: Loadout, now: number)
	finishReload(activeSlot(loadout), now)
end

-- Frames rarely land on the exact moment a gun is ready. Counting from when the shot was due,
-- not from the frame that fired it, keeps the rhythm even.
function Weapon.nextShotTime(lastShot: number, interval: number, now: number): number?
	local due = lastShot + interval
	if now < due then
		return nil
	end
	return if now - due > SHOT_CATCH_UP_SECONDS then now else due
end

function Weapon.tryFire(loadout: Loadout, now: number): boolean
	Weapon.update(loadout, now)
	local slot = activeSlot(loadout)
	if slot.ammo <= 0 or (slot.reloadDoneAt and not slot.gun.perShell) then
		return false
	end
	local interval = 60 / slot.gun.rpm / (1 + loadout.fireRateBonus)
	if now - slot.lastShot < interval * (1 - FIRE_RATE_TOLERANCE) then
		return false
	end
	slot.reloadDoneAt = nil
	slot.lastShot = now
	slot.ammo -= 1
	return true
end

function Weapon.startReload(loadout: Loadout, now: number): boolean
	Weapon.update(loadout, now)
	local slot = activeSlot(loadout)
	if slot.reloadDoneAt or slot.ammo >= slot.gun.mag then
		return false
	end
	slot.reloadDoneAt = now + slot.gun.reload
	return true
end

function Weapon.swap(loadout: Loadout, slotName: string, now: number): boolean
	if (slotName ~= "primary" and slotName ~= "sidearm") or slotName == loadout.active then
		return false
	end
	Weapon.update(loadout, now)
	activeSlot(loadout).reloadDoneAt = nil
	loadout.active = slotName
	return true
end

function Weapon.refill(loadout: Loadout)
	for _, slot in loadout.slots :: any do
		slot.ammo = slot.gun.mag
		slot.reloadDoneAt = nil
		slot.lastShot = -math.huge
	end
end

return Weapon
