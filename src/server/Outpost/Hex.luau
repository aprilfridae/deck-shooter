-- Hex: a 1v1 map in a box, from River's sketch. Two players spawn at opposite ends of a walled box. Each has
-- a slab of cover just in front of their spawn and a ramp in the corner on their right, up to a flat lookout.
-- In the middle is a ring of six walls with gaps between them and holes to shoot through.
-- The box's walls are tall and plain so you can sprint along them and wall jump off them.
-- It stands in a ruined city in fog: weathered concrete, dead retro tech lying about, amber and green
-- emergency lamps, and broken towers looming over the walls. See docs/specs/hex.md.
-- The map is point-symmetric. One side is built, then the same build runs turned half round.
-- Side axes: this side's spawn is toward -X, facing +X, so its right hand is +Z.
local CollectionService = game:GetService("CollectionService")

local Kit = require(script.Parent.Kit)
local Relay = require(script.Parent.Relay)

local M = Enum.Material

local SEED = 61
local HALF_LONG = 80 -- inside of the end walls, from the centre (along X)
local HALF_WIDE = 45 -- inside of the side walls (along Z)
local WALL_HEIGHT = 34 -- too tall to wall jump out of
local T = 2 -- outer wall thickness

local RING = 28 -- from the centre to the middle of each ring wall
local RING_LENGTH = 25 -- each ring wall's length; the gaps between them are about 7
local RING_HEIGHT = 13
local RING_THICK = 1.2
local HOLE_BOTTOM, HOLE_TOP = 3.8, 7.4 -- the windows, around head height (River found 3.2 to 5.6 too low)
local HOLE_WIDE = 7

local COVER_X = 45 -- the spawn cover's distance from the centre
local COVER_HALF = 12 -- half its length
local COVER_HEIGHT = 11

local RAMP_FOOT, RAMP_TOP = 78, 60 -- the ramp runs from the back corner toward the middle
local RAMP_HEIGHT = 12
local RAMP_WIDE = 22
local DECK_LENGTH = 12 -- the flat lookout at the ramp's top

local SPAWN_X = 73

-- Each side's emergency-light colour: its caps and lamps. Amber for one, a sickly green for the other.
local SIDES = { Color3.fromRGB(255, 170, 70), Color3.fromRGB(150, 235, 120) }
local RUST = Color3.fromRGB(128, 66, 34)
local TOWER = Color3.fromRGB(46, 54, 58) -- the ruined city: dark, so it's a silhouette in the fog
local GIRDER = Color3.fromRGB(30, 32, 34)
local CASES = { Color3.fromRGB(104, 106, 104), Color3.fromRGB(84, 86, 88), Color3.fromRGB(66, 68, 70) }
local GLASS = Color3.fromRGB(12, 16, 18)
local CABLE = Color3.fromRGB(20, 21, 22)
local SCREEN_TAG = "OutpostWiredScreen" -- the client runs code on these (OutpostWired.client.luau)
local SCREEN_LIGHT = Color3.fromRGB(150, 220, 200)

local function v(x: number, y: number, z: number): Vector3
	return Vector3.new(x, y, z)
end

-- Weathered concrete between two corners. how is Kit:dirty's ("wall", "block", "floor").
local function concrete(g, a: Vector3, b: Vector3, how: string, kind: string?): BasePart
	return g:dirty(g:boxOf(kind or "darkConcrete", a, b), how)
end

-- A rusted bar end poking out of a wall with a stain bled down from it. at is on the wall's face and out
-- points into the room.
local function rustBleed(g, at: Vector3, out: Vector3)
	local frame = CFrame.lookAt(at, at + out)
	Kit.decor(g:block(v(0.25, 0.25, 0.5), frame * CFrame.new(0, 0, -0.2), RUST, M.CorrodedMetal))
	local length = g:range(3, 9)
	local stain = Kit.decor(g:block(v(g:range(0.4, 0.9), length, 0.06), frame * CFrame.new(0, -length / 2, -0.08), g:vary(RUST, 0.05), M.Concrete))
	stain.Transparency = 0.45
end

-- This side's half of the box: the end wall and half of each side wall, cast in panels.
local function walls(g, color: Color3)
	g:panels("concrete", v(-HALF_LONG - T, -1, -HALF_WIDE - T), v(-HALF_LONG, WALL_HEIGHT, HALF_WIDE + T), 16, "wall")
	g:panels("concrete", v(-HALF_LONG, -1, HALF_WIDE), v(0, WALL_HEIGHT, HALF_WIDE + T), 16, "wall")
	-- A darker band along the top, like a later pour.
	Kit.decor(g:boxOf("darkConcrete", v(-HALF_LONG - T - 0.3, WALL_HEIGHT, -HALF_WIDE - T - 0.3), v(-HALF_LONG + 0.3, WALL_HEIGHT + 1.5, HALF_WIDE + T + 0.3)))
	Kit.decor(g:boxOf("darkConcrete", v(-HALF_LONG + 0.3, WALL_HEIGHT, HALF_WIDE - 0.3), v(0, WALL_HEIGHT + 1.5, HALF_WIDE + T + 0.3)))
	for _ = 1, 9 do
		rustBleed(g, v(g:range(-HALF_LONG + 4, -3), g:range(14, WALL_HEIGHT - 2), HALF_WIDE), v(0, 0, -1))
	end
	for _ = 1, 9 do
		rustBleed(g, v(-HALF_LONG, g:range(14, WALL_HEIGHT - 2), g:range(-HALF_WIDE + 4, HALF_WIDE - 4)), v(1, 0, 0))
	end
	-- Emergency lamps high on the walls, in this side's colour.
	g:lamp(v(-HALF_LONG + 0.5, 17, 0), color, 46, 1.5)
	g:lamp(v(-40, 19, HALF_WIDE - 0.5), color, 46, 1.5)
	g:lamp(v(-HALF_LONG + 0.5, 15, -HALF_WIDE + 14), color, 30, 1.1)
end

-- One ring wall, its middle RING out from the centre toward angle (radians, from +X toward +Z), with two
-- windows to shoot through.
local function ringWall(g, angle: number, color: Color3)
	local out = v(math.cos(angle), 0, math.sin(angle))
	local at = CFrame.lookAt(out * RING, out * (RING + 1)) -- X runs along the wall
	local function piece(x0: number, x1: number, y0: number, y1: number): BasePart
		local part = g:solid("darkConcrete", v(x1 - x0, y1 - y0, RING_THICK), at * CFrame.new((x0 + x1) / 2, (y0 + y1) / 2, 0))
		return g:dirty(part, "wall")
	end
	local half = RING_LENGTH / 2
	local hole = HOLE_WIDE / 2
	local centre = half / 2 -- each window sits in the middle of its half of the wall
	piece(-half, half, 0, HOLE_BOTTOM)
	piece(-half, half, HOLE_TOP, RING_HEIGHT)
	piece(-half, -centre - hole, HOLE_BOTTOM, HOLE_TOP)
	piece(-centre + hole, centre - hole, HOLE_BOTTOM, HOLE_TOP)
	piece(centre + hole, half, HOLE_BOTTOM, HOLE_TOP)
	-- A thin lit strip along the top, so you know whose side you're on.
	g:neon(v(RING_LENGTH - 1, 0.12, 0.3), at * CFrame.new(0, RING_HEIGHT + 0.06, 0), color)
	-- Bars left sticking out of the top where the pour stopped.
	for _ = 1, 3 do
		local x = g:range(-half + 1, half - 1)
		local tall = g:range(0.8, 2.2)
		Kit.decor(g:block(v(0.15, tall, 0.15), at * CFrame.new(x, RING_HEIGHT + tall / 2, g:range(-0.3, 0.3)) * CFrame.Angles(g:range(-0.25, 0.25), 0, g:range(-0.25, 0.25)), RUST, M.CorrodedMetal))
	end
end

-- The slab of cover in front of the spawn.
local function cover(g, color: Color3)
	concrete(g, v(-COVER_X - 1, 0, -COVER_HALF), v(-COVER_X + 1, COVER_HEIGHT, COVER_HALF), "wall")
	g:neon(v(0.3, 0.12, COVER_HALF * 2 - 1), CFrame.new(-COVER_X, COVER_HEIGHT + 0.06, 0), color)
	rustBleed(g, v(-COVER_X - 1, COVER_HEIGHT - 1, g:range(-8, 8)), v(-1, 0, 0))
	rustBleed(g, v(-COVER_X + 1, COVER_HEIGHT - 1.5, g:range(-8, 8)), v(1, 0, 0))
end

-- The ramp on the spawn's right, along the side wall, up to a plain flat lookout (River
-- didn't want a lip on it).
local function ramp(g)
	local z0, z1 = HALF_WIDE - RAMP_WIDE, HALF_WIDE
	local length = RAMP_FOOT - RAMP_TOP
	local middle = v(-(RAMP_FOOT + RAMP_TOP) / 2, RAMP_HEIGHT / 2, (z0 + z1) / 2)
	local color, material = g:surface("darkConcrete")
	-- A wedge is low at its front (-Z) and full height at its back, so it faces away from where it rises to.
	g:dirty(g:wedge(v(RAMP_WIDE, RAMP_HEIGHT, length), CFrame.lookAt(middle, middle - Vector3.xAxis), color, material), "wedgeShell")
	local front = -RAMP_TOP + DECK_LENGTH
	concrete(g, v(-RAMP_TOP, 0, z0), v(front, RAMP_HEIGHT, z1), "block")
	rustBleed(g, v(front, RAMP_HEIGHT - 1, g:range(z0 + 3, z1 - 3)), v(1, 0, 0))
	rustBleed(g, v(g:range(-RAMP_TOP + 2, front - 2), RAMP_HEIGHT - 1, z0), v(0, 0, -1))
end

-- A dead CRT monitor lying where it fell, its glass dark or smashed in. Never in the way: you walk and
-- shoot through it.
local function deadMonitor(g, at: Vector3)
	local size = g:range(1.8, 2.8)
	local frame = CFrame.new(at + v(0, size * 0.4, 0)) * CFrame.Angles(0, g:range(0, math.pi * 2), 0) * CFrame.Angles(g:range(-0.5, 0.2), 0, if g:chance(0.3) then math.pi / 2 else g:range(-0.15, 0.15))
	Kit.decor(g:block(v(size, size * 0.8, size * 0.9), frame, g:vary(CASES[g.random:NextInteger(1, #CASES)], 0.03), M.SmoothPlastic))
	local glass = Kit.decor(g:block(v(size * 0.76, size * 0.56, 0.1), frame * CFrame.new(0, 0.05, -size * 0.45 - 0.03), GLASS, M.Glass))
	if g:chance(0.55) then
		-- Still running: code scrolls on it, left going since whoever worked here stopped coming. Its glow
		-- falls on the floor and cables around it, and the client makes it stutter (OutpostFlicker).
		glass:SetAttribute("WiredKind", "Code")
		glass:SetAttribute("WiredSeed", g.random:NextInteger(1, 1e6))
		CollectionService:AddTag(glass, SCREEN_TAG)
		if g:chance(0.6) then
			local light = g:light(glass, "PointLight", { Color = SCREEN_LIGHT, Range = 11, Brightness = 0.9, Shadows = false })
			light:SetAttribute("FlickerDepth", g:range(4, 8))
		end
	else -- smashed: a hole into the tube
		Kit.decor(g:block(v(size * 0.35, size * 0.3, 0.06), frame * CFrame.new(g:range(-0.3, 0.3), g:range(-0.2, 0.2), -size * 0.45 - 0.1) * CFrame.Angles(0, 0, g:range(0, 3)), Color3.new(0, 0, 0), M.SmoothPlastic))
	end
end

-- A heavy analog control desk against the end wall: a sloped panel of faded switches and a few lamps
-- still lit. wall is a frame on the wall's face at floor height, looking into the room.
local function controlDesk(g, wall: CFrame, width: number, color: Color3)
	local body = g:vary(CASES[g.random:NextInteger(1, #CASES)], 0.03)
	g:block(v(width, 3.2, 2.6), wall * CFrame.new(0, 1.6, -1.3), body, M.Metal)
	-- The sloped panel: a wedge whose slope faces the room.
	g:wedge(v(width, 1.6, 2.6), wall * CFrame.new(0, 4, -1.3), body, M.Metal)
	local slope = wall * CFrame.new(0, 4, -1.3) * CFrame.Angles(-math.atan2(1.6, 2.6), 0, 0)
	for row = 0, 1 do
		for column = 0, math.floor(width / 0.7) - 2 do
			local spot = slope * CFrame.new(-width / 2 + 0.9 + column * 0.7, 0.08, -0.6 + row * 0.9)
			if g:chance(0.12) then
				g:neon(v(0.22, 0.1, 0.22), spot, if g:chance(0.7) then color else Color3.fromRGB(255, 70, 50))
			elseif g:chance(0.8) then
				Kit.decor(g:block(v(0.16, 0.3, 0.16), spot * CFrame.Angles(g:range(-0.4, 0.4), 0, 0), Color3.fromRGB(168, 160, 140), M.SmoothPlastic))
			end
		end
	end
	-- A dead gauge panel standing on the back of it.
	Kit.decor(g:block(v(width * 0.8, 2.2, 0.4), wall * CFrame.new(0, 5.4, -0.25), g:vary(body, 0.04), M.Metal))
	for dial = 0, 2 do
		Kit.decor(g:cylinder(wall * CFrame.new(-width * 0.25 + dial * width * 0.25, 5.5, -0.48) * CFrame.Angles(0, math.pi / 2, 0), 0.08, 1.1, Color3.fromRGB(196, 188, 164), M.SmoothPlastic))
	end
end

-- An oxidised metal crate standing on the floor at base (its bottom middle).
local function crate(g, base: Vector3, size: number, turn: number)
	local color, material = g:surface("rust")
	local frame = CFrame.new(base + v(0, size / 2, 0)) * CFrame.Angles(0, turn, 0)
	g:dirty(g:block(v(size, size, size), frame, color, material), "block")
	-- Its banding.
	for _, y in { -size * 0.3, size * 0.3 } do
		Kit.decor(g:block(v(size + 0.1, 0.25, size + 0.1), frame * CFrame.new(0, y, 0), GIRDER, M.Metal))
	end
end

-- A heavy rubber cable lying slack on the floor from a to b (both at floor height): it wanders side to side
-- in lazy bends and never runs straight (River: no taut lines). coil ends it in a loose coil at b.
-- Built from short lengths of round cable, which you walk and shoot through.
local function snake(g, a: Vector3, b: Vector3, thick: number, coil: boolean)
	local along = b - a
	local length = along.Magnitude
	local side = along.Unit:Cross(Vector3.yAxis)
	local points = {}
	local steps = math.max(8, math.ceil(length / 1.5))
	local swing1, swing2 = g:range(2, 4.5), g:range(0.8, 2)
	local bends1, bends2 = g:range(1.2, 2.4), g:range(3, 5.5)
	local phase1, phase2 = g:range(0, 6.28), g:range(0, 6.28)
	for step = 0, steps do
		local t = step / steps
		local ease = math.max(math.sin(t * math.pi), 0) ^ 0.6 -- the ends stay where they're asked to
		local off = (math.sin(t * bends1 * 6.28 + phase1) * swing1 + math.sin(t * bends2 * 6.28 + phase2) * swing2) * ease
		table.insert(points, a + along * t + side * off)
	end
	if coil then
		local radius = g:range(1.4, 2.4)
		local centre = b + side * radius
		local start = math.atan2(-side.Z, -side.X)
		local turns = g:range(1.6, 2.8)
		local count = math.ceil(turns * 11)
		for step = 1, count do
			local angle = start + step / 11 * 6.28
			local r = radius * (1 - 0.35 * step / count)
			table.insert(points, centre + v(math.cos(angle) * r, 0, math.sin(angle) * r))
		end
	end
	local color = g:vary(CABLE, 0.02)
	for index = 1, #points - 1 do
		local from, to = points[index] + v(0, thick / 2, 0), points[index + 1] + v(0, thick / 2, 0)
		local frame = CFrame.lookAt((from + to) / 2, to) * CFrame.Angles(0, math.pi / 2, 0)
		Kit.decor(g:cylinder(frame, (to - from).Magnitude + thick * 0.6, thick, color, M.SmoothPlastic))
	end
end

-- The set dressing for one side. The solid things (desk and crates) stand in the dead corner on the spawn's
-- left, away from the ramp, the cover and the lanes; everything else is walked and shot through.
local function dressing(g, color: Color3)
	local endWall = CFrame.lookAt(v(-HALF_LONG, 0, 0), v(-HALF_LONG + 1, 0, 0))
	controlDesk(g, endWall * CFrame.new(-(HALF_WIDE - 18), 0, 0), 9, color) -- toward -Z, the spawn's left
	crate(g, v(-HALF_LONG + 3, 0, -HALF_WIDE + 3), 5, 0.1)
	crate(g, v(-HALF_LONG + 8.5, 0, -HALF_WIDE + 2.6), 4, -0.2)
	crate(g, v(-HALF_LONG + 3.2, 5, -HALF_WIDE + 3.2), 3.4, 0.5)
	-- Dead monitors: heaped by the desk and crates, at the back of the cover and at the foot of the ring.
	local heaps = {
		{ v(-HALF_LONG + 4, 0, -HALF_WIDE + 16), 5, 3 },
		{ v(-HALF_LONG + 12, 0, -HALF_WIDE + 6), 4, 3 },
		{ v(-COVER_X - 3, 0, COVER_HALF - 3), 3, 2 },
		{ v(-COVER_X - 3, 0, -COVER_HALF + 2), 2, 2 },
		{ v(-RING - 3, 0, 6), 3, 2.5 },
		{ v(-4, 0, RING + 3), 3, 2.5 },
		{ v(-RAMP_TOP + DECK_LENGTH + 3, 0, HALF_WIDE - 4), 4, 3 },
	}
	for _, heap in heaps do
		for _ = 1, heap[2] do
			deadMonitor(g, heap[1] + v(g:range(-heap[3], heap[3]), 0, g:range(-heap[3], heap[3])))
		end
	end
	-- Thick rubber cables snaking across the floor, from the desk out to the cover, the ring and the far corner.
	local desk = v(-HALF_LONG + 3, 0, -HALF_WIDE + 18)
	for _, to in {
		v(-COVER_X - 2, 0, -6),
		v(-COVER_X - 2, 0, 5),
		v(-RING - 4, 0, -10),
		v(-HALF_LONG + 10, 0, HALF_WIDE - RAMP_WIDE - 3),
		v(-30, 0, -HALF_WIDE + 3),
	} do
		snake(g, desk + v(g:range(0, 2), 0, g:range(-3, 3)), to, g:range(0.3, 0.45), g:chance(0.6))
	end
	-- And slung along the walls, out of reach.
	for _ = 1, 3 do
		local from = g:range(-HALF_LONG + 2, -30)
		g:cable(v(from, g:range(24, 31), HALF_WIDE - 0.3), v(from + g:range(18, 28), g:range(24, 31), HALF_WIDE - 0.3), g:range(5, 9), 0.3, CABLE)
	end
	for _ = 1, 2 do
		local from = g:range(-HALF_WIDE + 4, 0)
		g:cable(v(-HALF_LONG + 0.3, g:range(22, 30), from), v(-HALF_LONG + 0.3, g:range(22, 30), from + g:range(20, 34)), g:range(5, 9), 0.3, CABLE)
	end
end

-- One ruined tower out in the fog, standing on base (far below the arena's floor). Its top is broken:
-- stepped stumps of what's left of the upper floors, and floor slabs hanging out. No steel frames on top: they floated
-- off the stumps and read as letter Ms in the sky (River had them removed). Nothing here
-- collides or stops a bullet; it's only ever seen over the walls.
local function tower(g, base: Vector3, wide: number, deep: number, height: number, lean: number)
	local frame = CFrame.new(base) * CFrame.Angles(0, g:range(0, math.pi), 0) * CFrame.Angles(lean, 0, lean * 0.6)
	local function chunk(size: Vector3, at: CFrame, color: Color3?): BasePart
		return Kit.decor(g:block(size, frame * at, g:vary(color or TOWER, 0.02), M.Concrete))
	end
	local body = height * g:range(0.55, 0.75)
	chunk(v(wide, body, deep), CFrame.new(0, body / 2, 0))
	-- What's left above: each stump smaller and off to one corner.
	local y, w, d = body, wide, deep
	local sideX, sideZ = if g:chance(0.5) then 1 else -1, if g:chance(0.5) then 1 else -1
	for _ = 1, g.random:NextInteger(3, 5) do
		local tall = (height - body) * g:range(0.15, 0.4)
		local nextW, nextD = w * g:range(0.55, 0.85), d * g:range(0.6, 0.9)
		local x, z = sideX * (wide - nextW) / 2, sideZ * (deep - nextD) / 2
		chunk(v(nextW, tall, nextD), CFrame.new(x, y + tall / 2, z))
		-- A floor slab left hanging out of the break.
		if g:chance(0.7) then
			chunk(v(w * g:range(0.3, 0.6), 2.5, d * 0.9), CFrame.new(x - sideX * nextW * 0.6, y + 1.5, z) * CFrame.Angles(0, 0, sideX * g:range(0.05, 0.3)))
		end
		y += tall
		w, d = nextW, nextD
	end
	-- Ledges round the body every so often, so it reads as floors and not one block.
	for level = 1, 3 do
		chunk(v(wide + 3, 3, deep + 3), CFrame.new(0, body * level / 4, 0), TOWER:Lerp(Color3.new(0, 0, 0), 0.25))
	end
	return frame, body
end

-- The ruined city around the arena. Towers ring it at different distances so the near ones loom and the far
-- ones are only shapes in the fog.
local function skyline(g, colors: { Color3 })
	local count = 16
	for index = 1, count do
		local angle = (index - 1 + g:range(-0.3, 0.3)) / count * math.pi * 2
		-- Near and far by turns. The box's corners are about 95 studs from the centre.
		local distance = if index % 2 == 0 then g:range(150, 180) else g:range(200, 290)
		local wide, deep = g:range(46, 96), g:range(44, 80)
		local height = g:range(380, 620) -- from 160 below the arena floor
		local base = v(math.cos(angle) * distance, -160, math.sin(angle) * distance)
		local lean = if g:chance(0.25) then g:range(0.03, 0.09) else 0
		local frame, body = tower(g, base, wide, deep, height, lean)
		-- A few windows still lit.
		for _ = 1, g.random:NextInteger(1, 4) do
			local face = if g:chance(0.5) then 1 else -1
			local at = frame * CFrame.new(face * (wide / 2 + 0.4), body * g:range(0.6, 0.95), g:range(-deep, deep) * 0.4)
			g:neon(v(1, 3, 2.2), at, colors[g.random:NextInteger(1, #colors)])
		end
	end
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
	base:floor("floor", v(-HALF_LONG - T, -2, -HALF_WIDE - T), v(HALF_LONG + T, 0, HALF_WIDE + T), true)
	skyline(base:group("Skyline"), SIDES)
	local spawns, terminals = {}, {}
	for index, color in SIDES do
		local sideFolder = Instance.new("Folder")
		sideFolder.Name = "Side" .. index
		sideFolder.Parent = folder
		local kit = Kit.new(sideFolder, origin * CFrame.Angles(0, (index - 1) * math.pi, 0), SEED + index)
		walls(kit:group("Walls"), color)
		local ring = kit:group("Ring")
		-- Three of the six: the one facing this spawn's side wall and the two angled toward this spawn.
		for _, degrees in { 90, 150, 210 } do
			ringWall(ring, math.rad(degrees), color)
		end
		cover(kit:group("Cover"), color)
		ramp(kit:group("Ramp"))
		dressing(kit:group("Dressing"), color)
		table.insert(spawns, makeSpawn(kit))
		local console = kit:point(v(-HALF_LONG + 1.5, 0, -12))
		table.insert(terminals, Relay.buildTerminal(sideFolder, console, kit:frame(CFrame.new()).RightVector, "OUTPOST"))
	end
	folder.Parent = workspace
	return { folder = folder, spawns = spawns, terminals = terminals }
end

-- A console in another room that leads to the map.
function Hex.buildTerminal(parent: Instance, base: Vector3, facing: Vector3): ProximityPrompt
	return Relay.buildTerminal(parent, base, facing, "HEX 1V1")
end

return Hex
