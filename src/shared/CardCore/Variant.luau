-- Cosmetic variants. They raise income and never affect combat.
local Config = require("./Config")

local Variant = {
	Base = "Base",
	Chromatic = "Chromatic",
	Redacted = "Redacted",
	ZeroDay = "ZeroDay",
	order = { "Base", "Chromatic", "Redacted", "ZeroDay" },
}

function Variant.isValid(variant: any): boolean
	return type(variant) == "string" and Config.VariantIncome[variant] ~= nil
end

function Variant.roll(rng: () -> number): string
	local roll = rng()
	local odds = Config.VariantOdds
	if roll < odds.ZeroDay then
		return Variant.ZeroDay
	elseif roll < odds.ZeroDay + odds.Redacted then
		return Variant.Redacted
	elseif roll < odds.ZeroDay + odds.Redacted + odds.Chromatic then
		return Variant.Chromatic
	end
	return Variant.Base
end

return Variant
