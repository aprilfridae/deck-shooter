-- The words on the back of a card. The menu font has no comma, apostrophe or percent sign.
local Cards = require("./Cards")

local BLURBS = {
	phase_dash = "DASH FORWARD AND TURN NEARLY INVISIBLE",
	overclock = "RAISES FIRE RATE ON BOTH GUNS",
	switchback = "SWAP PLACES WITH THE ENEMY YOU AIM AT",
	kickplate = "BLAST THE GROUND NEAR YOU AND GET THROWN AWAY FROM IT",
	siphon = "A BOLT THAT STEALS SPEED FROM THE ENEMY IT HITS",
	aegis_shell = "A BUBBLE THAT TAKES EVERY HIT THEN PUSHES ENEMIES AWAY",
}

-- The card's stats in the order they're listed, leaving out the cooldown, which always goes last.
local STATS = {
	phase_dash = { { "distance", "DISTANCE", "%g STUDS" } },
	overclock = {
		{ "fireRateBonus", "FIRE RATE", "+%g PCT", 100 },
		{ "duration", "DURATION", "%g S" },
	},
	switchback = { { "range", "RANGE", "%g STUDS" } },
	kickplate = { { "height", "HEIGHT", "%g STUDS" } },
	siphon = {
		{ "speedSteal", "SPEED", "%g PCT", 100 },
		{ "duration", "DURATION", "%g S" },
	},
	aegis_shell = {
		{ "shieldHp", "SHIELD", "%g HP" },
		{ "duration", "DURATION", "%g S" },
	},
}

local CardText = {}

function CardText.blurb(cardId: string): string
	return BLURBS[cardId] or ""
end

function CardText.stats(cardId: string, tier: string): { { label: string, value: string } }
	local stats = {}
	if not STATS[cardId] then
		return stats -- a new card, before its words are written
	end
	for _, stat in STATS[cardId] do
		local key, label, format, scale = stat[1], stat[2], stat[3], stat[4] or 1
		local value = math.round(Cards.stat(cardId, tier, key) * scale * 100) / 100
		table.insert(stats, { label = label, value = string.format(format, value) })
	end
	table.insert(stats, { label = "COOLDOWN", value = string.format("%g S", Cards.cooldown(cardId, tier)) })
	return stats
end

function CardText.copies(count: number): string
	return if count > 0 then `X{count}` else "NOT OWNED"
end

function CardText.wrap(text: string, width: number): { string }
	local lines = {}
	local line = ""
	for _, word in string.split(text, " ") do
		if line ~= "" and #line + 1 + #word > width then
			table.insert(lines, line)
			line = word
		else
			line = if line == "" then word else `{line} {word}`
		end
	end
	table.insert(lines, line)
	return lines
end

return CardText
