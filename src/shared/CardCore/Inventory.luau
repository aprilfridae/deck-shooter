-- Card stacks in save data, keyed "cardId:tier:variant".
local Inventory = {}

function Inventory.key(cardId: string, tier: string, variant: string): string
	return `{cardId}:{tier}:{variant}`
end

function Inventory.parse(key: string): (string?, string?, string?)
	local cardId, tier, variant = string.match(key, "^([^:]+):([^:]+):([^:]+)$")
	return cardId, tier, variant
end

function Inventory.count(data: any, cardId: string, tier: string, variant: string?): number
	if variant then
		return data.stacks[Inventory.key(cardId, tier, variant)] or 0
	end
	local total = 0
	for key, n in data.stacks do
		local stackCard, stackTier = Inventory.parse(key)
		if stackCard == cardId and stackTier == tier then
			total += n
		end
	end
	return total
end

function Inventory.add(data: any, cardId: string, tier: string, variant: string, n: number)
	local key = Inventory.key(cardId, tier, variant)
	data.stacks[key] = (data.stacks[key] or 0) + n
end

function Inventory.remove(data: any, cardId: string, tier: string, variant: string, n: number): boolean
	local key = Inventory.key(cardId, tier, variant)
	local have = data.stacks[key] or 0
	if have < n then
		return false
	end
	data.stacks[key] = if have == n then nil else have - n
	return true
end

function Inventory.ownsCard(data: any, cardId: string): boolean
	for key in data.stacks do
		if Inventory.parse(key) == cardId then
			return true
		end
	end
	return false
end

return Inventory
