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
	PerkPower = { Field = 0.5, BlackSite = 0.75, Prototype = 1 },
	-- Aimed cards (Switchback, Siphon, Kickplate).
	AimWidth = 3, -- studs off the line that still count as a hit
	AimMissCooldown = 4, -- seconds a card that hit nobody takes to come back
	SiphonRange = 120,
	KickplateReach = 14, -- how far away the ground you aim at can be
	KickplateGraceSeconds = 3, -- the movement guard looks away for a launch
	SwitchbackGraceSeconds = 1, -- and for a swap
	DashSeconds = 0.14, -- a dash launches at its distance over this, in studs a second
	DashCamoSeconds = 1.5,
	CamoTransparency = 0.9,
	MoveGraceSeconds = 0.5, -- the movement guard looks away after a push
	DashGraceSeconds = 3, -- and for a dash, until it has ramped back under the speed limit
	PushRadius = 15,
	PushSpeed = 60, -- under the guard's 63 speed limit
	PushRise = 35,
	-- Flashpoint
	FlashRange = 48, -- how far the card is flicked, if nothing stops it first
	FlashSpeed = 110, -- studs a second it flies
	FlashLeast = 0.15, -- seconds: the shortest flight, however close the wall
	FlashRadius = 34, -- enemies further than this from the burst aren't blinded
	FlashFullWithin = 0.5, -- of the radius: closer than this blinds fully, and it falls off to FlashEdge at the radius
	FlashEdge = 0.35,
	-- Bulwark
	WallReach = 16, -- the ground you aim at can be this far away
	WallAhead = 6, -- where it goes, in front of you, when you aim at no ground in reach
	-- A card turned on its side, standing on its long edge (a card is 150 by 240, so 11 by 6.9 keeps its shape).
	WallWidth = 11,
	WallHeight = 6.9,
	WallThick = 0.6,
	-- Split
	DecoyHealth = 40,
	DecoyAhead = 3, -- studs in front of you the copy lands
	DecoyFall = 0.2, -- seconds the copy card falls before the double stands up
	DecoyVanish = 2.5, -- seconds a double that's gone stays in the world for its glitch
	-- Rewind
	RewindSeconds = 3, -- how far back you go
	RewindLeast = 0.5, -- seconds of path needed before there is anywhere to go back to
	RewindLeastDistance = 2, -- studs: closer than this, with no health lost, it isn't used up
	RewindGraceSeconds = 1,

	StarterDeck = { "phase_dash", "overclock", "siphon" },

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
