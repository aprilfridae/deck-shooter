-- Health rules. All damage passes through here, so the Aegis Shell can join later.
local Combat = {}

function Combat.applyDamage(health: number, amount: number): (number, boolean)
	if health <= 0 then
		return health, false
	end
	local remaining = math.max(health - amount, 0)
	return remaining, remaining <= 0
end

return Combat
