-- What a card shows: its letters, names and which of the four looks it takes.
local Variant = require("./Variant")

local CardLook = {}

local MONOGRAMS = {
	phase_dash = "PD",
	overclock = "OC",
	recon_pulse = "RP",
	aegis_shell = "AS",
}
local TIER_NAMES = { Field = "FIELD", BlackSite = "REDLINE", Prototype = "PROTOTYPE" }
local VARIANT_NAMES = {
	[Variant.Chromatic] = "CHROMATIC",
	[Variant.Redacted] = "REDACTED",
	[Variant.ZeroDay] = "ZERO-DAY",
}
local TIER_LOOKS = { Field = "Field", BlackSite = "Redline", Prototype = "Prototype" }
local LONGEST_BESIDE_SET_CODE = 14 -- characters of rarity text that still clear the set code
local SERIAL_DIGITS = 2 -- the big serial's full size holds this many
local LOW_SERIALS = 10
local STUDIO_SERIALS = { phase_dash = 1, overclock = 7, recon_pulse = 42, aegis_shell = 117 }

function CardLook.monogram(cardId: string): string
	return MONOGRAMS[cardId]
end

function CardLook.tierName(tier: string): string
	return TIER_NAMES[tier]
end

function CardLook.rarityText(tier: string, variant: string): string
	local name = VARIANT_NAMES[variant]
	return if name then `{TIER_NAMES[tier]} {name}` else TIER_NAMES[tier]
end

function CardLook.showsSetCode(tier: string, variant: string): boolean
	return #CardLook.rarityText(tier, variant) <= LONGEST_BESIDE_SET_CODE
end

-- Zero-Day looks the same at every tier. Every other card looks like its tier.
function CardLook.look(tier: string, variant: string): string
	return if variant == Variant.ZeroDay then "ZeroDay" else TIER_LOOKS[tier]
end

function CardLook.serialText(serial: number?): string
	return if serial then string.format("%02d", serial) else "--"
end

-- The name as printed on the front: capitals, run together (River, 2026-11-11: "compressed into one word").
function CardLook.faceName(name: string): string
	return (string.gsub(string.upper(name), "%s", ""))
end

-- The rarity as printed on the front: lowercase, tier then variant.
function CardLook.faceRarity(tier: string, variant: string): string
	return string.lower(CardLook.rarityText(tier, variant))
end

-- The serial as printed on the front. Longer numbers show in full.
function CardLook.faceSerial(serial: number?): string
	return if serial then string.format("%04d", serial) else "----"
end

-- Serials 1 to 10 get the big rainbow number.
function CardLook.isLowSerial(serial: number?): boolean
	return serial ~= nil and serial >= 1 and serial <= LOW_SERIALS
end

function CardLook.lowSerialText(serial: number): string
	return string.format("%02d", serial)
end

-- Serials aren't built yet (card-art.md, step 3), so Studio shows these stand-ins to let River judge both the
-- normal and the low look. Delete this when real serials land.
function CardLook.studioSerial(cardId: string): number?
	return STUDIO_SERIALS[cardId]
end

-- The big serial's size for this text, as a share of its size for two digits.
function CardLook.bigSerialSize(text: string): number
	return math.min(1, SERIAL_DIGITS / #text)
end

return CardLook
