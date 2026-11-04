-- Health and shield rules. All damage passes through here.
local Combat = {}

function Combat.applyDamage(health: number, amount: number): (number, boolean)
	if health <= 0 then
		return health, false
	end
	local remaining = math.max(health - amount, 0)
	return remaining, remaining <= 0
end

-- A shield takes the whole hit. Damage beyond its HP is lost, and an instant kill just breaks it.
function Combat.absorb(shield: number, amount: number): (number, boolean)
	local remaining = math.max(shield - amount, 0)
	return remaining, remaining <= 0
end

return Combat
