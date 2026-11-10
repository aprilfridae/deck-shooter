-- Free-for-all spawning: the spawn furthest from everyone else, so nobody appears in front of a gun.
local SpawnPick = {}

-- Anything with X, Y and Z: a Vector3 in the game, a plain table in tests.
type Point = { X: number, Y: number, Z: number } | Vector3

local function distance(a: any, b: any): number
	local dx, dy, dz = a.X - b.X, a.Y - b.Y, a.Z - b.Z
	return math.sqrt(dx * dx + dy * dy + dz * dz)
end

-- spawns and others are positions. Returns the index of the spawn whose nearest other player is furthest away.
-- With nobody else there, or ties, roll picks among the best (roll(n) returns 1..n).
function SpawnPick.farthest(spawns: { Point }, others: { Point }, roll: (number) -> number): number
	if #others == 0 then
		return roll(#spawns)
	end
	local best, bestDistance = {}, -1
	for index, spawn in spawns do
		local nearest = math.huge
		for _, other in others do
			nearest = math.min(nearest, distance(spawn, other))
		end
		if nearest > bestDistance + 0.5 then
			best, bestDistance = { index }, nearest
		elseif math.abs(nearest - bestDistance) <= 0.5 then
			table.insert(best, index)
		end
	end
	return best[roll(#best)]
end

return SpawnPick
