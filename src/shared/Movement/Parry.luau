-- Decides whether an edge in front of the player can be parried off. Pure: the client finds
-- the edge and passes its height above the player's feet.
local MoveConfig = require("./MoveConfig")

local Parry = {}

function Parry.allows(height: number): boolean
	return height >= MoveConfig.ParryMinHeight and height <= MoveConfig.ParryMaxHeight
end

function Parry.isFlat(normalY: number): boolean
	return normalY >= MoveConfig.ParryMinFlatness
end

-- The upward speed that carries the feet just past the edge.
function Parry.riseSpeed(height: number, gravity: number): number
	return math.sqrt(2 * gravity * (height + MoveConfig.ParryClearance))
end

return Parry
