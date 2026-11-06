-- Lays out the stacked lifts of a half-round gable wall inside the vault's shell. Lifts are
-- square-cornered, so each is sized at its top corner: sized any lower, the corners stand
-- proud of the curved roof as a row of teeth.
local LIFT = 2
local CLEARANCE = 0.5 -- how far under the roof's outer face the corners stop

export type Lift = { bottom: number, top: number, half: number }

local Gable = {}

function Gable.lifts(outer: number, inner: number): { Lift }
	local radius = outer - CLEARANCE
	local lifts: { Lift } = {}
	local bottom = 0
	repeat
		local top = bottom + LIFT
		table.insert(lifts, { bottom = bottom, top = top, half = math.sqrt(radius ^ 2 - top ^ 2) })
		bottom = top
	until bottom > inner
	return lifts
end

return Gable
