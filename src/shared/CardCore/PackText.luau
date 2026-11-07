-- The words on the packs menu and income line. The menu font has no comma or percent sign.
local CardLook = require("./CardLook")
local Packs = require("./Packs")

local SMALLEST_PERCENT = 0.001 -- rarer odds read better as 1 IN N
local PLAIN_BELOW = 10000
local UNITS = { { 1e12, "T" }, { 1e9, "B" }, { 1e6, "M" }, { 1e3, "K" } }

local PackText = {}

function PackText.name(pack: string): string
	return if pack == "ZeroDay" then "ZERO-DAY" else CardLook.tierName(pack)
end

function PackText.odds(chance: number): string
	if chance > 0 and chance < SMALLEST_PERCENT then
		return `1 IN {math.round(1 / chance)}`
	end
	return string.format("%g PCT", math.round(chance * 10000) / 100)
end

-- Three digits at most, rounded down, so a price never reads as met before it is.
local function threeDigits(value: number): string
	local shift = if value >= 100 then 1 elseif value >= 10 then 10 else 100
	return string.format("%g", math.floor(value * shift + 1e-9) / shift)
end

local function short(amount: number): string
	if amount < PLAIN_BELOW then
		return string.format("%g", amount)
	end
	for _, unit in UNITS do
		if amount >= unit[1] then
			return threeDigits(math.min(amount / unit[1], 999)) .. unit[2]
		end
	end
	return string.format("%g", amount)
end

function PackText.income(rate: number): string
	return `+{short(math.round(rate * 10) / 10)} CR/S`
end

function PackText.credits(amount: number): string
	return `{short(amount)} CR`
end

-- Open All's button, counting any purchases waiting for a pile.
function PackText.openAll(saved: number): string
	return if saved > 0 then `OPEN ALL X{saved}` else "OPEN ALL"
end

function PackText.luck(rebirths: number): string
	return string.format("LUCK X%g", math.round(Packs.luck(rebirths) * 100) / 100)
end

return PackText
