-- Bulwark's walls: giant cards standing on their long edge as cover. The part made here is the real wall: it stops
-- bullets (GunServer's firstWall), aimed cards and bodies. It is invisible; each client draws the card itself
-- rising, flinching when hit and breaking (CardWallFx.client.luau), found by the tag.
local CollectionService = game:GetService("CollectionService")

local TAG = "CardWall"

local CardWalls = { TAG = TAG }

local walls: { [Instance]: { hp: number, onBreak: () -> () } } = {}

-- Puts a wall up. frame is the middle of its bottom edge, facing the way its front looks. onBreak runs once if it's
-- shot down.
function CardWalls.place(frame: CFrame, size: Vector3, hp: number, tier: string, owner: Player, onBreak: () -> ()): BasePart
	local wall = Instance.new("Part")
	wall.Name = "Bulwark"
	wall.Size = size
	wall.CFrame = frame * CFrame.new(0, size.Y / 2, 0)
	wall.Anchored = true
	wall.CanCollide = true
	wall.CanQuery = true
	wall.CanTouch = false
	wall.CastShadow = false
	wall.Transparency = 1
	wall:SetAttribute("WallHp", hp)
	wall:SetAttribute("WallMaxHp", hp)
	wall:SetAttribute("Tier", tier)
	wall:SetAttribute("Owner", owner.UserId)
	walls[wall] = { hp = hp, onBreak = onBreak }
	CollectionService:AddTag(wall, TAG)
	wall.Parent = workspace
	return wall
end

-- Takes a wall down, broken or not. Clients tell which from its Broken attribute.
function CardWalls.remove(wall: BasePart)
	walls[wall] = nil
	wall:Destroy()
end

-- Something hit `part` for `amount` damage. Returns true if it was a wall.
function CardWalls.struck(part: Instance, amount: number): boolean
	local wall = walls[part]
	if not wall then
		return false
	end
	wall.hp -= amount
	part:SetAttribute("WallHp", math.max(wall.hp, 0))
	if wall.hp <= 0 then
		walls[part] = nil
		part:SetAttribute("Broken", true)
		wall.onBreak()
	end
	return true
end

return CardWalls
