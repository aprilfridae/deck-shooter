-- Hex: a 1v1 map in a box, from River's sketch. Two players spawn at opposite ends of a walled box. Each has
-- a slab of cover just in front of their spawn and a ramp in the corner on their right, up to a flat lookout.
-- In the middle is a ring of six walls with gaps between them and holes to shoot through.
-- The box's walls are tall and plain so you can sprint along them and wall jump off them.
-- Grey box for now: shapes and flow first, looks later. See docs/specs/hex.md.
-- The map is point-symmetric. One side is built, then the same build runs turned half round.
-- Side axes: this side's spawn is toward -X, facing +X, so its right hand is +Z.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Guns = ReplicatedStorage:WaitForChild("Guns")
local Palette = require(Guns:WaitForChild("Palette"))
local Kit = require(script.Parent.Kit)
local Relay = require(script.Parent.Relay)

local M = Enum.Material

local SEED = 61
local HALF_LONG = 80 -- inside of the end walls, from the centre (along X)
local HALF_WIDE = 45 -- inside of the side walls (along Z)
local WALL_HEIGHT = 34 -- too tall to wall jump out of
local T = 2 -- outer wall thickness

local RING = 20 -- from the centre to the middle of each ring wall
local RING_LENGTH = 17 -- each ring wall's length; the gaps between them are about 6
local RING_HEIGHT = 9
local RING_THICK = 1.2
local HOLE_BOTTOM, HOLE_TOP = 3.2, 5.6 -- the shooting holes, about chest to head height
local HOLE_WIDE = 3

local COVER_X = 45 -- the spawn cover's distance from the centre
local COVER_HALF = 12 -- half its length
local COVER_HEIGHT = 11

local RAMP_FOOT, RAMP_TOP = 78, 52 -- the ramp runs from the back corner toward the middle
local RAMP_HEIGHT = 8
local RAMP_WIDE = 22
local DECK_LENGTH = 6 -- the flat lookout at the ramp's top

local SPAWN_X = 73

local SIDES = { Palette.DataCyan, Palette.HazardRed }
local GREY = Color3.fromRGB(150, 152, 158)
local LIGHT = Color3.fromRGB(184, 186, 190)
local DARK = Palette.DeepNavy

local function v(x: number, y: number, z: number): Vector3
	return Vector3.new(x, y, z)
end

local function grey(g, a: Vector3, b: Vector3, color: Color3?): BasePart
	return g:box(a, b, g:vary(color or GREY, 0.02), M.SmoothPlastic)
end

-- This side's half of the box: the end wall and half of each side wall.
local function walls(g)
	grey(g, v(-HALF_LONG - T, -1, -HALF_WIDE - T), v(-HALF_LONG, WALL_HEIGHT, HALF_WIDE + T), LIGHT)
	grey(g, v(-HALF_LONG, -1, HALF_WIDE), v(0, WALL_HEIGHT, HALF_WIDE + T), LIGHT)
end

-- One ring wall, its middle RING out from the centre toward angle (radians, from +X toward +Z), with two
-- holes to shoot through.
local function ringWall(g, angle: number, color: Color3)
	local out = v(math.cos(angle), 0, math.sin(angle))
	local at = CFrame.lookAt(out * RING, out * (RING + 1)) -- X runs along the wall
	local function piece(x0: number, x1: number, y0: number, y1: number, tint: Color3?)
		g:block(v(x1 - x0, y1 - y0, RING_THICK), at * CFrame.new((x0 + x1) / 2, (y0 + y1) / 2, 0), g:vary(tint or GREY, 0.02), M.SmoothPlastic)
	end
	local half = RING_LENGTH / 2
	local hole = HOLE_WIDE / 2
	local centre = half / 2 -- each hole sits in the middle of its half of the wall
	piece(-half, half, 0, HOLE_BOTTOM)
	piece(-half, half, HOLE_TOP, RING_HEIGHT - 0.5)
	piece(-half, half, RING_HEIGHT - 0.5, RING_HEIGHT, color) -- a colour cap, so you know whose side you're on
	piece(-half, -centre - hole, HOLE_BOTTOM, HOLE_TOP)
	piece(-centre + hole, centre - hole, HOLE_BOTTOM, HOLE_TOP)
	piece(centre + hole, half, HOLE_BOTTOM, HOLE_TOP)
end

-- The slab of cover in front of the spawn.
local function cover(g, color: Color3)
	grey(g, v(-COVER_X - 1, 0, -COVER_HALF), v(-COVER_X + 1, COVER_HEIGHT, COVER_HALF), DARK)
	grey(g, v(-COVER_X - 1, COVER_HEIGHT, -COVER_HALF), v(-COVER_X + 1, COVER_HEIGHT + 0.4, COVER_HALF), color)
end

-- The ramp on the spawn's right, along the side wall, up to a plain flat lookout (River
-- didn't want a lip on it).
local function ramp(g)
	local z0, z1 = HALF_WIDE - RAMP_WIDE, HALF_WIDE
	local length = RAMP_FOOT - RAMP_TOP
	local middle = v(-(RAMP_FOOT + RAMP_TOP) / 2, RAMP_HEIGHT / 2, (z0 + z1) / 2)
	-- A wedge is low at its front (-Z) and full height at its back, so it faces away from where it rises to.
	g:wedge(v(RAMP_WIDE, RAMP_HEIGHT, length), CFrame.lookAt(middle, middle - Vector3.xAxis), DARK, M.SmoothPlastic)
	local front = -RAMP_TOP + DECK_LENGTH
	grey(g, v(-RAMP_TOP, 0, z0), v(front, RAMP_HEIGHT, z1), DARK)
end

local function makeSpawn(g): SpawnLocation
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "HexSpawn"
	spawn.Anchored = true
	spawn.Size = Vector3.new(6, 1, 6)
	local look = CFrame.lookAt(v(-SPAWN_X, 0, 0), v(0, 0, 0))
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

local Hex = {}

-- Builds the map with its centre at origin. Returns its two spawns and a return terminal by each.
function Hex.build(origin: CFrame)
	local folder = Instance.new("Folder")
	folder.Name = "Hex"
	local base = Kit.new(folder, origin, SEED)
	grey(base, v(-HALF_LONG - T, -2, -HALF_WIDE - T), v(HALF_LONG + T, 0, HALF_WIDE + T), LIGHT) -- the floor
	local spawns, terminals = {}, {}
	for index, color in SIDES do
		local sideFolder = Instance.new("Folder")
		sideFolder.Name = "Side" .. index
		sideFolder.Parent = folder
		local kit = Kit.new(sideFolder, origin * CFrame.Angles(0, (index - 1) * math.pi, 0), SEED + index)
		walls(kit:group("Walls"))
		local ring = kit:group("Ring")
		-- Three of the six: the one facing this spawn's side wall and the two angled toward this spawn.
		for _, degrees in { 90, 150, 210 } do
			ringWall(ring, math.rad(degrees), color)
		end
		cover(kit:group("Cover"), color)
		ramp(kit:group("Ramp"))
		table.insert(spawns, makeSpawn(kit))
		local console = kit:point(v(-HALF_LONG + 1.5, 0, -12))
		table.insert(terminals, Relay.buildTerminal(sideFolder, console, kit:frame(CFrame.new()).RightVector, "OUTPOST"))
		kit:finish(sideFolder)
	end
	base:finish(folder)
	folder.Parent = workspace
	return { folder = folder, spawns = spawns, terminals = terminals }
end

-- A console in another room that leads to the map.
function Hex.buildTerminal(parent: Instance, base: Vector3, facing: Vector3): ProximityPrompt
	return Relay.buildTerminal(parent, base, facing, "HEX 1V1")
end

return Hex
