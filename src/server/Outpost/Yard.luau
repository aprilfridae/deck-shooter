-- Yard, the Elimination arena for 2v2 and 3v3 (docs/specs/matches.md: "a smaller arena reused for the team
-- sizes"). A grey blockout, as the spec asks: real art comes later. Each match builds its own copy far from
-- everything else and removes it when the match ends.
--
-- Walled in, 140 by 90 studs. Each side has a spawn bay behind a wall with two ways out, a lane of low cover on
-- each flank, and the middle has a raised block with a ramp toward each side. The two halves are the same,
-- turned half round, so neither team has the better start. Side 1's accents are teal and side 2's orange, the
-- map colours, which also tell the teams apart.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Palette = require(ReplicatedStorage:WaitForChild("Guns"):WaitForChild("Palette"))
local Kit = require(script.Parent.Kit)

local HALF_LONG = 70 -- x
local HALF_WIDE = 45 -- z
local WALL_HEIGHT = 16
local WALL = 2
local FENCE_HEIGHT = 90 -- the unseen fence above the walls
local SPAWN_X = 62
local SPAWN_GAP = 9 -- between a side's spawns, along z
local BAY_WALL_X = 52 -- the wall in front of the spawns
local BAY_GAP = 9 -- the width of each way out of the bay
local MIDDLE = 12 -- half the raised block's size
local MIDDLE_HEIGHT = 5
local RAMP_LENGTH = 14
local LOW = 3.6 -- crouch cover, a little under eye height
local HIGH = 9
local SEED = 4404

local TEAL = Color3.fromRGB(18, 196, 190)
local ORANGE = Color3.fromRGB(255, 132, 28)
local SIDES = { TEAL, ORANGE }

local function v(x: number, y: number, z: number): Vector3
	return Vector3.new(x, y, z)
end

local function strip(kit: any, a: Vector3, b: Vector3, color: Color3)
	local part = kit:box(a, b, color, Enum.Material.Neon)
	Kit.decor(part)
	return part
end

-- One half: everything for the side at -x. Side 2 is the same kit turned half round.
local function half(kit: any, color: Color3): { SpawnLocation }
	local walls = kit:group("Walls")
	-- The long walls along this half, and the end wall behind the spawns.
	walls:boxOf("concrete", v(-HALF_LONG, 0, -HALF_WIDE - WALL), v(0, WALL_HEIGHT, -HALF_WIDE))
	walls:boxOf("concrete", v(-HALF_LONG, 0, HALF_WIDE), v(0, WALL_HEIGHT, HALF_WIDE + WALL))
	walls:boxOf("concrete", v(-HALF_LONG - WALL, 0, -HALF_WIDE - WALL), v(-HALF_LONG, WALL_HEIGHT, HALF_WIDE + WALL))
	strip(walls, v(-HALF_LONG, 1.2, -HALF_WIDE), v(0, 1.6, -HALF_WIDE + 0.2), color)
	strip(walls, v(-HALF_LONG, 1.2, HALF_WIDE - 0.2), v(0, 1.6, HALF_WIDE), color)
	strip(walls, v(-HALF_LONG, 1.2, -HALF_WIDE), v(-HALF_LONG + 0.2, 1.6, HALF_WIDE), color)
	-- An unseen fence on top, so a wall jump can't take anyone out of the arena.
	for _, fence in {
		walls:box(v(-HALF_LONG, WALL_HEIGHT, -HALF_WIDE - WALL), v(0, FENCE_HEIGHT, -HALF_WIDE), color, Enum.Material.SmoothPlastic),
		walls:box(v(-HALF_LONG, WALL_HEIGHT, HALF_WIDE), v(0, FENCE_HEIGHT, HALF_WIDE + WALL), color, Enum.Material.SmoothPlastic),
		walls:box(v(-HALF_LONG - WALL, WALL_HEIGHT, -HALF_WIDE - WALL), v(-HALF_LONG, FENCE_HEIGHT, HALF_WIDE + WALL), color, Enum.Material.SmoothPlastic),
	} do
		fence.Name = "Fence"
		fence.Transparency = 1
		fence.CastShadow = false
		fence.CanQuery = false
	end

	-- The spawn bay: a wall across with two ways out near the flanks, so nobody is shot as they appear.
	local bay = kit:group("Bay")
	local outA, outB = -HALF_WIDE + 8, HALF_WIDE - 8 - BAY_GAP
	bay:boxOf("darkConcrete", v(-BAY_WALL_X - 2, 0, outA + BAY_GAP), v(-BAY_WALL_X, HIGH, outB))
	bay:boxOf("darkConcrete", v(-BAY_WALL_X - 2, 0, -HALF_WIDE), v(-BAY_WALL_X, HIGH, outA))
	bay:boxOf("darkConcrete", v(-BAY_WALL_X - 2, 0, outB + BAY_GAP), v(-BAY_WALL_X, HIGH, HALF_WIDE))
	strip(bay, v(-BAY_WALL_X - 2.2, HIGH - 0.6, outA + BAY_GAP), v(-BAY_WALL_X - 2, HIGH - 0.2, outB), color)

	-- Lanes: low cover to slide behind, and a tall pillar to break the long sightline down each flank.
	local lanes = kit:group("Lanes")
	for _, z in { -30, 30 } do
		lanes:boxOf("concrete", v(-40, 0, z - 4), v(-37, LOW, z + 4))
		lanes:boxOf("concrete", v(-24, 0, z - 2.5), v(-18, HIGH, z + 2.5))
		lanes:boxOf("steel", v(-10, 0, z - 6), v(-7, LOW, z - 1))
	end
	-- Two blocks between the bay and the middle, staggered so there's no straight run to the ramp.
	lanes:boxOf("concrete", v(-36, 0, -9), v(-30, HIGH, -3))
	lanes:boxOf("concrete", v(-30, 0, 5), v(-26, LOW, 13))

	-- This side's ramp up to the middle block.
	local ramp = kit:group("Ramp")
	local rampColor, rampMaterial = ramp:surface("plate")
	ramp:wedge(
		v(8, MIDDLE_HEIGHT, RAMP_LENGTH),
		-- A wedge is low toward its front, so the front faces away from the middle.
		CFrame.new(-MIDDLE - RAMP_LENGTH / 2, MIDDLE_HEIGHT / 2, 0) * CFrame.Angles(0, math.pi / 2, 0),
		rampColor,
		rampMaterial
	)
	strip(ramp, v(-MIDDLE - 0.2, MIDDLE_HEIGHT - 0.1, -4), v(-MIDDLE, MIDDLE_HEIGHT + 0.1, 4), color)

	-- Invisible spawn pads like Hex's: a player's RespawnLocation, facing the middle.
	local spawns = {}
	for index = -1, 1 do
		local at = v(-SPAWN_X, 0, index * SPAWN_GAP)
		local spawn = Instance.new("SpawnLocation")
		spawn.Name = "Spawn"
		spawn.Anchored = true
		spawn.Size = Vector3.new(4, 1, 4)
		spawn.CFrame = kit:frame(CFrame.lookAt(at, v(0, 0, index * SPAWN_GAP))) * CFrame.new(0, -spawn.Size.Y / 2, 0)
		spawn.Transparency = 1
		spawn.CanCollide = false
		spawn.CanQuery = false
		spawn.CanTouch = false
		spawn.Neutral = true
		spawn.Duration = 0
		spawn.Parent = kit.parent
		table.insert(spawns, spawn)
		strip(kit, at - v(1.5, 0, 1.5), at + v(1.5, 0.08, 1.5), color)
	end
	return spawns
end

local Yard = {}

Yard.WALL_HEIGHT = WALL_HEIGHT

-- Builds a copy with its centre at origin. Returns the folder and each side's three spawns.
function Yard.build(origin: CFrame, name: string?): { folder: Folder, spawns: { { SpawnLocation } } }
	local folder = Instance.new("Folder")
	folder.Name = name or "Yard"
	local base = Kit.new(folder, origin, SEED)
	base:boxOf("floor", v(-HALF_LONG - WALL, -2, -HALF_WIDE - WALL), v(HALF_LONG + WALL, 0, HALF_WIDE + WALL))
	local middle = base:group("Middle")
	middle:boxOf("concrete", v(-MIDDLE, 0, -MIDDLE), v(MIDDLE, MIDDLE_HEIGHT, MIDDLE))
	-- A low lip on the middle's open edges, to duck behind up top.
	middle:boxOf("steel", v(-MIDDLE, MIDDLE_HEIGHT, -MIDDLE), v(MIDDLE, MIDDLE_HEIGHT + 2.2, -MIDDLE + 1))
	middle:boxOf("steel", v(-MIDDLE, MIDDLE_HEIGHT, MIDDLE - 1), v(MIDDLE, MIDDLE_HEIGHT + 2.2, MIDDLE))
	-- A light over the middle and one over each half, all white.
	base:lamp(v(0, WALL_HEIGHT + 6, 0), Palette.Bone, 60, 1.4, false, 1)
	local spawns = {}
	for index, color in SIDES do
		local sideFolder = Instance.new("Folder")
		sideFolder.Name = "Side" .. index
		sideFolder.Parent = folder
		local kit = Kit.new(sideFolder, origin * CFrame.Angles(0, (index - 1) * math.pi, 0), SEED + index)
		spawns[index] = half(kit, color)
		-- White light: a coloured one turns the whole half its colour. The strips carry the side's colour.
		kit:lamp(v(-40, WALL_HEIGHT + 4, 0), Palette.Bone, 60, 0.9, false, 1)
	end
	folder.Parent = workspace
	return { folder = folder, spawns = spawns }
end

return Yard
