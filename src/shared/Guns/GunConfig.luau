-- Gun and class data. Times are seconds, distances are studs, spread and recoil are degrees.
-- pattern is the spray: { shots fired, degrees up, degrees sideways } for where bullets land
-- relative to the aim, joined by straight lines. recovery is shots forgiven per second.
-- Automatics climb nearly straight for a third of the magazine, then sweep side to side.
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
		pattern = {
			{ 1, 0.3, 0 },
			{ 2, 0.8, 0 },
			{ 4, 2.1, 0.1 },
			{ 7, 4, 0.2 },
			{ 10, 5, 0.3 },
			{ 12, 5.2, 0.9 },
			{ 15, 5.4, 1.6 },
			{ 17, 5.3, 1.2 },
			{ 19, 5.4, 0 },
			{ 22, 5.5, -1.6 },
			{ 24, 5.4, -1.2 },
			{ 26, 5.5, 0 },
			{ 28, 5.5, 1 },
			{ 30, 5.5, 1.2 },
		},
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
		pattern = {
			{ 1, 0.4, 0 },
			{ 2, 1.2, 0.05 },
			{ 4, 3, 0.2 },
			{ 7, 5.6, 0.4 },
			{ 10, 7.2, 0.6 },
			{ 12, 7.6, 1.4 },
			{ 15, 7.8, 2.6 },
			{ 17, 7.6, 2.1 },
			{ 19, 7.7, 0 },
			{ 22, 7.9, -2.6 },
			{ 24, 7.8, -2.1 },
			{ 26, 8, 0 },
			{ 28, 8, 1.9 },
			{ 30, 8, 2.2 },
		},
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
		pattern = {
			{ 1, 0.2, 0 },
			{ 3, 0.9, 0.05 },
			{ 6, 2.1, 0.15 },
			{ 10, 3.1, 0.3 },
			{ 13, 3.3, 0.8 },
			{ 16, 3.4, 1.3 },
			{ 18, 3.4, 0.9 },
			{ 20, 3.5, 0 },
			{ 24, 3.6, -1.3 },
			{ 26, 3.6, -0.9 },
			{ 29, 3.7, 0.3 },
			{ 32, 3.7, 1 },
		},
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
		hipSpread = 7,
		pattern = { { 1, 5, 0.4 }, { 2, 6.4, -0.3 } },
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
		pattern = { { 1, 3.5, 0.2 }, { 3, 7, -0.4 }, { 6, 8.4, 0.4 } },
		recovery = 2.5,
	}),
	Pistol = gun({
		name = "Pistol",
		body = 20,
		rpm = 400,
		mag = 12,
		reload = 1.4,
		spread = 0.4,
		pattern = { { 1, 0.6, 0 }, { 4, 2.1, 0.1 }, { 8, 3.5, 0.2 }, { 12, 4.2, -0.45 } },
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
		pattern = {
			{ 1, 0.3, 0 },
			{ 3, 1.1, -0.05 },
			{ 6, 2.8, -0.2 },
			{ 8, 3.4, -0.7 },
			{ 10, 3.6, -1.3 },
			{ 13, 3.7, 0 },
			{ 16, 3.8, 1.3 },
			{ 18, 3.8, 0.9 },
			{ 20, 3.8, 0.5 },
		},
		recovery = 16,
	}),
	Revolver = gun({
		name = "Revolver",
		body = 45,
		rpm = 150,
		mag = 6,
		reload = 2.2,
		spread = 0.3,
		pattern = { { 1, 2.1, 0.15 }, { 3, 4.9, -0.4 }, { 6, 7, 0.6 } },
		recovery = 5,
	}),
	AutoPistol = gun({
		name = "Auto-pistol",
		body = 16,
		rpm = 550,
		mag = 15,
		reload = 1.5,
		spread = 0.6,
		pattern = { { 1, 0.35, 0 }, { 4, 1.5, 0.1 }, { 8, 2.7, 0.2 }, { 15, 3.4, 0.7 } },
		recovery = 13,
	}),
}

GunConfig.classes = {
	Assault = { primaries = { "M4", "AK47" }, sidearm = "Pistol" },
	Rusher = { primaries = { "SMG" }, sidearm = "Pistol" },
	Marksman = { primaries = { "Sniper" }, sidearm = "Pistol" },
	Breacher = { primaries = { "Shotgun" }, sidearm = "Pistol" },
}

GunConfig.classOrder = { "Assault", "Rusher", "Marksman", "Breacher" }

return GunConfig
