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

	GroupId = 237720778, -- Fridae Studios
	OpenAllProduct = 0, -- the developer product, 0 until River creates it
	AutoOpenPass = 0, -- the gamepass, 0 until River creates it
	RebirthPrice = 25000,
	RebirthGrowth = 2.5,
	LuckPerRebirth = 0.15,
	ReceiptMemory = 50, -- purchases each save remembers, so a repeated receipt opens nothing
	PackOdds = { BlackSite = 0.16, Prototype = 0.0398, ZeroDay = 0.0002 }, -- Field takes the rest
	-- Tier chances, commonest first. A Zero-Day pack's first card differs from its other two.
	PackTierOdds = {
		Field = { { "Field", 0.9 }, { "BlackSite", 0.09 }, { "Prototype", 0.01 } },
		BlackSite = { { "BlackSite", 0.88 }, { "Prototype", 0.12 } },
		Prototype = { { "Prototype", 1 } },
		ZeroDay = { { "BlackSite", 0.6 }, { "Prototype", 0.4 } },
		ZeroDayFirst = { { "Field", 0.6 }, { "BlackSite", 0.3 }, { "Prototype", 0.1 } },
	},
	PackVariantOdds = { Prototype = 0.05 }, -- the Zero-Day variant, or else VariantOdds.ZeroDay

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
