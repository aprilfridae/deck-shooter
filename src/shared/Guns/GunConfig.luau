-- Gun and class data. magnet is bullet magnetism (see Hitbox.test); guns without it have none. Times are seconds, distances are studs, spread and kick are degrees.
-- kick is how far each shot nudges the view up. It settles straight back, and bullets always go where
-- the crosshair is, so there's no spray to learn.
local SIDEARM_FULL_TO = 40
local SIDEARM_LOW_TO = 90
local SIDEARM_LOW_SCALE = 0.7

local GunConfig = {}

local function gun(fields: { [string]: any }): { [string]: any }
	fields.pellets = fields.pellets or 1
	fields.perShell = fields.perShell == true
	fields.automatic = fields.automatic == true
	fields.collateral = fields.collateral == true -- a bullet through two or more bodies kills them all
	fields.headshot = fields.headshot or "Double"
	fields.fullTo = fields.fullTo or SIDEARM_FULL_TO
	fields.lowTo = fields.lowTo or SIDEARM_LOW_TO
	fields.lowScale = fields.lowScale or SIDEARM_LOW_SCALE
	return fields
end

GunConfig.guns = {
	M4 = gun({
		name = "M57",
		magnet = 2, -- bullet magnetism: a shot this close to a body (studs) is pulled onto it. River's AK only. It was 0.4; River asked for 2
		kick = 0.12,
		body = 24,
		rpm = 600,
		mag = 30,
		reload = 2,
		automatic = true,
		fullTo = 90,
		lowTo = 180,
		lowScale = 0.7,
		spread = 0.2,
	}),
	AK47 = gun({
		name = "B33",
		kick = 0.15,
		body = 24,
		headshot = "Kill",
		rpm = 540,
		mag = 30,
		reload = 0.985,
		automatic = true,
		fullTo = 90,
		lowTo = 180,
		lowScale = 0.7,
		spread = 0.4,
	}),
	SMG = gun({
		name = "SMG",
		kick = 0.08,
		body = 17,
		rpm = 800,
		mag = 32,
		reload = 2.0,
		automatic = true,
		fullTo = 40,
		lowTo = 90,
		lowScale = 0.6,
		spread = 0.8,
	}),
	Sniper = gun({
		name = "Longscope",
		kick = 1.2,
		body = 85,
		headshot = "Kill",
		bodyshot = "Kill", -- one shot anywhere kills
		rpm = 50,
		mag = 1, -- one in the chamber: every shot needs a reload
		autoReload = true, -- starts reloading by itself right after the shot
		collateral = true,
		reload = 1.714,
		fullTo = math.huge,
		lowTo = math.huge,
		lowScale = 1,
		spread = 0,
		aimFov = 18, -- only guns with this can aim down sights
	}),
	Shotgun = gun({
		name = "Shotgun",
		kick = 0.6,
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
	}),
	Pistol = gun({
		name = "Energy Pistol",
		kick = 0.25,
		body = 20,
		rpm = 720, -- as fast as anyone can click. 400 dropped fast clicks and felt unusable to River
		mag = 12,
		reload = 0.964,
		spread = 0.4,
	}),
	MachinePistol = gun({
		name = "Machine pistol",
		kick = 0.06,
		body = 13,
		rpm = 900,
		mag = 20,
		reload = 1.6,
		automatic = true,
		spread = 1,
	}),
	Revolver = gun({
		name = "Revolver",
		kick = 0.5,
		body = 45,
		rpm = 150,
		mag = 6,
		reload = 2.2,
		spread = 0.3,
	}),
	AutoPistol = gun({
		name = "Auto-pistol",
		kick = 0.1,
		body = 16,
		rpm = 550,
		mag = 15,
		reload = 1.5,
		spread = 0.6,
	}),
}

GunConfig.classes = {
	Assault = { primaries = { "M4" }, sidearm = "Pistol" },
	Rusher = { primaries = { "SMG" }, sidearm = "Pistol" },
	Marksman = { primaries = { "Sniper" }, sidearm = "Pistol" },
	Breacher = { primaries = { "Shotgun" }, sidearm = "Pistol" },
}

-- The classes players can pick for now. Rusher, Breacher and the B33 wait in the data.
GunConfig.classOrder = { "Assault", "Marksman" }

return GunConfig
