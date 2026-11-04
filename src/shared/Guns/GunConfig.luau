-- Gun and class data. Times are seconds, distances are studs, spread and recoil are degrees.
-- pattern is the spray: { shots fired, degrees up, degrees sideways } for where bullets land
-- relative to the aim, joined by straight lines. recovery is shots forgiven per second.
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
		spread = 0.2,
		pattern = { { 1, 0.4, 0 }, { 4, 2.2, 0.2 }, { 9, 5.5, 0.6 }, { 14, 6.6, 2 }, { 20, 7.2, -1.8 }, { 26, 7.6, 1.6 }, { 30, 7.8, 0.4 } },
		recovery = 12,
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
		spread = 0.4,
		pattern = { { 1, 0.6, 0 }, { 4, 3.2, 0.3 }, { 10, 8.5, 1 }, { 15, 9.8, 3.2 }, { 21, 10.6, -3 }, { 27, 11.2, 2.6 }, { 30, 11.4, 1 } },
		recovery = 11,
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
		spread = 0.8,
		pattern = { { 1, 0.3, 0 }, { 5, 1.8, 0.4 }, { 10, 3.6, -0.8 }, { 16, 4.4, 1.6 }, { 23, 4.8, -1.6 }, { 32, 5.2, 0.8 } },
		recovery = 16,
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
		spread = 0,
		pattern = { { 1, 7, 0.5 }, { 2, 9, -0.4 } },
		recovery = 1.6,
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
		spread = 4,
		pattern = { { 1, 5, 0.3 }, { 3, 10, -0.6 }, { 6, 12, 0.6 } },
		recovery = 2.5,
	}),
	Pistol = gun({
		name = "Pistol",
		body = 20,
		rpm = 400,
		mag = 12,
		reload = 1.4,
		spread = 0.4,
		pattern = { { 1, 0.9, 0 }, { 4, 3, 0.3 }, { 8, 5, -0.6 }, { 12, 6, 0.5 } },
		recovery = 10,
	}),
	MachinePistol = gun({
		name = "Machine pistol",
		body = 13,
		rpm = 900,
		mag = 20,
		reload = 1.6,
		automatic = true,
		spread = 1,
		pattern = { { 1, 0.4, 0 }, { 5, 2.4, -0.5 }, { 10, 4.4, 1.2 }, { 15, 5, -1.6 }, { 20, 5.4, 0.6 } },
		recovery = 16,
	}),
	Revolver = gun({
		name = "Revolver",
		body = 45,
		rpm = 150,
		mag = 6,
		reload = 2.2,
		spread = 0.3,
		pattern = { { 1, 3, 0.2 }, { 3, 7, -0.5 }, { 6, 10, 0.8 } },
		recovery = 5,
	}),
	AutoPistol = gun({
		name = "Auto-pistol",
		body = 16,
		rpm = 550,
		mag = 15,
		reload = 1.5,
		spread = 0.6,
		pattern = { { 1, 0.5, 0 }, { 4, 2.2, 0.4 }, { 8, 3.8, -0.8 }, { 15, 4.8, 1 } },
		recovery = 13,
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
