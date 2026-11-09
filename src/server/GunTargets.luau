-- Everything that can be shot: player characters and the test dummy.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Guns = ReplicatedStorage:WaitForChild("Guns")
local Collision = require(Guns:WaitForChild("Collision"))
local Combat = require(Guns:WaitForChild("Combat"))
local History = require(Guns:WaitForChild("History"))
local Hitbox = require(Guns:WaitForChild("Hitbox"))

local MAX_HEALTH = 100

export type Target = {
	model: Model,
	root: BasePart,
	humanoid: Humanoid,
	player: Player?,
	history: History.History,
	shape: Hitbox.Shape,
	health: number,
	shield: { hp: number, onBreak: () -> () }?,
}

local targets: { [Model]: Target } = {}

local GunTargets = {}

function GunTargets.add(model: Model, player: Player?): Target?
	local root = model:WaitForChild("HumanoidRootPart", 10) :: BasePart?
	local humanoid = model:WaitForChild("Humanoid", 10) :: Humanoid?
	-- A character is not in the workspace yet when CharacterAdded fires.
	local current = if player then player.Character == model else model:IsDescendantOf(workspace)
	if not root or not humanoid or not current then
		return nil
	end

	humanoid.MaxHealth = MAX_HEALTH
	humanoid.Health = MAX_HEALTH
	model:SetAttribute("Health", MAX_HEALTH)

	local target: Target = {
		model = model,
		root = root,
		humanoid = humanoid,
		player = player,
		history = History.new(),
		shape = if model:GetAttribute("SoldierRig") then Hitbox.shapes.soldier else Hitbox.shapes.plain,
		health = MAX_HEALTH,
	}
	targets[model] = target
	model.AncestryChanged:Connect(function()
		if not model:IsDescendantOf(workspace) then
			targets[model] = nil
		end
	end)
	return target
end

function GunTargets.all(): { [Model]: Target }
	return targets
end

function GunTargets.forPlayer(player: Player): Target?
	local model = player.Character
	return if model then targets[model] else nil
end

function GunTargets.isAlive(target: Target): boolean
	return target.health > 0 and target.humanoid.Health > 0 and target.root:IsDescendantOf(workspace)
end

-- Kills the target outright, through any shield. Returns true if it was alive.
function GunTargets.kill(target: Target): boolean
	if not GunTargets.isAlive(target) then
		return false
	end
	local shield = target.shield
	if shield then
		target.shield = nil
		target.model:SetAttribute("ShieldHp", 0)
		shield.onBreak()
	end
	return GunTargets.damage(target, math.max(target.health, 1))
end

-- Returns true if this damage killed the target.
function GunTargets.damage(target: Target, amount: number): boolean
	if not GunTargets.isAlive(target) then
		return false
	end
	local shield = target.shield
	if shield then
		local left, broke = Combat.absorb(shield.hp, amount)
		shield.hp = left
		target.model:SetAttribute("ShieldHp", left)
		if broke then
			target.shield = nil
			shield.onBreak()
		end
		return false
	end
	local health, killed = Combat.applyDamage(target.health, amount)
	target.health = health
	target.model:SetAttribute("Health", health)
	target.humanoid.Health = health
	if killed then
		-- The body's mesh parts only skip the world while the root carries them; once it falls apart they have to
		-- land, or it drops through the floor.
		for _, part in target.model:GetDescendants() do
			if part:IsA("BasePart") then
				part.CollisionGroup = Collision.corpse
				part.CanCollide = true
			end
		end
	end
	return killed
end

return GunTargets
