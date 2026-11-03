-- Rarity tiers, lowest to highest.
local Tier = {
	Field = "Field",
	BlackSite = "BlackSite",
	Prototype = "Prototype",
	order = { "Field", "BlackSite", "Prototype" },
}

local indexOf: { [string]: number } = {}
for i, name in Tier.order do
	indexOf[name] = i
end

function Tier.index(tier: string): number?
	return indexOf[tier]
end

function Tier.next(tier: string): string?
	local i = indexOf[tier]
	return if i then Tier.order[i + 1] else nil
end

function Tier.isValid(tier: any): boolean
	return type(tier) == "string" and indexOf[tier] ~= nil
end

return Tier
