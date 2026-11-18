-- Which part of the world a player is in. The server sets each player's Zone attribute.
-- The Outpost is a safe zone: guns and cards only work in the test room and on the Relay and Hex maps.
local Zones = {
	Outpost = "Outpost",
	TestRoom = "TestRoom",
	Relay = "Relay",
	Hex = "Hex",
	Yard = "Yard", -- the Elimination arena for 2v2 and 3v3; only ever a match's own copy
}

local KNOWN = {
	[Zones.Outpost] = true,
	[Zones.TestRoom] = true,
	[Zones.Relay] = true,
	[Zones.Hex] = true,
	[Zones.Yard] = true,
}

local COMBAT = {
	[Zones.TestRoom] = true,
	[Zones.Relay] = true,
	[Zones.Hex] = true,
	[Zones.Yard] = true,
}

-- Anything missing or unknown counts as the Outpost, so a late attribute never allows shooting.
function Zones.of(player: any): string
	local zone = player:GetAttribute("Zone")
	if type(zone) == "string" and KNOWN[zone] then
		return zone
	end
	return Zones.Outpost
end

function Zones.allowsCombat(zone: string): boolean
	return COMBAT[zone] == true
end

-- Whether this player may shoot and use cards right now: in a combat zone, and not held at the spawn for a match
-- round's countdown (the server sets MatchFrozen).
function Zones.canFight(player: any): boolean
	return Zones.allowsCombat(Zones.of(player)) and player:GetAttribute("MatchFrozen") ~= true
end

-- The zone for combat keys: the Outpost while combat is held off, so Zones.filter blocks them.
function Zones.combatZone(player: any): string
	return if Zones.canFight(player) then Zones.of(player) else Zones.Outpost
end

-- Makes every combat key false where combat is off.
function Zones.filter(zone: string, keys: { [string]: boolean }): { [string]: boolean }
	if Zones.allowsCombat(zone) then
		return keys
	end
	local blocked = {}
	for key in keys do
		blocked[key] = false
	end
	return blocked
end

function Zones.autoRotates(zone: string): boolean
	return zone == Zones.Outpost
end

-- Everywhere else you wear the game's own body.
function Zones.usesAvatar(zone: string): boolean
	return zone == Zones.Outpost
end

return Zones
