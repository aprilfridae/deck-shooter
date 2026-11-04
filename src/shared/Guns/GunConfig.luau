-- Gun and class data. Times are seconds, distances are studs, spread and recoil are degrees.
local AIM_FOV = 60
local SIDEARM_FULL_TO = 40
local SIDEARM_LOW_TO = 90
local SIDEARM_LOW_SCALE = 0.7

local GunConfig = {}

local function gun(fields: { [string]: any }): { [string]: any }
	fields.pellets = fields.pellets or 1
	fields.perShell = fields.perShell == true
	fields.automatic = fields.automatic == true
	fields.headshot = fields.headshot or "Double"
	fields.aimFov = fields.aimFov or AIM_FOV
	fields.fullTo = fields.fullTo or SIDEARM_FULL_TO
	fields.lowTo = fields.lowTo or SIDEARM_LOW_TO
	fields.lowScale = fields.lowScale or SIDEARM_LOW_SCALE
	return fields
end

GunConfig.guns = {
	M4 = gun({
		name = "M4",
		body = 24,
		rpm = 600,
		mag = 30,
		reload = 2.2,
		automatic = true,
		fullTo = 90,
		lowTo = 180,
		lowScale = 0.7,
		hipSpread = 1.5,
		aimSpread = 0.2,
		recoil = 0.1,
	}),
	AK47 = gun({
		name = "AK-47",
		body = 24,
		headshot = "Kill",
		rpm = 540,
		mag = 30,
		reload = 2.4,
		automatic = true,
		fullTo = 90,
		lowTo = 180,
		lowScale = 0.7,
		hipSpread = 2,
		aimSpread = 0.4,
		recoil = 1.1,
	}),
	SMG = gun({
		name = "SMG",
		body = 17,
		rpm = 800,
		mag = 32,
		reload = 2.0,
		automatic = true,
		fullTo = 40,
		lowTo = 90,
		lowScale = 0.6,
		hipSpread = 2,
		aimSpread = 0.8,
		recoil = 0.35,
	}),
	Sniper = gun({
		name = "Sniper",
		body = 85,
		headshot = "Kill",
		rpm = 50,
		mag = 5,
		reload = 3.0,
		fullTo = math.huge,
		lowTo = math.huge,
		lowScale = 1,
		hipSpread = 7,
		aimSpread = 0,
		recoil = 5,
		aimFov = 30,
	}),
	Shotgun = gun({
		name = "Shotgun",
		body = 14,
		pellets = 8,
		rpm = 75,
		mag = 6,
		reload = 0.5,
		perShell = true,
		fullTo = 15,
		lowTo = 45,
		lowScale = 0,
		hipSpread = 5,
		aimSpread = 4,
		recoil = 4,
	}),
	Pistol = gun({
		name = "Pistol",
		body = 20,
		rpm = 400,
		mag = 12,
		reload = 1.4,
		hipSpread = 1.5,
		aimSpread = 0.4,
		recoil = 0.6,
	}),
	MachinePistol = gun({
		name = "Machine pistol",
		body = 13,
		rpm = 900,
		mag = 20,
		reload = 1.6,
		automatic = true,
		hipSpread = 2.5,
		aimSpread = 1,
		recoil = 0.4,
	}),
	Revolver = gun({
		name = "Revolver",
		body = 45,
		rpm = 150,
		mag = 6,
		reload = 2.2,
		hipSpread = 2,
		aimSpread = 0.3,
		recoil = 2.5,
	}),
	AutoPistol = gun({
		name = "Auto-pistol",
		body = 16,
		rpm = 550,
		mag = 15,
		reload = 1.5,
		hipSpread = 1.8,
		aimSpread = 0.6,
		recoil = 0.5,
	}),
}

GunConfig.classes = {
	Assault = { primaries = { "M4", "AK47" }, sidearm = "Pistol" },
	Rusher = { primaries = { "SMG" }, sidearm = "MachinePistol" },
	Marksman = { primaries = { "Sniper" }, sidearm = "Revolver" },
	Breacher = { primaries = { "Shotgun" }, sidearm = "AutoPistol" },
}

GunConfig.classOrder = { "Assault", "Rusher", "Marksman", "Breacher" }

return GunConfig
