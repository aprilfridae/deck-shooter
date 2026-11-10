-- Junction: the free-for-all arena. A walled square about 190 studs across, small enough that a fight is never
-- far. A raised hub sits in the middle, reached by four ramps laid like a pinwheel, and a block house stands in
-- each corner with a ramp to its roof and a sloping catwalk from the roof down to the hub. Between them is
-- cover at three heights: low walls to crouch behind, crate stacks, a jump-up block, and a pair of tall walls
-- close enough to wall jump between. Each corner has its own colour so players can call out where they are.
-- Grey box for now: shapes and flow first, textures later. See docs/specs/junction.md.
-- The map has four-way symmetry. One quarter is built, then the same build runs turned a quarter round
-- each time. Quarter axes: this quarter's corner house is toward +X +Z.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Guns = ReplicatedStorage:WaitForChild("Guns")
local Palette = require(Guns:WaitForChild("Palette"))
local Kit = require(script.Parent.Kit)
local Relay = require(script.Parent.Relay)

local M = Enum.Material

local SEED = 77
local HALF = 96 -- inside of the outer wall, from the centre
local OUTER_HEIGHT = 26
local HUB = 12 -- half the hub's width
local HUB_TOP = 7
local HOUSE = 64 -- the corner house's inner faces, along X and Z
local HOUSE_TOP = 12 -- its roof's top
local T = 1 -- wall thickness

-- Each quarter's colour, in build order.
local CORNERS = { Palette.DataCyan, Palette.SignalAcid, Palette.HazardRed, Palette.FieldGreen }
local GREY = Color3.fromRGB(150, 152, 158)
local LIGHT = Color3.fromRGB(184, 186, 190)
local DARK = Palette.DeepNavy

local function v(x: number, y: number, z: number): Vector3
	return Vector3.new(x, y, z)
end

-- A ramp from low to high: its foot at low, its top edge at high, width wide across it. low and high share Y
-- only at their own heights; the ramp runs along the line between them on the ground.
local function ramp(g, low: Vector3, high: Vector3, wide: number, color: Color3)
	local flat = v(high.X - low.X, 0, high.Z - low.Z)
	local rise = high.Y - low.Y
	local middle = v((low.X + high.X) / 2, low.Y + rise / 2, (low.Z + high.Z) / 2)
	-- A wedge is low at its front (-Z) and full height at its back, so it faces away from where it rises to.
	g:wedge(v(wide, rise, flat.Magnitude), CFrame.lookAt(middle, middle - flat), color, M.SmoothPlastic)
end

local function grey(g, a: Vector3, b: Vector3, color: Color3?): BasePart
	return g:box(a, b, g:vary(color or GREY, 0.02), M.SmoothPlastic)
end

local function outerWall(g)
	grey(g, v(-HALF - T, -1, HALF), v(HALF + T, OUTER_HEIGHT, HALF + T), LIGHT)
end

-- The corner house: walls on its two inner faces with doorways and a long window, the outer wall behind it,
-- and a flat roof with a low parapet.
local function house(g, color: Color3)
	local x0, z0, x1, z1 = HOUSE, HOUSE, HALF, HALF
	-- The face toward -X: solid at the bottom, a long window, solid above.
	grey(g, v(x0, 0, z0), v(x0 + T, 6, z1), color)
	grey(g, v(x0, 6, z0), v(x0 + T, HOUSE_TOP - 1, z0 + 6), color)
	grey(g, v(x0, 9, z0 + 6), v(x0 + T, HOUSE_TOP - 1, z1), color)
	-- The face toward -Z: two doorways.
	for _, span in { { x0, x0 + 8 }, { x0 + 16, x0 + 22 }, { x0 + 28, x1 } } do
		grey(g, v(span[1], 0, z0), v(span[2], HOUSE_TOP - 1, z0 + T), color)
	end
	for _, span in { { x0 + 8, x0 + 16 }, { x0 + 22, x0 + 28 } } do
		grey(g, v(span[1], 8, z0), v(span[2], HOUSE_TOP - 1, z0 + T), color)
	end
	-- Roof, and a pillar inside so it doesn't read as floating.
	grey(g, v(x0, HOUSE_TOP - 1, z0), v(x1, HOUSE_TOP, z1), DARK)
	grey(g, v(x0 + 14, 0, z0 + 14), v(x0 + 17, HOUSE_TOP - 1, z0 + 17), DARK)
	-- Inside: a crate to fight around.
	grey(g, v(x0 + 22, 0, z0 + 20), v(x0 + 27, 4, z0 + 25))
	-- Parapet: waist high, with a gap where the catwalk leaves and where the ramp arrives.
	grey(g, v(x0 + 7, HOUSE_TOP, z0), v(x1, HOUSE_TOP + 3, z0 + T), color)
	grey(g, v(x0, HOUSE_TOP, z0 + 7), v(x0 + T, HOUSE_TOP + 3, z1 - 8), color)
	-- The ramp to the roof, along the -X face, rising toward the outer wall.
	ramp(g, v(x0 - 4.5, 0, z0 + 2), v(x0 - 4.5, HOUSE_TOP, z1 - 8), 8, DARK)
	grey(g, v(x0 - 8.5, 0, z1 - 8), v(x0, HOUSE_TOP, z1), DARK) -- the landing at its top
end

-- A catwalk sloping from the house roof's corner down to the hub's corner.
local function catwalk(g, color: Color3)
	local from = v(HOUSE + 2, HOUSE_TOP - 0.5, HOUSE + 2)
	local to = v(HUB - 1, HUB_TOP - 0.5, HUB - 1)
	local length = (to - from).Magnitude
	local middle = (from + to) / 2
	g:block(v(5, 1, length), CFrame.lookAt(middle, to), DARK, M.SmoothPlastic)
	-- A thin colour strip down its middle, so its quarter reads from across the map.
	Kit.decor(g:block(v(0.6, 0.05, length), CFrame.lookAt(middle, to) * CFrame.new(0, 0.52, 0), color, M.Neon))
	-- Two legs.
	for _, share in { 0.35, 0.7 } do
		local at = from:Lerp(to, share)
		grey(g, v(at.X - 1, 0, at.Z - 1), v(at.X + 1, at.Y - 0.5, at.Z + 1), DARK)
	end
end

-- The hub's share for this quarter: a ramp up its +Z side and a cover block on top.
local function hub(g, color: Color3)
	ramp(g, v(HUB, 0, HUB + 4), v(-HUB, HUB_TOP, HUB + 4), 8, GREY)
	grey(g, v(2, HUB_TOP, 6), v(8, HUB_TOP + 3.5, 8), color)
end

-- Cover between the hub and the house, at three heights.
local function field(g, color: Color3)
	-- Crate stack: one tall, one to climb it by.
	grey(g, v(30, 0, 40), v(36, 6, 46))
	grey(g, v(36, 0, 42), v(40, 3, 46))
	-- A low wall to crouch behind, across the lane to the hub.
	grey(g, v(22, 0, 56), v(40, 3.5, 57), color)
	-- A block to jump up on, with a view over the middle.
	grey(g, v(40, 0, 12), v(52, 4.5, 24), DARK)
	grey(g, v(44, 4.5, 12), v(52, 7, 13)) -- a lip of cover along its edge
	-- Two tall walls close enough to wall jump between, on the side lane.
	grey(g, v(70, 0, 18), v(71, 11, 42), color)
	grey(g, v(79, 0, 18), v(80, 11, 42), color)
	-- The edge lane between corner houses: a block to break the long line and a low one beside it.
	grey(g, v(24, 0, 76), v(32, 6, 84))
	grey(g, v(12, 0, 86), v(18, 3, 92))
	-- A short wall in the open diagonal, so the hub isn't a free shot from the house door.
	grey(g, v(54, 0, 34), v(55, 6, 44), color)
end

local function makeSpawn(g, position: Vector3): SpawnLocation
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "JunctionSpawn"
	spawn.Anchored = true
	spawn.Size = Vector3.new(6, 1, 6)
	-- Facing the middle of the map.
	local look = CFrame.lookAt(position, v(0, position.Y, 0))
	spawn.CFrame = g:frame(look) * CFrame.new(0, -spawn.Size.Y / 2, 0)
	spawn.Transparency = 1
	spawn.CanCollide = false
	spawn.CanQuery = false
	spawn.CanTouch = false
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Parent = g.parent
	return spawn
end

local function quarter(kit, color: Color3, spawns: { SpawnLocation })
	outerWall(kit:group("Wall"))
	house(kit:group("House"), color)
	catwalk(kit:group("Catwalk"), color)
	hub(kit:group("Hub"), color)
	field(kit:group("Field"), color)
	for _, at in { v(84, 0, 84), v(90, 0, 50), v(50, 0, 90) } do
		table.insert(spawns, makeSpawn(kit, at))
	end
end

local Junction = {}

-- Builds the arena with its centre at origin. Returns its spawns and a return terminal in each corner house.
function Junction.build(origin: CFrame)
	local folder = Instance.new("Folder")
	folder.Name = "Junction"
	local base = Kit.new(folder, origin, SEED)
	grey(base, v(-HALF - T, -2, -HALF - T), v(HALF + T, 0, HALF + T), LIGHT) -- the floor
	grey(base, v(-HUB, 0, -HUB), v(HUB, HUB_TOP, HUB), DARK) -- the hub
	local spawns, terminals = {}, {}
	for index, color in CORNERS do
		local quarterFolder = Instance.new("Folder")
		quarterFolder.Name = "Quarter" .. index
		quarterFolder.Parent = folder
		local kit = Kit.new(quarterFolder, origin * CFrame.Angles(0, (index - 1) * math.pi / 2, 0), SEED + index)
		quarter(kit, color, spawns)
		local console = kit:point(v(HALF - 3, 0, HALF - 10))
		table.insert(terminals, Relay.buildTerminal(quarterFolder, console, kit:frame(CFrame.new()).RightVector * -1, "OUTPOST"))
		kit:finish(quarterFolder)
	end
	folder.Parent = workspace
	return { folder = folder, spawns = spawns, terminals = terminals }
end

-- A console in another room that leads to the arena.
function Junction.buildTerminal(parent: Instance, base: Vector3, facing: Vector3): ProximityPrompt
	return Relay.buildTerminal(parent, base, facing, "JUNCTION FFA")
end

return Junction
