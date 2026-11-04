-- Decides what an edge in front of the player allows. Pure: the client finds
-- the edge and passes its height above the player's feet.
local MoveConfig = require("./MoveConfig")

export type Kind = "Parry" | "Climb"

local Climb = {}

function Climb.classify(height: number): Kind?
	if height < MoveConfig.ClimbMinHeight or height > MoveConfig.ClimbMaxHeight then
		return nil
	end
	return if height <= MoveConfig.ParryMaxHeight then "Parry" else "Climb"
end

function Climb.isFlat(normalY: number): boolean
	return normalY >= MoveConfig.ClimbMinFlatness
end

-- The upward speed that carries the feet just past the edge.
function Climb.riseSpeed(height: number, gravity: number): number
	return math.sqrt(2 * gravity * (height + MoveConfig.ParryClearance))
end

return Climb
