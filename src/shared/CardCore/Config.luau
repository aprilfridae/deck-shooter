-- Tunable game values. Spec values and plan decisions both live here.
local Config = {
	CopiesToFuse = 5,
	CatalystCopies = 4,
	FusionFee = { Field = 100, BlackSite = 600 },

	TierPower = { Field = 100, BlackSite = 112, Prototype = 125 },
	GunPointsPerLevel = 3,

	IncomePerSecond = { Field = 0.1, BlackSite = 0.6, Prototype = 3.5 },
	SetBonus = 0.10,
	SoftCapCopies = 10,
	SoftCapRate = 0.5,
	MaxTickSeconds = 5,

	VariantIncome = { Base = 1, Chromatic = 1.5, Redacted = 2.5, ZeroDay = 5 },
	VariantOdds = { Chromatic = 1 / 50, Redacted = 1 / 500, ZeroDay = 1 / 5000 },

	-- Perks reach full strength at Prototype.
	PerkPower = { Field = 0.8, BlackSite = 0.9, Prototype = 1 },
	DashSeconds = 0.12,
	DashCamoSeconds = 1.5,
	CamoTransparency = 0.9,
	MoveGraceSeconds = 0.5, -- the movement guard looks away after a push
	DashGraceSeconds = 1, -- and for a dash, until it has ramped back under the speed limit
	PushRadius = 15,
	PushSpeed = 60, -- under the guard's 63 speed limit
	PushRise = 35,
	CooldownSegments = 10,

	StarterDeck = { "phase_dash", "overclock", "recon_pulse" },

	-- Anything above these in a save is corrupt.
	MaxStackCount = 1000000,
	MaxCredits = 2 ^ 53,
	MaxGunLevel = 100,
	DefaultClass = "Assault",
	DefaultRifle = "M4",
	Classes = { Assault = true, Marksman = true },
	Rifles = { M4 = true },
}

return Config
