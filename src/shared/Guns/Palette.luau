-- The game's colours, from the design doc. Red is for threats and purchases only.
local Palette = {
	DeepNavy = Color3.fromRGB(41, 50, 79), -- #29324F panels, backgrounds, dark surfaces
	SignalAcid = Color3.fromRGB(194, 254, 11), -- #C2FE0B primary accent, Prototype tier
	DataCyan = Color3.fromRGB(1, 255, 255), -- #01FFFF readouts, friendly things, Black-Site tier
	FieldGreen = Color3.fromRGB(89, 180, 29), -- #59B41D Field tier, positive states
	HazardRed = Color3.fromRGB(255, 13, 26), -- #FF0D1A enemies, damage, warnings
	Bone = Color3.fromRGB(232, 230, 223), -- #E8E6DF text
}

Palette.Tiers = {
	Field = Palette.FieldGreen,
	BlackSite = Palette.DataCyan,
	Prototype = Palette.SignalAcid,
}

return Palette
