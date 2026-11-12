-- The game's colours, from the design doc. Red is for threats and purchases only.
local Palette = {
	DeepNavy = Color3.fromRGB(41, 50, 79), -- #29324F panels, backgrounds, dark surfaces
	SignalAcid = Color3.fromRGB(194, 254, 11), -- #C2FE0B primary accent, Prototype tier
	DataCyan = Color3.fromRGB(1, 255, 255), -- #01FFFF readouts, friendly things, Zero-Day cards
	FieldGreen = Color3.fromRGB(89, 180, 29), -- #59B41D Field tier, positive states
	HazardRed = Color3.fromRGB(255, 13, 26), -- #FF0D1A enemies, damage, warnings, Redline cards
	Bone = Color3.fromRGB(232, 230, 223), -- #E8E6DF text
	-- A motion blur copy's colour, like the Outpost's trail: white (Bone) right behind the thing, running to blue
	-- (Deep Navy) at the far end. near is 1 for the copy nearest the thing and 0 for the furthest.
	blur = function(near: number): Color3
		-- It turns blue close in: only the first copy or two are white, and it's most of the way to blue by a third
		-- of the way back.
		return Color3.fromRGB(41, 50, 79):Lerp(Color3.fromRGB(232, 230, 223), math.clamp(near, 0, 1) ^ 3)
	end,
	ZeroDayBack = Color3.fromRGB(14, 16, 24), -- #0E1018 Zero-Day cards only
}

Palette.Tiers = {
	Field = Palette.DeepNavy,
	BlackSite = Palette.HazardRed,
	Prototype = Palette.SignalAcid,
}

return Palette
