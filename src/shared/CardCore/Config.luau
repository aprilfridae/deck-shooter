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

	StarterDeck = { "phase_dash", "overclock", "recon_pulse" },
}

return Config
