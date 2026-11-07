-- The Outpost: a concrete building at sea, all of it indoors, with windows onto the fog.
-- See docs/specs/outpost.md for the layout.
-- Local axes: +Z runs along the main hall toward the Market, X along the side halls, and the
-- floors are at 6.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Guns = ReplicatedStorage:WaitForChild("Guns")
local OutpostAssets = require(Guns:WaitForChild("OutpostAssets"))
local Palette = require(Guns:WaitForChild("Palette"))
local Gable = require(script.Parent.Gable)
local Kit = require(script.Parent.Kit)
local OutpostScale = require(script.Parent.OutpostScale)

local M = Enum.Material

-- Colours for one-off parts. Amber is only for lights; signs and screens use the palette.
local RUST = Color3.fromRGB(178, 86, 34)
local SEAM = Color3.fromRGB(26, 28, 30)
local AMBER = Color3.fromRGB(255, 168, 76)
local FLUORESCENT = Color3.fromRGB(198, 234, 214)
local SKYLIGHT = Color3.fromRGB(208, 228, 232)
local RAIN = Color3.fromRGB(200, 214, 216)
local GLASS = Color3.fromRGB(170, 190, 196)
local WINDOW_LIGHT = Color3.fromRGB(150, 176, 186)
local ROCKS = { M.Basalt, M.Basalt, M.Rock, M.Slate }
local CARDBOARD = Color3.fromRGB(150, 122, 88)

local DECK = 6 -- top of the hall, arrival room and corridor floors
local SLAB_BOTTOM = 0
local SPRING = 24 -- where the hall's vault starts
local VAULT_IN = 20
local VAULT_OUT = 23
local VAULT_SEGMENTS = 16
local RIB_SEGMENTS = 8
local RIBS = { 21, 39, 57, 75, 93, 111 }
local HALL_SOUTH = 13
local HALL_NORTH = 119
local CROSS_Z = 66 -- the side halls' centre line, where they meet the main hall
-- The skylight. The vault strips leave an eight-sided opening, and a round rim sits over its edge.
local SKY_CORNER = 3.92 -- across and along, where the crown's strips meet the vault's diagonal creases
local SKY_TIP = SKY_CORNER * math.sqrt(2) -- on the halls' centre lines, so all eight sides match
local SKY_RADIUS = 4.8 -- the clear hole
local SKY_RIM = 6 -- the rim's outside edge
local CROSS_SOUTH = CROSS_Z - VAULT_IN
local CROSS_NORTH = CROSS_Z + VAULT_IN
local HALL_WEST = -123 -- the outside of the west hall's end wall
local WEST_RIBS = { -109, -91, -73, -55, -37 }
local WALL = VAULT_OUT - VAULT_IN
local CORRIDOR_SHIFT = 100 -- the test range corridor starts at the East Hall's far end
local WINDOW_SILL = 9
local WINDOW_HEAD = 21
local WINDOW_WIDTH = 10
local SEA_HALF = 448 -- far past where the fog hides it
local SEED = 7

-- The East Hall is the West Hall turned halfway round the point where the halls cross.
local EAST_TURN = CFrame.new(0, 0, CROSS_Z) * CFrame.Angles(0, math.pi, 0) * CFrame.new(0, 0, -CROSS_Z)

local Map = {}

local function v(x: number, y: number, z: number): Vector3
	return Vector3.new(x, y, z)
end

-- A cframe at position whose front faces direction.
local function facing(position: Vector3, direction: Vector3): CFrame
	return CFrame.lookAt(position, position + direction)
end

-- Moves everything built in g. Sizes and positions go through the kit, so the cframe is full size.
-- Cables hang off the terrain, so they have to be placed where they end up.
local function moveGroup(kit, g, cframe: CFrame)
	local move = kit:frame(cframe) * kit:frame(CFrame.identity):Inverse()
	for _, part in g.parent:GetDescendants() do
		if part:IsA("BasePart") then
			part.CFrame = move * part.CFrame
		end
	end
end

-- The sea around the building, and rocks fading into the fog beyond the windows.
local function outside(kit)
	local land = workspace.Terrain
	land.WaterColor = Color3.fromRGB(30, 50, 52)
	land.WaterReflectance = 0.6
	land.WaterTransparency = 0.2
	land.WaterWaveSize = 0.08
	land.WaterWaveSpeed = 4
	-- Fills whole voxels exactly, so the surface lands at 0 as asked.
	local region = Region3.new(kit:point(v(-SEA_HALF, -24, -SEA_HALF + 40)), kit:point(v(SEA_HALF, 0, SEA_HALF + 40))):ExpandToGrid(4)
	land:FillRegion(region, 4, M.Water)
	for _, rock in {
		{ -70, -24, 28 },
		{ -135, -6, 36 },
		{ -20, -46, 22 },
		{ -96, 142, 32 },
		{ -44, 160, 26 },
		{ 90, -2, 32 },
		{ 104, 132, 38 },
		{ 182, 40, 34 },
		{ 176, 104, 30 },
		{ 82, -34, 24 },
		{ -176, 62, 42 },
		{ 118, 178, 30 },
	} do
		local height = rock[3] * kit:range(0.7, 1.2)
		local turn = CFrame.Angles(kit:range(-0.15, 0.15), kit:range(0, math.pi), kit:range(-0.15, 0.15))
		local size = v(rock[3], height, rock[3] * kit:range(0.7, 1.3))
		land:FillBlock(kit:frame(CFrame.new(rock[1], height / 2 - 6, rock[2]) * turn), size * kit.scale, ROCKS[kit.random:NextInteger(1, #ROCKS)])
	end
end

-- A wall from low to high across its thickness, running along x or z from from to to, with a
-- window at each centre. inward is the side the hall is on, +1 or -1.
local function wallWithWindows(g, along: string, low: number, high: number, from: number, to: number, windows: { number }, inward: number)
	local function at(run: number, across: number, y: number): Vector3
		return if along == "z" then v(across, y, run) else v(run, y, across)
	end
	local middle = (low + high) / 2
	local cursor = from
	for _, centre in windows do
		local a, b = centre - WINDOW_WIDTH / 2, centre + WINDOW_WIDTH / 2
		g:panels("concrete", at(cursor, low, DECK), at(a, high, SPRING), 18, "wall")
		g:dirty(g:boxOf("concrete", at(a, low, DECK), at(b, high, WINDOW_SILL)), "wall")
		g:dirty(g:boxOf("concrete", at(a, low, WINDOW_HEAD), at(b, high, SPRING)), "wall")
		local glass = g:box(at(a, middle - 0.05, WINDOW_SILL), at(b, middle + 0.05, WINDOW_HEAD), GLASS, M.Glass)
		glass.Transparency = 0.75
		glass.CastShadow = false
		for _, share in { 1 / 3, 2 / 3 } do
			local run = a + WINDOW_WIDTH * share
			g:boxOf("steel", at(run - 0.12, middle - 0.2, WINDOW_SILL), at(run + 0.12, middle + 0.2, WINDOW_HEAD))
		end
		local rail = (WINDOW_SILL + WINDOW_HEAD) / 2
		g:boxOf("steel", at(a, middle - 0.25, rail - 0.12), at(b, middle + 0.25, rail + 0.12))
		-- The grey daylight coming in.
		local glow = Kit.decor(g:block(v(1, 1, 1), CFrame.new(at(centre, middle + inward * 3, rail)), GLASS, M.SmoothPlastic))
		glow.Transparency = 1
		g:light(glow, "PointLight", { Color = WINDOW_LIGHT, Range = 30, Brightness = 0.8 })
		cursor = b
	end
	g:panels("concrete", at(cursor, low, DECK), at(to, high, SPRING), 18, "wall")
end

-- Cuts the run from first to last at the ribs, skipping cuts that would leave a sliver.
-- Where two vaults cross, their inside faces meet on a diagonal crease. Each strip of vault stops
-- on that crease with a slanted end. Returns how far from the crossing's centre the slant starts
-- and finishes: a strip reaches closest on the edge nearer the crown.
local function slantReach(angle: number, width: number): (number, number)
	local offset = VAULT_IN * math.abs(math.cos(angle))
	local rise = width / 2 * math.sin(angle)
	return offset + rise, offset - rise
end

-- The same for the two strips along the crown, which stop on the skylight's opening instead. These
-- reach closest on the edge further from the crown.
local function skyReach(angle: number, width: number): (number, number)
	local offset = VAULT_IN * math.abs(math.cos(angle))
	local rise = width / 2 * math.sin(angle)
	local slope = (SKY_TIP - SKY_CORNER) / SKY_CORNER
	return SKY_TIP - slope * (offset - rise), SKY_TIP - slope * (offset + rise)
end

-- The slanted end itself. `frame` sits at the crossing's centre, with Y out of the vault and Z along
-- the strip towards the crossing.
local function vaultSlant(g, frame: CFrame, far: number, near: number, width: number, band, crown: boolean)
	local crownward = if frame.XVector.Y > 0 then 1 else -1
	local long = if crown then -crownward else crownward
	local corner = CFrame.fromMatrix(v(0, 0, -(far + near) / 2), v(0, long, 0), v(0, 0, 1), v(long, 0, 0))
	g:dirty(g:wedge(v(VAULT_OUT - VAULT_IN, far - near, width), frame * corner, band.color, band.material), "wedgeShell")
end

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
	-- Faded lines along the walls, and the drain under the skylight.
	for _, x in { -17.6, 17.6 } do
		paint:mark(x - 0.12, 15, x + 0.12, CROSS_SOUTH, Palette.Bone, 0.78)
		paint:mark(x - 0.12, CROSS_NORTH, x + 0.12, 117, Palette.Bone, 0.78)
	end
	paint:grate(-1.5, CROSS_Z - 1.5, 1.5, CROSS_Z + 1.5)
	for _, drain in { { -19.4, 46, -18.6, 50 }, { 18.6, 86, 19.4, 90 } } do
		paint:grate(drain[1], drain[2], drain[3], drain[4])
	end
	for _ = 1, 6 do
		paint:stain(g:range(-14, 14), g:range(18, 96), g:range(2, 4.5), g:range(2, 4.5), g:range(0.35, 0.6))
	end
	-- Side walls, opening into the West and East Halls.
	wallWithWindows(g, "z", -23, -20, HALL_SOUTH, CROSS_SOUTH, { 30 }, 1)
	wallWithWindows(g, "z", -23, -20, CROSS_NORTH, HALL_NORTH, { 102 }, 1)
	wallWithWindows(g, "z", 20, 23, HALL_SOUTH, CROSS_SOUTH, { 30 }, -1)
	wallWithWindows(g, "z", 20, 23, CROSS_NORTH, HALL_NORTH, { 102 }, -1)
	-- End walls below the vault.
	g:panels("concrete", v(-20, DECK, HALL_SOUTH), v(20, SPRING, 16), 14, "wall")
	g:panels("concrete", v(-20, DECK, 116), v(20, SPRING, HALL_NORTH), 14, "wall")

	-- The barrel vault, cut at the ribs and open at the top over the skylight.
	local step = math.pi / VAULT_SEGMENTS
	local middle = (VAULT_IN + VAULT_OUT) / 2
	local width = 2 * VAULT_OUT * math.sin(step / 2) + 0.1
	-- One look per band along the hall. Segments overlap at their joints, so neighbours with
	-- different looks would flicker on the end faces they share.
	local bands = {}
	for index = 1, VAULT_SEGMENTS do
		local angle = (index - 0.5) * step
		local x, y = middle * math.cos(angle), SPRING + middle * math.sin(angle)
		local turn = CFrame.Angles(0, 0, angle - math.pi / 2)
		-- Either side of the crown the vault opens where the side halls' roofs come through.
		local crown = index == VAULT_SEGMENTS / 2 or index == VAULT_SEGMENTS / 2 + 1
		local far, near = (if crown then skyReach else slantReach)(angle, width)
		local spans = { { HALL_SOUTH, CROSS_Z - far }, { CROSS_Z + far, HALL_NORTH } }
		for _, span in spans do
			local cuts = ribCuts(span[1], span[2])
			for piece = 1, #cuts - 1 do
				local from, to = cuts[piece], cuts[piece + 1]
				if not bands[from] then
					local color, material = g:surface("concrete")
					bands[from] = { color = color, material = material }
				end
				local band = bands[from]
				local part = g:block(v(width, VAULT_OUT - VAULT_IN, to - from), CFrame.new(x, y, (from + to) / 2) * turn, band.color, band.material)
				g:dirty(part, "shell")
				if to == CROSS_Z - far then
					vaultSlant(g, CFrame.new(x, y, CROSS_Z) * turn, far, near, width, band, crown)
				elseif from == CROSS_Z + far then
					vaultSlant(g, CFrame.new(x, y, CROSS_Z) * turn * CFrame.Angles(0, math.pi, 0), far, near, width, band, crown)
				end
			end
		end
	end
	-- Half-round gable walls, set back a little from the vault's ends. Each lift is its own pour.
	for _, ends in { { HALL_SOUTH + 0.3, 16 }, { 116, HALL_NORTH - 0.3 } } do
		for _, lift in Gable.lifts(VAULT_OUT, VAULT_IN) do
			local low, high = v(-lift.half, SPRING + lift.bottom, ends[1]), v(lift.half, SPRING + lift.top, ends[2])
			local part = g:box(low, high, g:vary(Color3.fromRGB(116, 123, 119), 0.03), M.Concrete)
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
			local x = radius * math.cos(angle)
			if z < CROSS_SOUTH or z > CROSS_NORTH then
				g:block(v(ribWidth, 1.4, 2.4), CFrame.new(x, SPRING + radius * math.sin(angle), z) * turn, color, material)
			end
		end
		for _, side in { -1, 1 } do
			if z < CROSS_SOUTH or z > CROSS_NORTH then
				g:dirty(g:boxOf("darkConcrete", v(side * 18.6, DECK, z - 1.2), v(side * VAULT_IN, SPRING, z + 1.2)), "block")
			end
		end
	end
end

-- A side hall: the main hall's shape again, turned sideways, with its roof running into the main
-- vault. The two vaults meet along diagonal ribs. It's laid out as the West Hall. Given a turn, it
-- becomes the East Hall, with a door in its far wall to the test range corridor.
local function sideHall(kit, name: string, turn: CFrame?)
	local g = kit:group(name)
	local wallEnd = HALL_WEST + WALL
	local function place(position: Vector3): Vector3
		return if turn then turn * position else position
	end
	local _, paint = g:floor("floor", v(HALL_WEST, SLAB_BOTTOM, CROSS_SOUTH - WALL), v(-VAULT_OUT, DECK, CROSS_NORTH + WALL), true)
	for _, z in { CROSS_Z - 17.6, CROSS_Z + 17.6 } do
		paint:mark(wallEnd + 2, z - 0.12, -VAULT_OUT, z + 0.12, Palette.Bone, 0.78)
	end
	for _, drain in { { -60, CROSS_SOUTH + 0.6, -56, CROSS_SOUTH + 1.4 }, { -96, CROSS_NORTH - 1.4, -92, CROSS_NORTH - 0.6 } } do
		paint:grate(drain[1], drain[2], drain[3], drain[4])
	end
	for _ = 1, 6 do
		paint:stain(g:range(-112, -30), g:range(CROSS_SOUTH + 4, CROSS_NORTH - 4), g:range(2, 4.5), g:range(2, 4.5), g:range(0.35, 0.6))
	end

	-- Walls.
	wallWithWindows(g, "x", CROSS_SOUTH - WALL, CROSS_SOUTH, HALL_WEST, -VAULT_OUT, { -100, -64 }, 1)
	wallWithWindows(g, "x", CROSS_NORTH, CROSS_NORTH + WALL, HALL_WEST, -VAULT_OUT, { -82, -46 }, -1)
	if turn then
		g:panels("concrete", v(HALL_WEST, DECK, CROSS_SOUTH), v(wallEnd, SPRING, CROSS_Z - 3), 14, "wall")
		g:panels("concrete", v(HALL_WEST, DECK, CROSS_Z + 3), v(wallEnd, SPRING, CROSS_NORTH), 14, "wall")
		g:dirty(g:boxOf("concrete", v(HALL_WEST, 14, CROSS_Z - 3), v(wallEnd, SPRING, CROSS_Z + 3)), "wall")
	else
		g:panels("concrete", v(HALL_WEST, DECK, CROSS_SOUTH), v(wallEnd, SPRING, CROSS_NORTH), 14, "wall")
	end

	-- The barrel vault, one look per band along the hall as in the main hall.
	local yaw = CFrame.Angles(0, math.pi / 2, 0)
	local step = math.pi / VAULT_SEGMENTS
	local middle = (VAULT_IN + VAULT_OUT) / 2
	local width = 2 * VAULT_OUT * math.sin(step / 2) + 0.1
	local bands = {}
	for index = 1, VAULT_SEGMENTS do
		local angle = (index - 0.5) * step
		local across, y = middle * math.cos(angle), SPRING + middle * math.sin(angle)
		local turn = yaw * CFrame.Angles(0, 0, angle - math.pi / 2)
		local crown = index == VAULT_SEGMENTS / 2 or index == VAULT_SEGMENTS / 2 + 1
		local far, near = (if crown then skyReach else slantReach)(angle, width)
		local stop = -far
		local cuts = { HALL_WEST }
		for _, x in WEST_RIBS do
			if stop - x >= 3 then
				table.insert(cuts, x)
			end
		end
		table.insert(cuts, stop)
		for piece = 1, #cuts - 1 do
			local from, to = cuts[piece], cuts[piece + 1]
			if not bands[piece] then
				local color, material = g:surface("concrete")
				bands[piece] = { color = color, material = material }
			end
			local band = bands[piece]
			local part = g:block(v(width, VAULT_OUT - VAULT_IN, to - from), CFrame.new((from + to) / 2, y, CROSS_Z - across) * turn, band.color, band.material)
			g:dirty(part, "shell")
			if to == stop then
				vaultSlant(g, CFrame.new(0, y, CROSS_Z - across) * turn, far, near, width, band, crown)
			end
		end
	end
	-- The half-round gable at the far end.
	for _, lift in Gable.lifts(VAULT_OUT, VAULT_IN) do
		local low = v(HALL_WEST + 0.3, SPRING + lift.bottom, CROSS_Z - lift.half)
		local high = v(wallEnd, SPRING + lift.top, CROSS_Z + lift.half)
		g:dirty(g:box(low, high, g:vary(Color3.fromRGB(116, 123, 119), 0.03), M.Concrete), "wall")
	end

	-- Ribs across the vault, with pilasters and wall lamps below them.
	local ribStep = math.pi / RIB_SEGMENTS
	local ribWidth = 2 * VAULT_IN * math.sin(ribStep / 2) + 0.1
	local radius = VAULT_IN - 0.7
	for _, x in WEST_RIBS do
		local color, material = g:surface("darkConcrete")
		for index = 1, RIB_SEGMENTS do
			local angle = (index - 0.5) * ribStep
			local turn = yaw * CFrame.Angles(0, 0, angle - math.pi / 2)
			g:block(v(ribWidth, 1.4, 2.4), CFrame.new(x, SPRING + radius * math.sin(angle), CROSS_Z - radius * math.cos(angle)) * turn, color, material)
		end
		for _, side in { -1, 1 } do
			local low, high = CROSS_Z + side * 18.6, CROSS_Z + side * VAULT_IN
			g:dirty(g:boxOf("darkConcrete", v(x - 1.2, DECK, math.min(low, high)), v(x + 1.2, SPRING, math.max(low, high))), "block")
			g:lamp(v(x, 18, CROSS_Z + side * 18.2), AMBER, 22, 1.4)
		end
	end
	-- The big lamp halfway along.
	local lamp = g:neon(v(6, 0.3, 10), CFrame.new(-73, 42.8, CROSS_Z), FLUORESCENT)
	g:light(lamp, "SpotLight", { Face = Enum.NormalId.Bottom, Angle = 60, Range = 60, Brightness = 3, Color = FLUORESCENT })

	-- Low walls to vault, crates to move around and oil drums, one knocked over.
	for _, z in { { CROSS_SOUTH, CROSS_Z - 7 }, { CROSS_Z + 7, CROSS_NORTH } } do
		g:dirty(g:boxOf("darkConcrete", v(-64, DECK, z[1]), v(-62.5, DECK + 3.5, z[2])), "block")
	end
	for _, crate in { { -100, CROSS_SOUTH + 3, 4 }, { -104, CROSS_SOUTH + 2.5, 3 }, { -104, CROSS_SOUTH + 6.5, 3.4 }, { -46, CROSS_NORTH - 3, 4 }, { -42, CROSS_NORTH - 2.5, 3 } } do
		local size = crate[3]
		g:solid("wood", v(size, size, size), CFrame.new(crate[1], DECK + size / 2, crate[2]) * CFrame.Angles(0, g:range(-0.3, 0.3), 0))
	end
	g:solid("wood", v(3, 3, 3), CFrame.new(-102, DECK + 5.5, CROSS_SOUTH + 3.5) * CFrame.Angles(0, 0.4, 0))
	for _, drum in { { -84, CROSS_NORTH - 2 }, { -81.6, CROSS_NORTH - 2.2 }, { -82.8, CROSS_NORTH - 4.4 } } do
		local drumColor, drumMaterial = g:surface("rust")
		g:post(v(drum[1], DECK, drum[2]), 2.9, 2, drumColor, drumMaterial)
	end
	local steelColor, steelMaterial = g:surface("steel")
	g:cylinder(CFrame.new(-79, DECK + 1, CROSS_NORTH - 5) * CFrame.Angles(0, math.rad(30), 0), 2.9, 2, steelColor, steelMaterial)

	-- Cables slung across the hall.
	for x = -116, -30, 7 do
		g:cable(place(v(x + g:range(-2, 2), g:range(19, 23), CROSS_Z - 19.6)), place(v(x + g:range(-4, 4), g:range(19, 23), CROSS_Z + 19.6)), g:range(3, 6))
	end
	if turn then
		moveGroup(kit, g, turn)
	end
end

-- Navy with Bone text is the only look a sign has.
local function signLook(text: string, vertical: boolean?): any
	return {
		text = text,
		color = Palette.Bone,
		fill = Palette.DeepNavy,
		back = Palette.DeepNavy,
		outline = Palette.Bone,
		light = Palette.Bone,
		vertical = vertical,
	}
end

-- A market stall knocked together inside the hall: a scaffold frame, corrugated walls, a ragged
-- awning, junk on the roof and cables running off to the walls. It backs onto z = back, opens
-- towards open (1 or -1) and returns its counter.
local function stall(g, back: number, open: number, depth: number, name: string, blade: string): BasePart
	local function z(along: number): number
		return back + open * along
	end
	local function span(kind: string, x0: number, y0: number, near: number, x1: number, y1: number, far: number): BasePart
		local low, high = math.min(z(near), z(far)), math.max(z(near), z(far))
		return g:boxOf(kind, v(x0, DECK + y0, low), v(x1, DECK + y1, high))
	end
	local function bar(a: Vector3, b: Vector3, thickness: number)
		local color, material = g:surface("steel")
		Kit.decor(g:block(v(thickness, thickness, (a - b).Magnitude), CFrame.lookAt((a + b) / 2, b), color, material))
	end

	g:dirty(span("darkConcrete", -10, 0, 0, 10, 0.8, depth), "floor")

	-- The back wall, ribbed like corrugated sheet.
	g:dirty(span("steel", -8, 0.8, 0, 8, 10.6, 1.4), "wall", 0.5)
	for x = -7.6, 7.6, 1.2 do
		Kit.decor(span("steel", x - 0.15, 0.8, 1.4, x + 0.15, 10.6, 1.55))
	end

	-- The scaffold: posts, lower sheets on the sides, and a brace across each side above them.
	for _, side in { -1, 1 } do
		for _, along in { 0.2, depth - 1 } do
			span("rust", side * 9.6 - 0.4, 0.8, along, side * 9.6 + 0.4, 11, along + 0.8)
		end
		g:dirty(span("rust", side * 9.8 - 0.1, 0.8, 1, side * 9.8 + 0.1, 5.5, depth - 1), "wall", 0.5)
		bar(v(side * 9.8, DECK + 5.5, z(1)), v(side * 9.8, DECK + 11, z(depth - 1)), 0.25)
	end

	-- The roof, with the sign across a fascia at its front.
	g:dirty(span("steel", -10, 11, 0, 10, 11.6, depth + 0.4), "block", 0.45)
	g:dirty(span("steel", -10, 11.6, depth, 10, 15.4, depth + 0.4), "block")
	local toHall = v(0, 0, open)
	g:sign(facing(v(0, DECK + 13.5, z(depth + 0.45)), toHall), 18, 3, signLook(name))

	-- A short sign hung off the corner, on a bracket, reads from down the hall.
	span("steel", -11.2, 12.4, depth - 0.2, -9.6, 12.7, depth + 0.1)
	span("steel", -11.2, 3.6, depth - 0.2, -9.6, 3.9, depth + 0.1)
	g:sign(facing(v(-11.8, DECK + 8.1, z(depth)), toHall), 1.6, 9.2, signLook(blade, true))

	-- The awning, in strips that don't quite agree, so it looks like tarp and not a plank.
	local strips = 6
	local reach = 3.4
	for strip = 1, strips do
		local width = 20 / strips
		local x = -10 + (strip - 0.5) * width
		local tilt = math.rad(g:range(14, 24))
		local color = if strip % 2 == 0 then Palette.Bone else Palette.DeepNavy
		local out = reach * g:range(0.85, 1.05) / 2
		local at = CFrame.new(x, DECK + 11.3 - math.sin(tilt) * out, z(depth + 0.4 + math.cos(tilt) * out))
		Kit.decor(g:block(v(width + 0.1, 0.12, out * 2), at * CFrame.Angles(open * tilt, 0, 0), g:vary(color, 0.04), M.Fabric))
	end

	-- Junk on the roof behind a rail.
	for _, side in { -1, 1 } do
		bar(v(side * 9.7, DECK + 14, z(0.3)), v(side * 9.7, DECK + 14, z(depth)), 0.14)
		for along = 0.3, depth, 2.4 do
			bar(v(side * 9.7, DECK + 11.6, z(along)), v(side * 9.7, DECK + 14, z(along)), 0.14)
		end
	end
	bar(v(-9.7, DECK + 14, z(0.3)), v(9.7, DECK + 14, z(0.3)), 0.14)
	span("steel", 3, 11.6, 2, 6.4, 13.4, 4.4)
	span("darkConcrete", 3.6, 13.4, 2.4, 5.8, 13.5, 4)
	for _, box in { { -6, 3, 2.4 }, { -3.4, 2.6, 1.8 }, { -5.2, 5.4, 1.5 } } do
		g:block(
			v(box[3], box[3] * 0.8, box[3]),
			CFrame.new(box[1], DECK + 11.6 + box[3] * 0.4, z(box[2])) * CFrame.Angles(0, g:range(-0.4, 0.4), 0),
			g:vary(CARDBOARD, 0.06),
			M.Cardboard
		)
	end

	-- An air conditioner on the side, and cables off to the hall's walls.
	span("steel", 10, 7, 3, 11.4, 9, 6)
	for along = 3.3, 5.7, 0.4 do
		Kit.decor(g:box(v(11.4, DECK + 7.2, z(along) - 0.08), v(11.46, DECK + 8.8, z(along) + 0.08), SEAM, M.Metal))
	end
	for index, along in { 0.8, 3, 5.5 } do
		g:cable(v(-9.8, DECK + 11.4, z(along)), v(-19.6, DECK + g:range(13, 17), z(along + index)), g:range(1.5, 3))
		g:cable(v(9.8, DECK + 11.4, z(along)), v(19.6, DECK + g:range(13, 17), z(along - index)), g:range(1.5, 3))
	end

	-- Warm light inside, which is what makes a stall read as open.
	for _, x in { -4, 4 } do
		g:lamp(v(x, DECK + 10.4, z(depth / 2)), AMBER, 14, 1.2, false, 0.5)
	end
	for _, box in { { -8.6, depth - 2.6, 1.4 }, { 8.6, depth - 3.6, 1.2 }, { 8.2, depth - 2.1, 1 } } do
		g:block(
			v(box[3], box[3] * 0.8, box[3]),
			CFrame.new(box[1], DECK + 0.8 + box[3] * 0.4, z(box[2])) * CFrame.Angles(0, g:range(-0.4, 0.4), 0),
			g:vary(CARDBOARD, 0.06),
			M.Cardboard
		)
	end

	local counter = g:dirty(span("steel", -7, 0.8, depth - 1.8, 7, 4.2, depth - 0.4), "wall", 0.5)
	span("steel", -7.2, 4.2, depth - 2, 7.2, 4.4, depth - 0.2)
	g:neon(v(14, 0.2, 0.08), CFrame.new(0, DECK + 3.5, z(depth - 0.34)), Palette.Bone)
	return counter
end

-- The matchmaking booth against the main hall's south wall, opposite the Market. Its back wall
-- holds three screens.
local function matchmakingBooth(kit)
	local g = kit:group("MatchmakingBooth")
	g.noNeon = true
	local counter = stall(g, 16, 1, 10, "MATCHMAKING", "PLAY")
	for _, x in { -5, 0, 5 } do
		Kit.decor(g:block(v(4, 3, 0.2), CFrame.new(x, DECK + 7, 17.65), Palette.DeepNavy, M.SmoothPlastic))
		for line, width in { 3, 2.2, 2.7 } do
			g:neon(v(width, 0.12, 0.05), CFrame.new(x - (3 - width) / 2, DECK + 7.7 - line * 0.5 + 0.2, 17.78), Palette.Bone)
		end
	end
	return g:prompt(counter, "MATCHMAKING", "Soon")
end

local function hallInside(kit)
	local g = kit:group("HallInside")
	-- Lamps at the south end, where you spawn.
	for _, x in { -14, 14 } do
		g:lamp(v(x, 20, 16.6), AMBER, 18, 1.4)
	end
	for _, z in { 21, 39, 93, 111 } do
		g:lamp(v(-18.2, 18, z), AMBER, 22, 1.4)
	end
	-- The catwalk along the east wall, in two runs with the East Hall's mouth open between them.
	local runs = { { 18, CROSS_SOUTH }, { CROSS_NORTH, 108 } }
	local function onRun(z: number): boolean
		return z <= CROSS_SOUTH or z >= CROSS_NORTH
	end
	for _, run in runs do
		g:dirty(g:boxOf("plate", v(12, 16.4, run[1]), v(20, 17, run[2])), "floor")
		-- The rails are a touch thicker than the posts, so they don't share faces.
		g:boxOf("steel", v(11.97, 20.2, math.max(run[1], 22)), v(12.23, 20.4, run[2]))
		g:boxOf("steel", v(11.97, 18.6, math.max(run[1], 22)), v(12.23, 18.8, run[2]))
	end
	for z = 18.3, 108, 15 do
		if onRun(z) then
			g:boxOf("steel", v(12.6, 15.8, z - 0.3), v(20, 16.4, z + 0.3))
		end
	end
	for _, z in { 18.5, 33, CROSS_SOUTH - 1, CROSS_NORTH + 1, 100, 107.5 } do
		g:boxOf("steel", v(12, DECK, z - 0.3), v(12.6, 16.4, z + 0.3))
	end
	for z = 22, 108, 6 do
		if onRun(z) then
			g:boxOf("steel", v(12, 17, z - 0.1), v(12.2, 20.2, z + 0.1))
		end
	end
	g:boxOf("steel", v(12, 20.2, 107.8), v(20, 20.4, 108))

	-- Two plates hung from the roof carry the jump across the gap, so the floor stays open. White
	-- edges mark every take-off.
	local function edge(z: number, x0: number, x1: number, top: number)
		Kit.decor(g:box(v(x0, top, z - 0.35), v(x1, top + 0.05, z + 0.35), Palette.Bone, M.SmoothPlastic))
	end
	edge(CROSS_SOUTH - 0.4, 12, 20, 17)
	edge(CROSS_NORTH + 0.4, 12, 20, 17)
	for _, plate in { { 14, 20, 55.3, 18.5 }, { 12, 18, 70.7, 17 } } do
		local x0, x1, z0, top = plate[1], plate[2], plate[3], plate[4]
		local z1 = z0 + 6
		g:dirty(g:boxOf("plate", v(x0, top - 0.6, z0), v(x1, top, z1)), "floor")
		edge(z0 + 0.4, x0, x1, top)
		edge(z1 - 0.4, x0, x1, top)
		for _, corner in { { x0 + 0.6, z0 + 0.6 }, { x1 - 0.6, z0 + 0.6 }, { x0 + 0.6, z1 - 0.6 }, { x1 - 0.6, z1 - 0.6 } } do
			-- Up to whichever vault is overhead here, and a little into it.
			local under = math.min(corner[1], math.abs(corner[2] - CROSS_Z))
			local roof = SPRING + math.sqrt(VAULT_IN ^ 2 - under ^ 2) + 0.5
			local color, material = g:surface("steel")
			g:post(v(corner[1], top, corner[2]), roof - top, 0.25, color, material)
		end
	end

	for _, crate in { { 15, 28, 3 }, { 17.5, 32, 2.4 }, { 16, 34.5, 2 } } do
		local size = crate[3]
		g:solid("wood", v(size, size, size), CFrame.new(crate[1], DECK + size / 2, crate[2]) * CFrame.Angles(0, g:range(-0.3, 0.3), 0))
	end

	-- The Market stall at the far end, with shelves of blank cards.
	g.noNeon = true
	local counter = stall(g, 116, -1, 12, "MARKET", "CARDS")
	g.noNeon = nil
	local cardColors = { Palette.Bone, Palette.DeepNavy }
	for row, height in { 3.5, 6.5, 9 } do
		g:boxOf("wood", v(-8, DECK + height, 113), v(8, DECK + height + 0.25, 114.6))
		for index = 1, 6 do
			local x = -6.5 + (index - 1) * 2.6
			g:block(
				v(0.9, 1.3, 0.25),
				CFrame.new(x, DECK + height + 0.9, 113.9) * CFrame.Angles(math.rad(-8), g:range(-0.15, 0.15), 0),
				cardColors[(index + row) % 2 + 1],
				M.SmoothPlastic
			)
		end
	end
	local market = g:prompt(counter, "MARKET", "Soon")

	-- Daylight through the skylight, with rain falling through it.
	-- The spotlight hangs under the roof, because the long slot above would cut its pool into a box.
	-- The pieces overlap at the back, so every other one stands a touch prouder to keep their faces apart.
	local rimColor, rimMaterial = g:surface("darkConcrete")
	local rimDepth = SKY_RIM - SKY_RADIUS
	local rimPieces = 32
	local rimWidth = 2 * SKY_RIM * math.tan(math.pi / rimPieces) + 0.05
	for piece = 1, rimPieces do
		local around = (piece - 0.5) / rimPieces * 2 * math.pi
		local middle = v(SKY_RADIUS + rimDepth / 2, 0, 0)
		local stagger = if piece % 2 == 0 then 0.03 else 0
		local at = CFrame.new(0, SPRING + 21.3, CROSS_Z) * CFrame.Angles(0, around, 0)
		g:block(v(rimDepth, 4 + stagger, rimWidth), at * CFrame.new(middle), rimColor, rimMaterial)
	end
	local sun = Kit.decor(g:block(v(1, 1, 1), CFrame.new(0, 43, CROSS_Z), SKYLIGHT, M.SmoothPlastic))
	sun.Transparency = 1
	g:light(sun, "SpotLight", { Face = Enum.NormalId.Bottom, Angle = 27, Range = 60, Brightness = 6, Shadows = true, Color = SKYLIGHT })
	g:shaft(v(0, 46.5, CROSS_Z), v(0, DECK + 0.2, CROSS_Z), 6.5, SKYLIGHT)
	local drips = Kit.decor(g:block(v(6, 0.2, 6), CFrame.new(0, 46, CROSS_Z), RAIN, M.SmoothPlastic))
	drips.Transparency = 1
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = OutpostAssets.rain
	emitter.Color = ColorSequence.new(RAIN)
	emitter.EmissionDirection = Enum.NormalId.Bottom
	emitter.Orientation = Enum.ParticleOrientation.FacingCameraWorldUp -- keeps the streak upright
	emitter.Rate = 25
	emitter.Lifetime = NumberRange.new(0.8, 1)
	emitter.Speed = NumberRange.new(45, 55)
	emitter.Size = NumberSequence.new(1.6)
	emitter.Transparency = NumberSequence.new(0.45)
	emitter.LightInfluence = 0.6
	emitter.Parent = drips

	-- Cables slung across the hall.
	for z = 18, 112, 7 do
		if z < CROSS_SOUTH - 4 or z > CROSS_NORTH + 4 then
			g:cable(v(-19.6, g:range(19, 23), z + g:range(-2, 2)), v(19.6, g:range(19, 23), z + g:range(-4, 4)), g:range(3, 6))
		end
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

	-- Lift doors to the test room. The frame's head sits on its jambs rather than overlapping them.
	g:boxOf("steel", v(49.6, DECK, 62.6), v(50, 14, 63.2))
	g:boxOf("steel", v(49.6, DECK, 68.8), v(50, 14, 69.4))
	g:boxOf("steel", v(49.6, 14, 62.6), v(50, 14.6, 69.4))
	local door = g:dirty(g:box(v(49.7, DECK, 63.2), v(49.9, 14, 66), Color3.fromRGB(120, 126, 126), M.Metal), "wall", 0.5)
	g:dirty(g:box(v(49.7, DECK, 66), v(49.9, 14, 68.8), Color3.fromRGB(116, 122, 122), M.Metal), "wall", 0.5)
	Kit.decor(g:box(v(49.56, 9.4, 63.2), v(49.62, 9.9, 68.8), RUST, M.SmoothPlastic))
	g:neon(v(0.08, 2.7, 0.4), CFrame.new(49.6, 11.85, 69.8), Palette.Bone)
	g:lamp(v(48.4, 14.4, 66), AMBER, 10, 1)
	local prompt = g:prompt(door, "TEST RANGE", "Travel", 0.4)
	moveGroup(kit, g, CFrame.new(CORRIDOR_SHIFT, 0, 0))
	return prompt
end

local function makeSpawn(kit): SpawnLocation
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "OutpostSpawn"
	spawn.Anchored = true
	spawn.Size = v(6, 1, 6)
	spawn.CFrame = kit:frame(CFrame.new(45, DECK, CROSS_Z) * CFrame.Angles(0, math.pi / 2, 0)) * CFrame.new(0, -spawn.Size.Y / 2, 0)
	spawn.Transparency = 1
	spawn.CanCollide = false
	spawn.CanQuery = false
	spawn.CanTouch = false
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Parent = kit.parent
	return spawn
end

-- Builds the Outpost at origin. Returns its spawn and the prompts the server answers.
function Map.build(origin: CFrame)
	local folder = Instance.new("Folder")
	folder.Name = "Outpost"
	local kit = Kit.new(folder, origin, SEED, OutpostScale.factor)

	outside(kit)
	local spawn = makeSpawn(kit)
	hallShell(kit)
	sideHall(kit, "WestHall")
	sideHall(kit, "EastHall", EAST_TURN)
	local market = hallInside(kit)
	local matchmaking = matchmakingBooth(kit)
	local testRoomDoor = rangeCorridor(kit)
	kit:finish(folder)

	folder.Parent = workspace
	return {
		folder = folder,
		spawn = spawn,
		testRoomDoor = testRoomDoor,
		market = market,
		matchmaking = matchmaking,
	}
end

-- A terminal beside the test room's spawn that leads back to the Outpost.
function Map.buildReturnTerminal(room: Instance, spawn: BasePart): ProximityPrompt
	local kit = Kit.new(room, CFrame.identity, SEED)
	local base = spawn.Position + v(9, -spawn.Size.Y / 2, 0)
	local console = kit:box(base + v(-1.2, 0, -1), base + v(1.2, 4, 1), Palette.DeepNavy, M.Metal)
	kit:sign(facing(base + v(-1.4, 3, 0), v(-1, 0, 0)), 1.8, 0.9, {
		text = "OUTPOST",
		color = Palette.Bone,
		fill = Palette.DeepNavy,
		back = Palette.DeepNavy,
		light = Palette.Bone,
	})
	return kit:prompt(console, "OUTPOST", "Travel", 0.4)
end

return Map
