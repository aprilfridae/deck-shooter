-- Damage for one hit, or one pellet. Pure.
local Damage = {
	KILL = math.huge,
}

function Damage.rangeScale(gun: any, distance: number): number
	if distance <= gun.fullTo then
		return 1
	elseif distance >= gun.lowTo then
		return gun.lowScale
	end
	local alpha = (distance - gun.fullTo) / (gun.lowTo - gun.fullTo)
	return 1 + (gun.lowScale - 1) * alpha
end

function Damage.hit(gun: any, distance: number, isHead: boolean): number
	if isHead and gun.headshot == "Kill" then
		return Damage.KILL
	end
	local amount = gun.body * Damage.rangeScale(gun, distance)
	return if isHead then amount * 2 else amount
end

return Damage
