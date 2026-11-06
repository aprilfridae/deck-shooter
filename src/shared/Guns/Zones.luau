-- Which part of the world a player is in. The server sets each player's Zone attribute.
-- The Outpost is a safe zone: guns and cards only work in the test room.
local Zones = {
	Outpost = "Outpost",
	TestRoom = "TestRoom",
}

local COMBAT = {
	[Zones.TestRoom] = true,
}

-- Anything missing or unknown counts as the Outpost, so a late attribute never allows shooting.
function Zones.of(player: any): string
	local zone = player:GetAttribute("Zone")
	if zone == Zones.TestRoom then
		return Zones.TestRoom
	end
	return Zones.Outpost
end

function Zones.allowsCombat(zone: string): boolean
	return COMBAT[zone] == true
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

return Zones
