-- The Outpost: a concrete sea outpost on a rock, in fog.
-- See docs/specs/outpost.md for the layout.
-- Local axes: +Z points from the dock toward the hall, sea level is 0 and the deck is at 6.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Guns = ReplicatedStorage:WaitForChild("Guns")
local OutpostAssets = require(Guns:WaitForChild("OutpostAssets"))
local Palette = require(Guns:WaitForChild("Palette"))
local Kit = require(script.Parent.Kit)

local M = Enum.Material

-- Colours for one-off parts. Amber is only for lights; signs and screens use the palette.
local STEEL = Color3.fromRGB(56, 60, 62)
local RUST = Color3.fromRGB(178, 86, 34)
local CARDBOARD = Color3.fromRGB(150, 122, 88)
local DISH = Color3.fromRGB(188, 194, 194)
local SEAM = Color3.fromRGB(26, 28, 30)
local WINDOW_DARK = Color3.fromRGB(28, 34, 36)
local AMBER = Color3.fromRGB(255, 168, 76)
local WINDOW_LIT = Color3.fromRGB(214, 138, 64)
local FLUORESCENT = Color3.fromRGB(198, 234, 214)
local SKYLIGHT = Color3.fromRGB(208, 228, 232)
local MIST = Color3.fromRGB(196, 210, 210)
local RAIN = Color3.fromRGB(200, 214, 216)
local ROCKS = { M.Basalt, M.Basalt, M.Rock, M.Slate }

local DOCK = 4 -- top of the pier
local DECK = 6 -- top of the yard, hall and corridor floors
-- The island's rock stops at sea level, well under the floors, and the floors are solid down to it.
-- Terrain blurs a filled block's edge by up to half a voxel, so with the rock just under the
-- floors it showed through them.
local ROCK_TOP = 0
local SLAB_BOTTOM = ROCK_TOP
local UNDER_FLOOR = 3 -- rocks under a floor keep their tops below this
local SPRING = 24 -- where the hall's vault starts
local VAULT_IN = 20
local VAULT_OUT = 23
local VAULT_SEGMENTS = 16
local RIB_SEGMENTS = 8
local RIBS = { 21, 39, 57, 75, 93, 111 }
local HALL_SOUTH = 13
local HALL_NORTH = 119
local SKY_SOUTH = 58 -- the skylight's ends
local SKY_NORTH = 74
local SEED = 7

-- Rocks stay clear of these, as x0, z0, x1, z1 and the height their tops must stay under.
local KEEP_CLEAR = {
	{ -10, -118, 10, -58, -1.5 }, -- the dock: only under the water
	{ -58, -102, -34, -82, -0.6 }, -- the bunker's platform
	{ -50, -57.5, 50, HALL_SOUTH, UNDER_FLOOR }, -- the yard
	{ -23, HALL_SOUTH, 23, HALL_NORTH, UNDER_FLOOR }, -- the hall
	{ 23, 59, 52, 73, UNDER_FLOOR }, -- the test range corridor
	{ 29.5, 88, 62.5, 112, UNDER_FLOOR }, -- the comms tower
}
-- Terrain smooths a voxel's surface, so a rock can show up to this far past its box.
local ROCK_SLACK = 2

local Map = {}

local function v(x: number, y: number, z: number): Vector3
	return Vector3.new(x, y, z)
end

-- A cframe at position whose front faces direction.
local function facing(position: Vector3, direction: Vector3): CFrame
	return CFrame.lookAt(position, position + direction)
end

-- How far a turned box reaches from its centre along each world axis.
local function reach(cframe: CFrame, size: Vector3): Vector3
	local half = size / 2
	local right, up, back = cframe.RightVector, cframe.UpVector, cframe.LookVector
	return Vector3.new(
		math.abs(right.X) * half.X + math.abs(up.X) * half.Y + math.abs(back.X) * half.Z,
		math.abs(right.Y) * half.X + math.abs(up.Y) * half.Y + math.abs(back.Y) * half.Z,
		math.abs(right.Z) * half.X + math.abs(up.Z) * half.Y + math.abs(back.Z) * half.Z
	)
end

-- The highest a rock's top can be at position with this reach, so it never pokes through a floor.
local function ceiling(position: Vector3, extent: Vector3): number
	local limit = math.huge
	for _, area in KEEP_CLEAR do
		local overlaps = position.X + extent.X + ROCK_SLACK > area[1]
			and position.X - extent.X - ROCK_SLACK < area[3]
			and position.Z + extent.Z + ROCK_SLACK > area[2]
			and position.Z - extent.Z - ROCK_SLACK < area[4]
		if overlaps then
			limit = math.min(limit, area[5] - ROCK_SLACK)
		end
	end
	return limit
end

local function terrain(kit)
	local land = workspace.Terrain
	land.WaterColor = Color3.fromRGB(30, 50, 52)
	land.WaterReflectance = 0.6
	land.WaterTransparency = 0.2
	land.WaterWaveSize = 0.08
	land.WaterWaveSpeed = 4

	local function fill(cframe: CFrame, size: Vector3, material: Enum.Material)
		land:FillBlock(kit.origin * cframe, size, material)
	end
	-- A turned block of rock, sunk if it would come up through anything built.
	local function boulder(position: Vector3, size: Vector3, tilt: number?)
		local lean = tilt or 0.25
		local turn = CFrame.Angles(kit:range(-lean, lean), kit:range(0, math.pi), kit:range(-lean, lean))
		local extent = reach(turn, size)
		local top = position.Y + extent.Y
		local limit = ceiling(position, extent)
		if top > limit then
			position -= Vector3.new(0, top - limit, 0)
		end
		fill(CFrame.new(position) * turn, size, ROCKS[kit.random:NextInteger(1, #ROCKS)])
	end

	-- Fills whole voxels exactly, so these big flat surfaces land where they're asked to.
	local function fillVoxels(low: Vector3, high: Vector3, material: Enum.Material)
		local region = Region3.new(kit:point(low), kit:point(high)):ExpandToGrid(4)
		land:FillRegion(region, 4, material)
	end

	-- The sea, with its surface at 0.
	fillVoxels(v(-448, -24, -408), v(448, 0, 488), M.Water)
	-- The rock under the yard, hall and annexes, stopping at sea level.
	fillVoxels(v(-60, -20, -56), v(64, ROCK_TOP, 128), M.Basalt)

	-- Broken edges, so the rock doesn't read as a box.
	for x = -56, 56, 11 do
		if math.abs(x) > 12 then
			boulder(v(x + kit:range(-3, 3), -2, -60 - kit:range(0, 4)), v(kit:range(8, 15), kit:range(6, 9), kit:range(8, 14)))
		end
	end
	for z = -50, 124, 12 do
		boulder(v(-64 - kit:range(0, 4), -2, z + kit:range(-3, 3)), v(kit:range(8, 15), kit:range(6, 10), kit:range(8, 14)))
		if z < 30 or z > 120 then
			boulder(v(68 + kit:range(0, 4), -2, z + kit:range(-3, 3)), v(kit:range(8, 15), kit:range(6, 10), kit:range(8, 14)))
		end
	end
	for x = -50, 60, 12 do
		boulder(v(x, -2, 134 + kit:range(0, 4)), v(kit:range(9, 16), kit:range(6, 10), kit:range(8, 14)))
	end

	-- The cliff beside the hall, kept off the corridor and comms tower.
	for _, rock in {
		{ 82, 30, 40, 26 },
		{ 96, 50, 62, 28 },
		{ 92, 38, 90, 24 },
		{ 100, 58, 110, 30 },
		{ 90, 34, 130, 26 },
		{ 106, 44, 80, 28 },
	} do
		local height = rock[2]
		boulder(v(rock[1], height / 2 - 10, rock[3]), v(rock[4], height, rock[4] * kit:range(0.8, 1.3)), 0.08)
	end

	-- Low rocks around the bunker, just out of the water and clear of its platform.
	for _, rock in { { -68, -92 }, { -46, -112 }, { -24, -90 }, { -66, -72 } } do
		boulder(v(rock[1], -2, rock[2]), v(kit:range(6, 8), kit:range(5, 7), kit:range(6, 8)))
	end

	-- Outcrops fading into the fog.
	local placed = 0
	while placed < 14 do
		local angle = kit:range(0, math.pi * 2)
		local distance = kit:range(90, 300)
		local x, z = math.cos(angle) * distance, math.sin(angle) * distance + 30
		-- Keep the view down the dock and past the bunker clear.
		if not (math.abs(x) < 24 and z < -60) and not (x < -24 and x > -80 and z < -64 and z > -120) then
			local size = kit:range(6, 26)
			boulder(v(x, kit:range(-4, 2), z), v(size, kit:range(6, 18), size * kit:range(0.7, 1.4)))
			placed += 1
		end
	end
end

local function mist(kit, center: Vector3, size: Vector3)
	local emitterPart = Kit.decor(kit:block(size, CFrame.new(center), MIST, M.SmoothPlastic))
	emitterPart.Transparency = 1
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = OutpostAssets.mist
	emitter.Color = ColorSequence.new(MIST)
	emitter.Rate = 2.5
	emitter.Lifetime = NumberRange.new(14, 20)
	emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 14), NumberSequenceKeypoint.new(1, 26) })
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.25, 0.86),
		NumberSequenceKeypoint.new(0.75, 0.88),
		NumberSequenceKeypoint.new(1, 1),
	})
	emitter.Speed = NumberRange.new(0.5, 1.5)
	emitter.SpreadAngle = Vector2.new(60, 60)
	emitter.Acceleration = Vector3.new(0.6, 0.05, 0.3)
	emitter.Rotation = NumberRange.new(0, 360)
	emitter.RotSpeed = NumberRange.new(-6, 6)
	emitter.LightInfluence = 1
	emitter.Parent = emitterPart
end

local function lampPost(kit, base: Vector3, armToward: number, shadows: boolean?)
	local color, material = kit:surface("steel")
	kit:post(base, 10, 0.5, color, material)
	local top = base + v(0, 10, 0)
	kit:box(top + v(0, -0.6, -0.15), top + v(armToward * 2.2, -0.2, 0.15), color, material)
	kit:lamp(top + v(armToward * 2, -0.6, 0), AMBER, 22, 1.6, shadows)
	return top
end

local function dock(kit)
	local g = kit:group("Dock")
	local _, paint = g:floor("floor", v(-7, DOCK - 1.2, -114), v(7, DOCK, -62), true)
	for _, x in { -5.6, 5.6 } do
		paint:mark(x - 0.11, -113.5, x + 0.11, -62.5, Palette.Bone, 0.74)
	end
	paint:mark(-6.2, -63.6, 6.2, -62.7, Palette.SignalAcid, 0.68)
	for _ = 1, 3 do
		paint:stain(g:range(-4, 4), g:range(-110, -66), g:range(1.5, 3.5), g:range(2, 4), g:range(0.35, 0.55))
	end
	for _, x in { -6.6, 6.6 } do
		g:dirty(g:boxOf("darkConcrete", v(x - 0.4, DOCK, -114), v(x + 0.4, DOCK + 0.4, -62)), "floor")
	end
	-- Pillars and cross beams into the sea.
	for z = -110, -66, 13 do
		for _, x in { -5.5, 5.5 } do
			local color, material = g:surface("darkConcrete")
			g:post(v(x, -10, z), 12.8, 1.6, color, material)
		end
		g:boxOf("darkConcrete", v(-7, DOCK - 2.2, z - 0.6), v(7, DOCK - 1.2, z + 0.6))
	end
	-- Railings.
	for _, x in { -6.6, 6.6 } do
		for z = -112, -64, 4 do
			g:boxOf("steel", v(x - 0.1, DOCK + 0.4, z - 0.1), v(x + 0.1, DOCK + 3.4, z + 0.1))
		end
		g:boxOf("steel", v(x - 0.12, DOCK + 3.4, -114), v(x + 0.12, DOCK + 3.6, -62))
		g:boxOf("steel", v(x - 0.08, DOCK + 1.9, -114), v(x + 0.08, DOCK + 2.05, -62))
	end
	-- Lamp posts, with wires slung between them.
	local tops = {}
	for index, z in { -108, -92, -76 } do
		local side = if index % 2 == 1 then -1 else 1
		table.insert(tops, lampPost(g, v(side * 6.6, DOCK + 0.4, z), -side, index == 2))
	end
	for index = 1, #tops - 1 do
		g:cable(tops[index], tops[index + 1], 1.2)
	end
	for _, spot in { { -5.5, -112 }, { 5.5, -112 }, { -5.5, -98 }, { 5.5, -84 } } do
		local color, material = g:surface("rust")
		g:post(v(spot[1], DOCK, spot[2]), 1.4, 1, color, material)
	end

	-- Players arrive at the far end, facing the outpost.
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "OutpostSpawn"
	spawn.Anchored = true
	spawn.Size = v(6, 1, 6)
	spawn.CFrame = kit.origin * CFrame.new(0, DOCK - 0.5, -104) * CFrame.Angles(0, math.pi, 0)
	spawn.Transparency = 1
	spawn.CanCollide = false
	spawn.CanQuery = false
	spawn.CanTouch = false
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Parent = g.parent
	return spawn
end

local function gantry(kit)
	local g = kit:group("Gantry")
	local frames = { -78, -70, -62, -54 }
	for _, z in frames do
		for _, x in { -8.5, 8.5 } do
			g:dirty(g:boxOf("rust", v(x - 0.7, -6, z - 0.7), v(x + 0.7, 19, z + 0.7)), "block", 0.45)
			local side = if x < 0 then 1 else -1
			-- A knee brace from the leg up to the beam.
			g:solid("rust", v(0.6, 4.2, 0.6), CFrame.new(x + side * 1.6, 16.6, z) * CFrame.Angles(0, 0, -side * math.rad(45)))
		end
		-- Reaches past the legs, so its ends don't share a face with them.
		g:dirty(g:boxOf("rust", v(-9.4, 18, z - 0.9), v(9.4, 19.6, z + 0.9)), "wall", 0.45)
	end
	for index = 1, #frames - 1 do
		for _ = 1, 5 do
			g:cable(v(g:range(-8, 8), 18, frames[index]), v(g:range(-8, 8), 18, frames[index + 1]), g:range(1, 3))
		end
	end
	-- A lightbox hung from the middle frame, facing the dock.
	g:sign(CFrame.new(0, 15.6, -62.9), 10, 2.2, {
		text = "DOCK 3",
		color = Palette.DeepNavy,
		fill = Palette.SignalAcid,
		light = Palette.SignalAcid,
	})
	for _, x in { -4, 4 } do
		Kit.decor(g:box(v(x - 0.05, 16.7, -62.95), v(x + 0.05, 18, -62.85), STEEL, M.Metal))
	end
	g:lamp(v(-4, 17.2, -78), AMBER, 14, 1.2)
	g:lamp(v(4, 17.2, -54), AMBER, 14, 1.2)
end

local function screenTower(kit)
	local g = kit:group("ScreenTower")
	g:dirty(g:boxOf("darkConcrete", v(-6, DECK, -30), v(6, DECK + 2, -18)), "block")
	g:dirty(g:boxOf("steel", v(-3, DECK + 2, -27), v(3, 24, -21)), "block", 0.45)
	for _, spot in { { -2.4, -27.4 }, { 2.4, -27.4 }, { -2.4, -20.6 }, { 2.4, -20.6 } } do
		g:post(v(spot[1], DECK + 2, spot[2]), 16, 0.5, SEAM, M.Metal)
	end
	g:dirty(g:boxOf("steel", v(-9, 24, -31), v(9, 38, -17)), "block", 0.4)
	g:screen(CFrame.new(0, 31, -31.2), 14, 9, "Name")
	g:screen(facing(v(-9.2, 31, -24), v(-1, 0, 0)), 10, 7, "Deck")

	-- The lamp head on top.
	g:dirty(g:boxOf("steel", v(-5, 38, -28), v(5, 42, -20)), "block", 0.45)
	for _, x in { -2.4, 2.4 } do
		local lens = Kit.decor(g:cylinder(CFrame.new(x, 40, -28.2) * CFrame.Angles(0, math.pi / 2, 0), 0.6, 2.6, Palette.DataCyan, M.Neon))
		g:light(lens, "PointLight", { Color = Palette.DataCyan, Range = 10, Brightness = 1 })
	end
	g:post(v(2, 42, -24), 16, 0.4, STEEL, M.Metal)
	g:lamp(v(2, 58.4, -24), AMBER, 10, 1.2)
	for _, spot in { { -8.6, 36, -31.1 }, { -7.6, 36, -31.1 }, { 8.6, 26, -31.1 }, { 6, 26.6, -16.9 } } do
		g:neon(v(0.5, 0.5, 0.2), CFrame.new(spot[1], spot[2], spot[3]), Palette.DataCyan)
	end

	-- Cables off the head, down to the deck and across to the buildings.
	for _, run in {
		{ v(-7, 24, -30), v(-6, DECK + 2, -30), 1.5 },
		{ v(7, 24, -18), v(6, DECK + 2, -18), 1.5 },
		{ v(-8, 30, -17), v(-14, 20, 12.6), 4 },
		{ v(0, 34, -17), v(2, 23, 12.6), 5 },
		{ v(8, 30, -17), v(15, 21, 12.6), 4 },
		{ v(9, 34, -20), v(36, 36, 88), 12 },
		{ v(-9, 28, -28), v(-44, 16, -50), 6 },
		{ v(6, 36, -31), v(6, 18.6, -54), 3 },
	} do
		g:cable(run[1], run[2], run[3], 0.16)
	end

	-- Equipment at the base.
	for _, box in { { v(7, DECK, -30), v(10, DECK + 3, -27) }, { v(-10.5, DECK, -22), v(-8, DECK + 4, -19.6) }, { v(6, DECK, -17), v(8, DECK + 2, -15) } } do
		g:dirty(g:boxOf("sheet", box[1], box[2]), "block", 0.45)
	end
	g:neon(v(0.4, 0.4, 0.1), CFrame.new(8.5, DECK + 2.4, -30.05), AMBER)
	g:neon(v(0.4, 0.4, 0.1), CFrame.new(-9.2, DECK + 3.2, -22.05), Palette.DataCyan)
end

local function yard(kit)
	local g = kit:group("Yard")
	local _, paint = g:floor("floor", v(-50, SLAB_BOTTOM, -56), v(50, DECK, HALL_SOUTH), true)
	g:dirty(g:wedge(v(14, DECK - DOCK, 6), CFrame.new(0, (DOCK + DECK) / 2, -59), g:surface("floor")), "floor")
	g:dirty(g:boxOf("darkConcrete", v(-50, -6, -57.5), v(50, DOCK, -56)), "wall")
	-- Parapets, low enough to vault.
	g:dirty(g:boxOf("darkConcrete", v(-50, DECK, -54.5), v(-48.5, DECK + 3.5, HALL_SOUTH)), "block")
	g:dirty(g:boxOf("darkConcrete", v(48.5, DECK, -54.5), v(50, DECK + 3.5, HALL_SOUTH)), "block")
	g:dirty(g:boxOf("darkConcrete", v(-50, DECK, -56), v(-9, DECK + 3.5, -54.5)), "block")
	g:dirty(g:boxOf("darkConcrete", v(9, DECK, -56), v(50, DECK + 3.5, -54.5)), "block")

	-- Old paint and fittings on the deck: a walkway from the dock to the hall, a hazard band at
	-- the top of the ramp, a box around the screen tower, drains, covers and stains.
	paint:dashes(-7.5, -54, 12, 0.3, 3, 2, Palette.Bone, 0.72)
	paint:dashes(7.5, -54, 12, 0.3, 3, 2, Palette.Bone, 0.72)
	paint:mark(-7, -55.6, 7, -54.8, Palette.SignalAcid, 0.66)
	paint:outline(-7.5, -31.5, 7.5, -16.5, 0.3, Palette.SignalAcid, 0.7)
	for _, drain in { { -47.6, -30, -46.6, -26 }, { 46.6, -12, 47.6, -8 }, { -3, 9.2, 3, 10.2 }, { 20, -53.8, 24, -53.2 } } do
		local x, z = (drain[1] + drain[3]) / 2, (drain[2] + drain[4]) / 2
		paint:disc(x, z, 5, Color3.fromRGB(38, 46, 48), 0.78)
		paint:grate(drain[1], drain[2], drain[3], drain[4])
	end
	for _, cover in { { -24, -18 }, { 22, -42 } } do
		paint:disc(cover[1], cover[2], 2.6, Color3.fromRGB(52, 56, 58), 0.05)
		paint:disc(cover[1], cover[2], 2.1, Color3.fromRGB(64, 68, 68), 0.15)
	end
	for _ = 1, 7 do
		local x, z = g:range(-44, 44), g:range(-52, 8)
		if math.abs(x) > 9 or z < -33 or z > -15 then
			paint:stain(x, z, g:range(2, 5), g:range(2, 5), g:range(0.3, 0.55))
		end
	end

	lampPost(g, v(-44, DECK, -50), 1, true)
	lampPost(g, v(44, DECK, -50), -1)
	lampPost(g, v(-44, DECK, 6), 1)
	lampPost(g, v(44, DECK, 6), -1)

	-- Crates to move around.
	for _, crate in { { -42, -36, 4 }, { -38, -40, 3 }, { -42, -40, 3.4 }, { 40, 2, 4 }, { 36, 4, 3 } } do
		local size = crate[3]
		g:solid("wood", v(size, size, size), CFrame.new(crate[1], DECK + size / 2, crate[2]) * CFrame.Angles(0, g:range(-0.3, 0.3), 0))
	end
	g:solid("wood", v(3, 3, 3), CFrame.new(-40, DECK + 5.5, -38) * CFrame.Angles(0, 0.4, 0))
	-- Oil drums by the west parapet, one knocked over.
	for _, drum in { { -46.4, 4 }, { -46.6, 6.4 }, { -44.2, 5.2 } } do
		local color, material = g:surface("rust")
		g:post(v(drum[1], DECK, drum[2]), 2.9, 2, color, material)
	end
	local color, material = g:surface("steel")
	g:cylinder(CFrame.new(-43, DECK + 1, 9) * CFrame.Angles(0, math.rad(30), 0), 2.9, 2, color, material)
	-- A power cable lying across the deck from the screen tower to the parapet.
	local run = { v(-6, -24, 0), v(-14, -21.5, 0), v(-25, -26, 0), v(-38, -25, 0), v(-48.5, -27, 0) }
	for index = 1, #run - 1 do
		local a = v(run[index].X, DECK + 0.15, run[index].Y)
		local b = v(run[index + 1].X, DECK + 0.15, run[index + 1].Y)
		local look = facing((a + b) / 2, (b - a).Unit) * CFrame.Angles(0, math.pi / 2, 0)
		g:cylinder(look, (b - a).Magnitude + 0.3, 0.3, Color3.fromRGB(24, 26, 28), M.Rubber)
	end
	screenTower(kit)
end

-- Cuts the run from first to last at the ribs, skipping cuts that would leave a sliver.
local function ribCuts(first: number, last: number): { number }
	local cuts = { first }
	for _, z in RIBS do
		if z - cuts[#cuts] >= 3 and last - z >= 3 then
			table.insert(cuts, z)
		end
	end
	table.insert(cuts, last)
	return cuts
end

local function hallShell(kit)
	local g = kit:group("HallShell")
	local _, paint = g:floor("floor", v(-23, SLAB_BOTTOM, HALL_SOUTH), v(23, DECK, HALL_NORTH), true)
	-- Faded lines along the walls, a queue box in front of the Market, and the wet patch and drain
	-- under the skylight.
	for _, x in { -17.6, 17.6 } do
		paint:mark(x - 0.12, 15, x + 0.12, 102, Palette.Bone, 0.78)
	end
	paint:outline(-8, 97.5, 8, 103.5, 0.25, Palette.HazardRed, 0.76)
	local skylightZ = (SKY_SOUTH + SKY_NORTH) / 2
	paint:disc(0, skylightZ, 11, Color3.fromRGB(34, 44, 46), 0.5)
	paint:disc(0.8, skylightZ - 1.2, 6, Color3.fromRGB(28, 38, 40), 0.55)
	paint:grate(-1.5, skylightZ - 1.5, 1.5, skylightZ + 1.5)
	for _, drain in { { -19.4, 46, -18.6, 50 }, { 18.6, 86, 19.4, 90 } } do
		paint:grate(drain[1], drain[2], drain[3], drain[4])
	end
	for _ = 1, 6 do
		paint:stain(g:range(-14, 14), g:range(18, 96), g:range(2, 4.5), g:range(2, 4.5), g:range(0.35, 0.6))
	end
	-- Side walls. The east one has the door to the test range corridor.
	g:panels("concrete", v(-23, DECK, HALL_SOUTH), v(-20, SPRING, HALL_NORTH), 18, "wall")
	g:panels("concrete", v(20, DECK, HALL_SOUTH), v(23, SPRING, 63), 18, "wall")
	g:panels("concrete", v(20, DECK, 69), v(23, SPRING, HALL_NORTH), 18, "wall")
	g:dirty(g:boxOf("concrete", v(20, 14, 63), v(23, SPRING, 69)), "wall")
	-- End walls below the vault. The south one has the entrance.
	g:dirty(g:boxOf("concrete", v(-20, DECK, HALL_SOUTH), v(-9, SPRING, 16)), "wall")
	g:dirty(g:boxOf("concrete", v(9, DECK, HALL_SOUTH), v(20, SPRING, 16)), "wall")
	g:dirty(g:boxOf("concrete", v(-9, 22, HALL_SOUTH), v(9, SPRING, 16)), "wall")
	g:panels("concrete", v(-20, DECK, 116), v(20, SPRING, HALL_NORTH), 14, "wall")

	-- The barrel vault, cut at the ribs and open at the top over the skylight.
	local step = math.pi / VAULT_SEGMENTS
	local middle = (VAULT_IN + VAULT_OUT) / 2
	local width = 2 * VAULT_OUT * math.sin(step / 2) + 0.1
	for index = 1, VAULT_SEGMENTS do
		local angle = (index - 0.5) * step
		local x, y = middle * math.cos(angle), SPRING + middle * math.sin(angle)
		local turn = CFrame.Angles(0, 0, angle - math.pi / 2)
		local spans = if index == VAULT_SEGMENTS / 2 or index == VAULT_SEGMENTS / 2 + 1
			then { { HALL_SOUTH, SKY_SOUTH }, { SKY_NORTH, HALL_NORTH } }
			else { { HALL_SOUTH, HALL_NORTH } }
		for _, span in spans do
			local cuts = ribCuts(span[1], span[2])
			for piece = 1, #cuts - 1 do
				local from, to = cuts[piece], cuts[piece + 1]
				local part = g:solid("concrete", v(width, VAULT_OUT - VAULT_IN, to - from), CFrame.new(x, y, (from + to) / 2) * turn)
				g:dirty(part, "shell")
			end
		end
	end
	-- Half-round gable walls, set back a little from the vault's ends. Each lift is its own pour.
	for _, ends in { { HALL_SOUTH + 0.3, 16 }, { 116, HALL_NORTH - 0.3 } } do
		for rise = 0, VAULT_OUT - 2, 2 do
			local half = math.sqrt(VAULT_OUT ^ 2 - (rise + 1) ^ 2)
			local part = g:box(v(-half, SPRING + rise, ends[1]), v(half, SPRING + rise + 2, ends[2]), g:vary(Color3.fromRGB(116, 123, 119), 0.03), M.Concrete)
			g:dirty(part, "wall")
		end
	end
	-- Ribs across the vault, with pilasters below them.
	local ribStep = math.pi / RIB_SEGMENTS
	local ribWidth = 2 * VAULT_IN * math.sin(ribStep / 2) + 0.1
	for _, z in RIBS do
		-- One colour per rib, so the segments' overlapping joints can't flicker.
		local color, material = g:surface("darkConcrete")
		for index = 1, RIB_SEGMENTS do
			local angle = (index - 0.5) * ribStep
			local radius = VAULT_IN - 0.7
			local turn = CFrame.Angles(0, 0, angle - math.pi / 2)
			g:block(v(ribWidth, 1.4, 2.4), CFrame.new(radius * math.cos(angle), SPRING + radius * math.sin(angle), z) * turn, color, material)
		end
		for _, side in { -1, 1 } do
			g:dirty(g:boxOf("darkConcrete", v(side * 18.6, DECK, z - 1.2), v(side * VAULT_IN, SPRING, z + 1.2)), "block")
		end
	end
end

local function hallFront(kit)
	local g = kit:group("HallFront")
	g:sign(CFrame.new(0, 27, 13.1), 16, 3, {
		text = "OUTPOST 07",
		color = Palette.DeepNavy,
		fill = Palette.SignalAcid,
		light = Palette.SignalAcid,
	})
	for _, x in { -11, 11 } do
		g:lamp(v(x, 19, 12.4), AMBER, 16, 1.5)
	end
	for _, spot in { v(-18, 23, 12.8), v(18, 23, 12.8), v(-2, 44, 13.1), v(2, 44, 13.1) } do
		g:lamp(spot, AMBER, 6, 1, false, 0.35)
	end
	for _, x in { -15, 15 } do
		g:box(v(x - 1.5, 19.2, 12.8), v(x + 1.5, 20.8, 13), SEAM, M.Metal)
	end
	-- Pipes up the facade, stopping below the roof's edge.
	for _, x in { -19.4, 19.4 } do
		local color, material = g:surface("steel")
		g:post(v(x, DECK, 12.4), 29, 0.6, color, material)
	end
	-- Lamps just inside the entrance.
	for _, x in { -6, 6 } do
		g:lamp(v(x, 18, 18), AMBER, 18, 1.4)
	end
end

local function hallInside(kit)
	local g = kit:group("HallInside")
	-- The catwalk along the east wall.
	g:dirty(g:boxOf("plate", v(12, 16.4, 18), v(20, 17, 108)), "floor")
	for z = 18.3, 108, 15 do
		g:boxOf("steel", v(12.6, 15.8, z - 0.3), v(20, 16.4, z + 0.3))
	end
	for _, z in { 18.5, 33, 48, 63, 78, 93, 107.5 } do
		g:boxOf("steel", v(12, DECK, z - 0.3), v(12.6, 16.4, z + 0.3))
	end
	for z = 22, 108, 6 do
		g:boxOf("steel", v(12, 17, z - 0.1), v(12.2, 20.2, z + 0.1))
	end
	-- The rails are a touch thicker than the posts, so they don't share faces.
	g:boxOf("steel", v(11.97, 20.2, 22), v(12.23, 20.4, 108))
	g:boxOf("steel", v(11.97, 18.6, 22), v(12.23, 18.8, 108))
	g:boxOf("steel", v(12, 20.2, 107.8), v(20, 20.4, 108))

	-- Stairs up to the catwalk.
	local steps, rise, run = 15, 11, 18
	for index = 1, steps do
		local top = DECK + index * rise / steps
		local far = 40 - index * run / steps
		g:boxOf("plate", v(6, top - 0.3, far), v(11.5, top, far + run / steps))
	end
	local slope = math.atan2(rise, run)
	local length = math.sqrt(rise ^ 2 + run ^ 2)
	for _, x in { 5.8, 11.7 } do
		g:solid("steel", v(0.3, 0.8, length), CFrame.new(x, DECK + rise / 2 - 0.4, 31) * CFrame.Angles(slope, 0, 0))
	end
	g:solid("steel", v(0.2, 0.2, length), CFrame.new(5.9, DECK + rise / 2 + 3, 31) * CFrame.Angles(slope, 0, 0))
	for _, index in { 1, 8, 15 } do
		local top = DECK + index * rise / steps
		local z = 40 - (index - 0.5) * run / steps
		g:boxOf("steel", v(5.8, top, z - 0.1), v(6, top + 3, z + 0.1))
	end
	g:boxOf("plate", v(6, 16.4, 18), v(12, 17, 22))
	for _, crate in { { 15, 28, 3 }, { 17.5, 32, 2.4 }, { 16, 34.5, 2 } } do
		local size = crate[3]
		g:solid("wood", v(size, size, size), CFrame.new(crate[1], DECK + size / 2, crate[2]) * CFrame.Angles(0, g:range(-0.3, 0.3), 0))
	end

	-- The Market kiosk at the far end.
	g:dirty(g:boxOf("darkConcrete", v(-10, DECK, 104), v(10, DECK + 0.8, 116)), "floor")
	local counter = g:dirty(g:boxOf("steel", v(-7, DECK + 0.8, 105), v(7, DECK + 4.2, 106.6)), "wall", 0.5)
	g:box(v(-7.2, DECK + 4.2, 104.8), v(7.2, DECK + 4.4, 106.8), SEAM, M.Metal)
	g:neon(v(14, 0.2, 0.08), CFrame.new(0, DECK + 3.5, 104.86), Palette.HazardRed)
	g:boxOf("wood", v(-8, DECK + 0.8, 114.6), v(8, DECK + 10, 116))
	local tiers = { Palette.Tiers.Field, Palette.Tiers.BlackSite, Palette.Tiers.Prototype }
	for row, height in { 3.5, 6.5, 9 } do
		g:boxOf("wood", v(-8, DECK + height, 113), v(8, DECK + height + 0.25, 114.6))
		for index = 1, 6 do
			local x = -6.5 + (index - 1) * 2.6
			g:block(
				v(0.9, 1.3, 0.25),
				CFrame.new(x, DECK + height + 0.9, 113.9) * CFrame.Angles(math.rad(-8), g:range(-0.15, 0.15), 0),
				tiers[(index + row) % 3 + 1],
				M.SmoothPlastic
			)
		end
	end
	g:sign(CFrame.new(0, 21, 115.8), 16, 4, {
		text = "MARKET",
		color = Palette.HazardRed,
		outline = Palette.HazardRed,
		light = Palette.HazardRed,
	})
	for _, x in { -4, 4 } do
		g:lamp(v(x, DECK + 9, 106), AMBER, 14, 1.2, false, 0.5)
	end
	for _, crate in { { -8.5, 108, 1.4 }, { 8.6, 110, 1.2 }, { 8.2, 108.4, 1 } } do
		local size = crate[3]
		g:block(v(size, size * 0.8, size), CFrame.new(crate[1], DECK + 0.8 + size * 0.4, crate[2]) * CFrame.Angles(0, g:range(-0.4, 0.4), 0), g:vary(CARDBOARD, 0.06), M.Cardboard)
	end
	local market = g:prompt(counter, "MARKET", "Soon")

	-- Daylight through the skylight, with drips falling through it.
	local skylightZ = (SKY_SOUTH + SKY_NORTH) / 2
	local sun = Kit.decor(g:block(v(1, 1, 1), CFrame.new(0, 50, skylightZ), SKYLIGHT, M.SmoothPlastic))
	sun.Transparency = 1
	g:light(sun, "SpotLight", { Face = Enum.NormalId.Bottom, Angle = 50, Range = 60, Brightness = 3.5, Shadows = true, Color = SKYLIGHT })
	g:shaft(v(0, 46.5, skylightZ), v(0, DECK + 0.2, skylightZ), 8, SKYLIGHT)
	local drips = Kit.decor(g:block(v(7, 0.2, 14), CFrame.new(0, 46, skylightZ), RAIN, M.SmoothPlastic))
	drips.Transparency = 1
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = OutpostAssets.rain
	emitter.Color = ColorSequence.new(RAIN)
	emitter.EmissionDirection = Enum.NormalId.Bottom
	emitter.Orientation = Enum.ParticleOrientation.VelocityParallel
	emitter.Rate = 45
	emitter.Lifetime = NumberRange.new(0.8, 1)
	emitter.Speed = NumberRange.new(45, 55)
	emitter.Size = NumberSequence.new(1.6)
	emitter.Transparency = NumberSequence.new(0.45)
	emitter.LightInfluence = 0.6
	emitter.Parent = drips

	-- Cables slung across the hall.
	for z = 18, 112, 7 do
		g:cable(v(-19.6, g:range(19, 23), z + g:range(-2, 2)), v(19.6, g:range(19, 23), z + g:range(-4, 4)), g:range(3, 6))
	end
	return market
end

local function rangeCorridor(kit)
	local g = kit:group("RangeCorridor")
	g:floor("tileFloor", v(23, SLAB_BOTTOM, 59), v(52, DECK, 73), false)
	g:panels("tile", v(23, DECK, 59), v(52, 17, 61), 8, "wall")
	g:panels("tile", v(23, DECK, 71), v(52, 17, 73), 8, "wall")
	g:dirty(g:boxOf("tile", v(50, DECK, 61), v(52, 17, 71)), "wall")
	g:dirty(g:boxOf("darkConcrete", v(23, 15, 61), v(50, 17, 71)), "shell")

	-- Standing water over the floor, lifted clear of it so the two don't flicker.
	local water = Kit.decor(g:box(v(23, DECK + 0.12, 61), v(50, DECK + 0.3, 71), Color3.fromRGB(44, 70, 66), M.Glass))
	water.Transparency = 0.45
	water.Reflectance = 0.25

	for index, x in { 28, 36, 44 } do
		local panel = g:neon(v(3.2, 0.2, 3), CFrame.new(x, 14.85, 66), FLUORESCENT)
		g:light(panel, "SurfaceLight", {
			Face = Enum.NormalId.Bottom,
			Color = FLUORESCENT,
			Brightness = 1.4,
			Range = 14,
			Angle = 100,
			Shadows = index == 2,
		})
	end
	local color, material = g:surface("tile")
	g:post(v(26.5, DECK, 62.6), 9, 2.6, color, material)
	g:sign(facing(v(33, 12.6, 66), v(-1, 0, 0)), 8, 1.4, {
		text = "TEST RANGE >",
		color = Palette.DeepNavy,
		fill = Palette.SignalAcid,
		light = Palette.SignalAcid,
	})
	for _, z in { 63.5, 68.5 } do
		Kit.decor(g:box(v(32.95, 13.3, z - 0.05), v(33.05, 15, z + 0.05), STEEL, M.Metal))
	end

	-- Lift doors to the test room. The frame's head sits on its jambs rather than overlapping them.
	g:boxOf("steel", v(49.6, DECK, 62.6), v(50, 14, 63.2))
	g:boxOf("steel", v(49.6, DECK, 68.8), v(50, 14, 69.4))
	g:boxOf("steel", v(49.6, 14, 62.6), v(50, 14.6, 69.4))
	local door = g:dirty(g:box(v(49.7, DECK, 63.2), v(49.9, 14, 66), Color3.fromRGB(120, 126, 126), M.Metal), "wall", 0.5)
	g:dirty(g:box(v(49.7, DECK, 66), v(49.9, 14, 68.8), Color3.fromRGB(116, 122, 122), M.Metal), "wall", 0.5)
	Kit.decor(g:box(v(49.56, 9.4, 63.2), v(49.62, 9.9, 68.8), RUST, M.SmoothPlastic))
	g:neon(v(0.08, 2.7, 0.4), CFrame.new(49.6, 11.85, 69.8), Palette.SignalAcid)
	g:lamp(v(48.4, 14.4, 66), AMBER, 10, 1)
	return g:prompt(door, "TEST RANGE", "Travel", 0.4)
end

local function commsTower(kit)
	local g = kit:group("CommsTower")
	g:dirty(g:boxOf("concrete", v(34, ROCK_TOP, 88), v(58, 40, 112)), "block")
	for _, x in { 34, 58 } do
		local color, material = g:surface("concrete")
		-- Stops just under the roof, so the two tops don't flicker.
		g:post(v(x, 14, 100), 25.8, 9, color, material)
	end
	g:dirty(g:boxOf("concrete", v(36, 40, 90), v(56, 50, 110)), "block")
	g:dirty(g:boxOf("darkConcrete", v(38, 50, 92), v(54, 57, 108)), "block")
	g:boxOf("steel", v(37.5, 57, 91.5), v(54.5, 58, 108.5))
	for _, edge in {
		{ v(36, 50, 90), v(56, 51, 90.4) },
		{ v(36, 50, 109.6), v(56, 51, 110) },
		{ v(36, 50, 90.4), v(36.4, 51, 109.6) },
		{ v(55.6, 50, 90.4), v(56, 51, 109.6) },
	} do
		g:boxOf("darkConcrete", edge[1], edge[2])
	end

	local function pane(cframe: CFrame)
		if g:chance(0.35) then
			g:neon(v(2.2, 2.6, 0.2), cframe, WINDOW_LIT)
		else
			g:block(v(2.2, 2.6, 0.2), cframe, WINDOW_DARK, M.SmoothPlastic)
		end
	end
	for _, y in { 14, 22, 30 } do
		for _, x in { 38, 43, 49, 54 } do
			pane(CFrame.new(x, y, 87.95))
		end
		-- Either side of the round turret.
		for _, z in { 90.5, 93, 107, 109.5 } do
			pane(facing(v(33.95, y, z), v(-1, 0, 0)))
		end
	end
	for _, x in { 40, 44, 48, 52 } do
		pane(CFrame.new(x, 53.5, 91.95))
	end
	for _, z in { 96, 100, 104 } do
		pane(facing(v(37.95, 53.5, z), v(-1, 0, 0)))
	end
	for _, unit in { { 40, 18, 87.3 }, { 52, 26, 87.3 }, { 46, 34, 87.3 }, { 44, 44, 89.3 } } do
		g:dirty(g:boxOf("sheet", v(unit[1] - 1.3, unit[2] - 1, unit[3] - 0.7), v(unit[1] + 1.3, unit[2] + 1, unit[3] + 0.7)), "block", 0.45)
		g:cylinder(CFrame.new(unit[1], unit[2], unit[3] - 0.8) * CFrame.Angles(0, math.pi / 2, 0), 0.1, 1.4, SEAM, M.Metal)
	end

	-- Antenna masts and dishes.
	for _, corner in { { -1.2, -1.2 }, { 1.2, -1.2 }, { -1.2, 1.2 }, { 1.2, 1.2 } } do
		g:post(v(46 + corner[1], 58, 100 + corner[2]), 34, 0.35, STEEL, M.Metal)
	end
	for y = 64, 90, 6.5 do
		g:box(v(44.8, y, 98.7), v(47.2, y + 0.25, 98.9), STEEL, M.Metal)
		g:box(v(44.8, y, 101.1), v(47.2, y + 0.25, 101.3), STEEL, M.Metal)
		g:box(v(44.7, y, 98.9), v(44.9, y + 0.25, 101.1), STEEL, M.Metal)
		g:box(v(47.1, y, 98.9), v(47.3, y + 0.25, 101.1), STEEL, M.Metal)
	end
	g:lamp(v(46, 92.5, 100), AMBER, 12, 1.5, false, 0.6)
	g:post(v(40, 58, 94), 16, 0.4, STEEL, M.Metal)
	g:box(v(38, 70, 93.9), v(42, 70.3, 94.1), STEEL, M.Metal)
	g:box(v(38.5, 73, 93.9), v(41.5, 73.3, 94.1), STEEL, M.Metal)
	for _, dish in {
		{ v(46, 74, 97.6), v(0.3, 0.2, -1) },
		{ v(51.5, 61.5, 104), v(0.7, 0.5, 0.3) },
		{ v(41.5, 61, 105), v(-0.6, 0.6, 0.4) },
	} do
		local look = facing(dish[1], dish[2].Unit) * CFrame.Angles(0, math.pi / 2, 0)
		g:cylinder(look, 0.8, 8, g:vary(DISH, 0.03), M.SmoothPlastic)
		g:cylinder(look * CFrame.new(0.9, 0, 0), 1.6, 0.4, STEEL, M.Metal)
	end
end

local function bunker(kit)
	local g = kit:group("Bunker")
	g:dirty(g:boxOf("darkConcrete", v(-58, -0.6, -102), v(-34, 1, -82)), "block")
	g:dirty(g:boxOf("concrete", v(-54, 1, -98), v(-38, 25, -86)), "block")
	-- The glowing door.
	g:boxOf("steel", v(-37.8, 1, -94.2), v(-37.4, 9.4, -93.8))
	g:boxOf("steel", v(-37.8, 1, -90.2), v(-37.4, 9.4, -89.8))
	g:boxOf("steel", v(-37.8, 9.4, -94.2), v(-37.4, 10, -89.8))
	g:neon(v(0.3, 7.8, 3.6), CFrame.new(-37.85, 5.1, -92), AMBER)
	local glow = Kit.decor(g:block(v(1, 1, 1), CFrame.new(-35.5, 5, -92), AMBER, M.SmoothPlastic))
	glow.Transparency = 1
	g:light(glow, "PointLight", { Color = AMBER, Range = 18, Brightness = 2.2, Shadows = true })
	g:dirty(g:boxOf("darkConcrete", v(-37.4, 1, -95), v(-35, 1.6, -89)), "floor")
	g:sign(facing(v(-37.75, 11.2, -92), v(1, 0, 0)), 2.4, 1.2, {
		text = "07",
		color = Palette.SignalAcid,
		style = "Label",
	})
	-- Ladder, lights and a floodlight.
	for _, z in { -88.6, -87.4 } do
		Kit.decor(g:box(v(-37.9, 1, z - 0.1), v(-37.6, 26, z + 0.1), STEEL, M.Metal))
	end
	for y = 2.5, 24.5, 1.5 do
		Kit.decor(g:box(v(-37.85, y, -88.6), v(-37.65, y + 0.15, -87.4), STEEL, M.Metal))
	end
	for _, spot in { v(-37.7, 18, -97.6), v(-37.7, 16.8, -97.6), v(-37.7, 23, -96.4) } do
		g:lamp(spot, AMBER, 6, 1, false, 0.35)
	end
	g:post(v(-39.4, 25, -87.4), 3, 0.3, STEEL, M.Metal)
	local flood = g:boxOf("steel", v(-40.2, 27.6, -88.2), v(-38.6, 28.8, -86.6))
	g:light(flood, "SpotLight", { Face = Enum.NormalId.Right, Angle = 70, Range = 30, Brightness = 1.2, Color = AMBER })
	g:cable(v(-37.8, 24.5, -86.2), v(-37.8, 4, -86.8), 1.5, 0.18)
end

-- Builds the Outpost at origin. Returns its spawn and the prompts the server answers.
function Map.build(origin: CFrame)
	local folder = Instance.new("Folder")
	folder.Name = "Outpost"
	local kit = Kit.new(folder, origin, SEED)

	terrain(kit)
	local spawn = dock(kit)
	gantry(kit)
	yard(kit)
	hallShell(kit)
	hallFront(kit)
	local market = hallInside(kit)
	local testRoomDoor = rangeCorridor(kit)
	commsTower(kit)
	bunker(kit)
	local air = kit:group("Mist")
	mist(air, v(0, 0.5, -96), v(50, 1, 40))
	mist(air, v(-46, 0.5, -70), v(50, 1, 50))
	mist(air, v(72, 0.5, 0), v(60, 1, 80))

	folder.Parent = workspace
	return {
		folder = folder,
		spawn = spawn,
		testRoomDoor = testRoomDoor,
		market = market,
	}
end

-- A terminal beside the test room's spawn that leads back to the Outpost.
function Map.buildReturnTerminal(room: Instance, spawn: BasePart): ProximityPrompt
	local kit = Kit.new(room, CFrame.identity, SEED)
	local base = spawn.Position + v(9, -spawn.Size.Y / 2, 0)
	local console = kit:box(base + v(-1.2, 0, -1), base + v(1.2, 4, 1), Palette.DeepNavy, M.Metal)
	kit:sign(facing(base + v(-1.4, 3, 0), v(-1, 0, 0)), 1.8, 0.9, {
		text = "OUTPOST",
		color = Palette.DeepNavy,
		fill = Palette.SignalAcid,
		light = Palette.SignalAcid,
	})
	return kit:prompt(console, "OUTPOST", "Travel", 0.4)
end

return Map
