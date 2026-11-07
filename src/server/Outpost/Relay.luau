-- Relay: the 1v1 map. Two identical relay towers stand in fog, joined by a bridge, with a block
-- of flats and fire stairs hanging underneath it. See docs/specs/relay.md for the layout.
-- The map is point-symmetric. One side is built, then the same build runs again turned halfway
-- round the centre with the same seed, so the two towers match exactly.
-- Side axes: this side's tower is toward -X, the bridge runs along X to the centre at X = 0, and
-- the bridge deck is at Y = 0. Nothing a side builds crosses X = 0 except where it meets its copy.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Guns = ReplicatedStorage:WaitForChild("Guns")
local Collision = require(Guns:WaitForChild("Collision"))
local Palette = require(Guns:WaitForChild("Palette"))
local Kit = require(script.Parent.Kit)

local M = Enum.Material

local SEED = 41
local T = 1 -- wall thickness
local STEP = 0.75 -- stair riser height

-- The tower.
local FACADE = -40 -- outside of the wall facing the bridge
local BACK = -76 -- outside of the back wall
local HALF = 14 -- half the tower's width along Z
local L1, L2, L3, ROOF = 0, 12, 24, 34 -- tops of the floors: lobby, operations, top floor, roof
local HULL_BOTTOM = -12 -- the tower's closed lower floors end here; the stem goes on below
local SHAFT = Vector3.new(-58, 0, 0) -- the ladder up the middle of the tower, lobby to top floor
local SHAFT_HOLE = { -62, -54, -4, 4 } -- the hole it climbs through in each upper floor: x0, x1, z0, z1
local STAIR_3 = { -66, -46, -13, -7 } -- hole in the roof for the stairs, under the stair house
local DRUM = Vector3.new(-53, 0, 18) -- the round wing's centre
local DRUM_RADIUS = 8
local DRUM_SIDES = 12
local DRUM_BOTTOM = -10
local CABIN_TOP = 42 -- the stair house's roof
local BALCONY_DEPTH = 4.5 -- the top floor's balcony, out from the facade
-- The bridge and what hangs under it.
local BRIDGE_HALF = 7
local GIRDER_BOTTOM = -6
local UNDER = -16 -- floor of the undercity
local FLATS_END = -10 -- west face of the hanging block of flats
local FLATS_HALF = 20
local FLATS_BOTTOM = -40
local STAIR_TOP = -33 -- where the stairs to the flats leave the bridge level, along X
local STAIR_FOOT = -13.5 -- where they reach the platform at the flats' door
local STAIR_SIDE = { 8, 15 } -- the stairs' width, along Z, beside the bridge's +Z edge

local RAIL = 3.6 -- railing height; railings block feet, not bullets, and can't be parried off
local FALL_DEPTH = -60 -- below this a player has fallen into the fog

local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

local AMBER = rgb(255, 170, 84)
local WARM = rgb(255, 204, 150)
local FLUORESCENT = rgb(204, 238, 228)
local DIM = rgb(150, 196, 204)
local TRIM = rgb(96, 116, 120)
local IRON = rgb(28, 30, 32) -- bent black railings
local GREEN = rgb(66, 124, 88) -- painted steel
local DARK_STEEL = rgb(46, 52, 54) -- the stairs down to the flats
local DISH = rgb(222, 232, 232)
local POLE = rgb(52, 58, 60)
local ORANGE = rgb(206, 92, 50)
local RUST = rgb(150, 70, 40)
local SNOW = rgb(238, 246, 248)
local LEAF = rgb(70, 116, 58)
local LEAF_DARK = rgb(52, 92, 50)
local POT = rgb(164, 104, 72)
local GLASS = rgb(40, 56, 62)
local CLOTHES = {
	rgb(214, 120, 90),
	rgb(120, 150, 190),
	rgb(226, 222, 210),
	rgb(60, 78, 110),
	rgb(196, 170, 96),
	rgb(150, 70, 70),
	rgb(170, 196, 214),
}

-- Looks for each kind of surface. Each part takes one, then a slight colour shift.
local LOOKS: { [string]: { { any } } } = {
	hull = {
		{ M.Concrete, rgb(152, 180, 180) },
		{ M.Metal, rgb(140, 170, 172) },
		{ M.Plaster, rgb(158, 184, 180) },
		{ M.CorrodedMetal, rgb(146, 174, 172) },
	},
	hullDark = {
		{ M.Concrete, rgb(110, 136, 140) },
		{ M.Metal, rgb(102, 128, 134) },
		{ M.CorrodedMetal, rgb(116, 140, 142) },
	},
	inside = {
		{ M.Plaster, rgb(176, 192, 186) },
		{ M.Plaster, rgb(166, 184, 180) },
		{ M.Concrete, rgb(170, 186, 180) },
	},
	floor = {
		{ M.CeramicTiles, rgb(124, 136, 132) },
		{ M.Concrete, rgb(118, 128, 126) },
	},
	deck = {
		{ M.DiamondPlate, rgb(98, 108, 108) },
		{ M.DiamondPlate, rgb(106, 114, 112) },
	},
	roof = {
		{ M.Concrete, rgb(168, 188, 188) },
		{ M.Concrete, rgb(160, 182, 184) },
	},
	girder = {
		{ M.CorrodedMetal, rgb(132, 164, 166) },
		{ M.Metal, rgb(126, 156, 160) },
	},
	stairs = {
		{ M.Concrete, rgb(150, 160, 156) },
		{ M.Concrete, rgb(142, 152, 150) },
	},
	steel = {
		{ M.Metal, GREEN },
		{ M.CorrodedMetal, rgb(78, 122, 90) },
	},
	grating = {
		{ M.DiamondPlate, rgb(62, 68, 70) },
		{ M.DiamondPlate, rgb(56, 62, 64) },
	},
	flats = {
		{ M.Concrete, rgb(72, 84, 102) },
		{ M.Plaster, rgb(80, 92, 110) },
		{ M.Concrete, rgb(64, 76, 94) },
	},
	flatsInside = {
		{ M.Plaster, rgb(150, 156, 146) },
		{ M.Plaster, rgb(140, 150, 144) },
	},
	flatsFloor = {
		{ M.WoodPlanks, rgb(104, 82, 62) },
		{ M.Concrete, rgb(92, 96, 96) },
	},
	crate = {
		{ M.WoodPlanks, rgb(122, 98, 68) },
		{ M.Wood, rgb(112, 88, 62) },
	},
	machine = {
		{ M.Metal, rgb(84, 96, 100) },
		{ M.Metal, rgb(70, 80, 86) },
	},
	ac = {
		{ M.SmoothPlastic, rgb(214, 220, 214) },
		{ M.Metal, rgb(196, 204, 200) },
	},
}

local function v(x: number, y: number, z: number): Vector3
	return Vector3.new(x, y, z)
end

-- A cframe at position whose front faces direction.
local function face(position: Vector3, direction: Vector3): CFrame
	return CFrame.lookAt(position, position + direction)
end

local function paint(g, look: string): (Color3, Enum.Material)
	local choices = LOOKS[look]
	local pick = choices[g.random:NextInteger(1, #choices)]
	return g:vary(pick[2], 0.03), pick[1]
end

local function box(g, look: string, a: Vector3, b: Vector3): BasePart
	local color, material = paint(g, look)
	return g:box(a, b, color, material)
end

local function block(g, look: string, size: Vector3, cframe: CFrame): BasePart
	local color, material = paint(g, look)
	return g:block(size, cframe, color, material)
end

-- Invisible. query says whether bullets and the edge check see it; parts they don't see go in
-- the feet-only collision group, since a colliding part can't turn CanQuery off.
local function ghost(part: BasePart, query: boolean): BasePart
	part.Transparency = 1
	part.CastShadow = false
	part.CanTouch = false
	if not query then
		Collision.feetOnly(part)
	end
	return part
end

-- A thin bar from a to b. Looks only.
local function beam(g, a: Vector3, b: Vector3, thick: number, color: Color3, material: Enum.Material?): BasePart?
	local length = (b - a).Magnitude
	if length < 0.01 then
		return nil
	end
	local middle = (a + b) / 2
	local up = if math.abs((b - a).Unit.Y) > 0.99 then Vector3.xAxis else Vector3.yAxis
	return Kit.decor(g:block(Vector3.new(thick, thick, length), CFrame.lookAt(middle, b, up), color, material or M.Metal))
end

local function subtract(spans: { { number } }, low: number, high: number): { { number } }
	local out = {}
	for _, span in spans do
		if high <= span[1] or low >= span[2] then
			table.insert(out, span)
		else
			if low > span[1] then
				table.insert(out, { span[1], low })
			end
			if high < span[2] then
				table.insert(out, { high, span[2] })
			end
		end
	end
	return out
end

-- Cuts the rectangle a0..a1 by b0..b1 around holes { a0, a1, b0, b1 } and hands each piece to emit.
local function grid(a0: number, a1: number, b0: number, b1: number, holes: { { number } }, emit: (number, number, number, number) -> ())
	local cuts = { a0, a1 }
	for _, hole in holes do
		table.insert(cuts, math.clamp(hole[1], a0, a1))
		table.insert(cuts, math.clamp(hole[2], a0, a1))
	end
	table.sort(cuts)
	for index = 1, #cuts - 1 do
		local low, high = cuts[index], cuts[index + 1]
		if high - low > 0.01 then
			local spans = { { b0, b1 } }
			for _, hole in holes do
				if hole[1] <= low + 0.01 and hole[2] >= high - 0.01 then
					spans = subtract(spans, hole[3], hole[4])
				end
			end
			for _, span in spans do
				if span[2] - span[1] > 0.01 then
					emit(low, high, span[1], span[2])
				end
			end
		end
	end
end

-- A floor slab from y0 to y1 with holes { x0, x1, z0, z1 }.
local function slab(g, look: string, x0: number, x1: number, z0: number, z1: number, y0: number, y1: number, holes: { { number } }?, how: string?)
	grid(x0, x1, z0, z1, holes or {}, function(a, b, c, d)
		local part = box(g, look, v(a, y0, c), v(b, y1, d))
		if how then
			g:dirty(part, how)
		end
	end)
end

-- A wall in the plane x = at (axis "x") or z = at (axis "z"), running from..to along the other
-- ground axis and low..high up. Holes are { from, to, bottom, top }.
local function wall(g, look: string, axis: string, at: number, thick: number, from: number, to: number, low: number, high: number, holes: { { any } }?, how: string?)
	grid(from, to, low, high, holes or {}, function(a, b, c, d)
		local p0, p1
		if axis == "x" then
			p0, p1 = v(at - thick / 2, c, a), v(at + thick / 2, d, b)
		else
			p0, p1 = v(a, c, at - thick / 2), v(b, d, at + thick / 2)
		end
		local part = box(g, look, p0, p1)
		if how ~= "none" then
			g:dirty(part, how or "wall")
		end
	end)
end

-- A point on a wall plane: along the wall, up, and out from its centre line.
local function onWall(axis: string, at: number, along: number, y: number, out: number): Vector3
	if axis == "x" then
		return v(at + out, y, along)
	end
	return v(along, y, at + out)
end

local function snowOn(g, a: Vector3, b: Vector3)
	Kit.decor(g:box(a, b, g:vary(SNOW, 0.02), M.Snow))
end

-- Frames each opening a wall's holes left. side is 1 or -1, toward the outside.
-- Kinds: "door" (a head only), "open" (a frame and nothing in it), "pane" (an invisible pane
-- that stops falls but not bullets), "bars" (a pane behind iron bars).
local function openings(g, axis: string, at: number, side: number, list: { { any } })
	local outer = side * T / 2
	for _, hole in list do
		local a0, a1, y0, y1, kind = hole[1], hole[2], hole[3], hole[4], hole[5]
		local color = g:vary(TRIM, 0.04)
		Kit.decor(g:box(onWall(axis, at, a0 - 0.3, y1, outer), onWall(axis, at, a1 + 0.3, y1 + 0.3, outer + side * 0.3), color, M.Metal))
		if kind ~= "door" then
			Kit.decor(g:box(onWall(axis, at, a0 - 0.2, y0 - 0.25, outer), onWall(axis, at, a1 + 0.2, y0, outer + side * 0.45), color, M.Metal))
			snowOn(g, onWall(axis, at, a0 - 0.15, y0, outer), onWall(axis, at, a1 + 0.15, y0 + 0.16, outer + side * 0.42))
			Kit.decor(g:box(onWall(axis, at, a0 - 0.2, y0, outer), onWall(axis, at, a0, y1, outer + side * 0.2), color, M.Metal))
			Kit.decor(g:box(onWall(axis, at, a1, y0, outer), onWall(axis, at, a1 + 0.2, y1, outer + side * 0.2), color, M.Metal))
		end
		if kind == "pane" or kind == "bars" then
			ghost(g:box(onWall(axis, at, a0, y0, -0.1), onWall(axis, at, a1, y1, 0.1), GLASS, M.Glass), false)
		end
		if kind == "bars" then
			local count = math.max(2, math.round((a1 - a0) / 0.55))
			for index = 1, count - 1 do
				local along = a0 + (a1 - a0) * index / count
				beam(g, onWall(axis, at, along, y0, outer + side * 0.15), onWall(axis, at, along, y1, outer + side * 0.15), 0.1, IRON)
			end
			for _, y in { y0 + (y1 - y0) * 0.33, y0 + (y1 - y0) * 0.66 } do
				beam(g, onWall(axis, at, a0, y, outer + side * 0.15), onWall(axis, at, a1, y, outer + side * 0.15), 0.08, IRON)
			end
		end
	end
end

-- A window that's only painted on: a lit or dark pane on a wall's outside.
local function fakeWindow(g, axis: string, at: number, side: number, a0: number, a1: number, y0: number, y1: number, lit: boolean)
	local outer = side * T / 2
	local pane = g:box(onWall(axis, at, a0, y0, outer), onWall(axis, at, a1, y1, outer + side * 0.15), if lit then g:vary(WARM, 0.06) else GLASS, if lit then M.Neon else M.Glass)
	Kit.decor(pane)
	if lit then
		pane.Transparency = 0.25
	end
	openings(g, axis, at, side, { { a0, a1, y0, y1, "open" } })
end

-- A railing from a to b, both at floor height. Posts and rails are looks only; an invisible wall
-- that bullets and the edge check ignore keeps feet in.
local function rail(g, a: Vector3, b: Vector3, color: Color3?)
	local along = b - a
	local length = along.Magnitude
	if length < 0.05 then
		return
	end
	local tint = color or IRON
	local up = Vector3.new(0, RAIL, 0)
	local middle = (a + b) / 2 + up / 2
	local stop = g:block(Vector3.new(0.3, RAIL, length), CFrame.lookAt(middle, middle + along), tint, M.SmoothPlastic)
	ghost(stop, false)
	-- Rails and posts differ in thickness, so where they cross no two faces share a plane.
	beam(g, a + up, b + up, 0.24, tint)
	beam(g, a + up * 0.5, b + up * 0.5, 0.05, tint)
	local count = math.max(1, math.ceil(length / 2.4))
	g.posts = g.posts or {}
	for index = 0, count do
		local base = a + along * (index / count)
		-- Posts are upright, so two railings ending at the same spot share one, whatever the heights.
		local key = string.format("%d %d", math.round(base.X * 3), math.round(base.Z * 3))
		if not g.posts[key] and math.abs(base.X) > 0.05 then
			g.posts[key] = true
			beam(g, base, base + up, 0.12, tint)
		end
	end
end

-- A flight of stairs climbing from (along0, y0) to (along1, y1). Along runs on X or Z (axis);
-- across0..across1 is its width on the other ground axis. rails lists the across edges that get
-- railings. Steel stairs are open treads; concrete ones are solid down to fillTo when given.
-- An invisible ramp under the treads does the walking, so feet glide instead of stepping.
local function flight(g, look: string, axis: string, along0: number, y0: number, along1: number, y1: number, across0: number, across1: number, rails: { number }, railColor: Color3?, fillTo: number?)
	local function at(a: number, y: number, c: number): Vector3
		if axis == "x" then
			return v(a, y, c)
		end
		return v(c, y, a)
	end
	local rise = y1 - y0
	local count = math.max(2, math.round(rise / STEP))
	local h = rise / count
	local d = (along1 - along0) / count
	local steel = look == "steel" or look == "grating"
	local frame = if look == "grating" then DARK_STEEL else GREEN
	for index = 1, count do
		local a0, a1 = along0 + d * (index - 1), along0 + d * index
		local top = y0 + h * index
		local bottom = if steel then top - 0.2 elseif fillTo then fillTo else top - h - 0.9
		local tread = box(g, look, at(a0, bottom, across0), at(a1, top, across1))
		if steel then
			Kit.decor(tread)
		end
	end
	local p0 = at(along0, y0 + h * 0.5, (across0 + across1) / 2)
	local p1 = at(along1, y1 + h * 0.5, (across0 + across1) / 2)
	local cframe = CFrame.lookAt((p0 + p1) / 2, p1)
	local width = math.abs(across1 - across0)
	ghost(g:block(Vector3.new(width, 1, (p1 - p0).Magnitude + 0.6), cframe - cframe.UpVector * 0.5, GREEN, M.SmoothPlastic), true)
	if steel then
		for _, edge in { across0, across1 } do
			beam(g, at(along0, y0 - 0.35, edge), at(along1, y1 - 0.35, edge), 0.32, g:vary(frame, 0.03))
		end
	end
	for _, edge in rails do
		rail(g, at(along0, y0 + h * 0.5, edge), at(along1, y1 + h * 0.5, edge), railColor or (if steel then frame else IRON))
	end
end

-- A free-standing ladder rising from base, its rungs on the side facing out. An invisible
-- TrussPart is what Roblox climbs (from any side; it stops feet, not bullets); the rails, rungs
-- and the post behind them are looks only. height must be even: a truss comes in 2-stud steps.
local function ladder(g, base: Vector3, out: Vector3, height: number)
	local look = face(base, out)
	local truss = Instance.new("TrussPart")
	truss.Style = Enum.Style.NoSupports
	g:place(truss, Vector3.new(2, height, 2), look * CFrame.new(0, height / 2, 0), DARK_STEEL, M.Metal)
	ghost(truss, false)
	local color = g:vary(DARK_STEEL, 0.03)
	local front = -0.85
	for _, across in { -0.85, 0.85 } do
		beam(g, (look * CFrame.new(across, 0, front)).Position, (look * CFrame.new(across, height, front)).Position, 0.18, color)
	end
	for rise = 0.8, height - 0.2, 0.9 do
		beam(g, (look * CFrame.new(-0.85, rise, front)).Position, (look * CFrame.new(0.85, rise, front)).Position, 0.12, color)
	end
	-- A steel post behind the rungs, braced to the rails every few studs.
	beam(g, (look * CFrame.new(0, 0, 0.4)).Position, (look * CFrame.new(0, height, 0.4)).Position, 0.5, color)
	for rise = 2, height - 1, 4 do
		for _, across in { -0.85, 0.85 } do
			beam(g, (look * CFrame.new(across, rise, front)).Position, (look * CFrame.new(0, rise, 0.4)).Position, 0.1, color)
		end
	end
end

-- An air conditioner hung on a wall. cframe sits on the wall and faces out.
local function airCon(g, cframe: CFrame, solid: boolean?)
	local body = block(g, "ac", Vector3.new(2.6, 1.7, 1.1), cframe * CFrame.new(0, 0, -0.55))
	if not solid then
		Kit.decor(body)
	end
	Kit.decor(g:block(Vector3.new(2.3, 1.4, 0.1), cframe * CFrame.new(0, 0, -1.2), rgb(150, 156, 154), M.Metal))
	Kit.decor(g:cylinder(cframe * CFrame.new(0.45, 0, -1.3) * CFrame.Angles(0, math.pi / 2, 0), 0.1, 1.25, rgb(60, 66, 66), M.Metal))
	Kit.decor(g:block(Vector3.new(2.5, 0.16, 1.0), cframe * CFrame.new(0, 0.93, -0.55), g:vary(SNOW, 0.02), M.Snow))
	-- The drip pipe and its stain.
	beam(g, (cframe * CFrame.new(-1.1, -0.85, -0.3)).Position, (cframe * CFrame.new(-1.1, -2.6, -0.1)).Position, 0.08, rgb(180, 186, 180))
end

-- A satellite dish facing direction, with its feed arm. Looks only.
local function dish(g, center: Vector3, direction: Vector3, diameter: number)
	local look = face(center, direction)
	local bowl = Kit.decor(g:block(Vector3.new(diameter * 0.28, diameter, diameter), look * CFrame.Angles(0, math.pi / 2, 0), g:vary(DISH, 0.02), M.SmoothPlastic))
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = bowl
	local feed = (look * CFrame.new(0, 0, -diameter * 0.55)).Position
	for _, corner in { v(0, 0.4, 0), v(0, -0.4, 0) } do
		beam(g, (look * CFrame.new(corner * diameter)).Position, feed, 0.07, TRIM)
	end
	Kit.decor(g:ball(feed, diameter * 0.09, rgb(180, 186, 184), M.SmoothPlastic))
	beam(g, center, (look * CFrame.new(0, 0, diameter * 0.25)).Position, 0.3, TRIM)
	-- Snow caught in the top of the bowl.
	Kit.decor(g:block(Vector3.new(diameter * 0.5, 0.12, diameter * 0.16), look * CFrame.new(0, diameter * 0.43, -diameter * 0.04), g:vary(SNOW, 0.02), M.Snow))
end

-- A tapering lattice mast with a red beacon on top. Looks only.
local function mast(g, base: Vector3, height: number, width: number)
	local color = g:vary(rgb(176, 184, 184), 0.03)
	local half = width / 2
	local corners = { v(-half, 0, -half), v(half, 0, -half), v(half, 0, half), v(-half, 0, half) }
	local taper = 0.65
	local function corner(index: number, share: number): Vector3
		return base + corners[index] * (1 - taper * share) + v(0, height * share, 0)
	end
	for index = 1, 4 do
		beam(g, corner(index, 0), corner(index, 1), 0.22, color)
	end
	local rungs = math.max(2, math.floor(height / 3))
	for rung = 0, rungs - 1 do
		local s0, s1 = rung / rungs, (rung + 1) / rungs
		for index = 1, 4 do
			local next = index % 4 + 1
			beam(g, corner(index, s0), corner(next, s0), 0.09, color)
			beam(g, corner(index, s0), corner(next, s1), 0.07, color)
		end
	end
	local top = base + v(0, height, 0)
	beam(g, top, top + v(0, 6, 0), 0.12, color)
	local beacon = g:neon(Vector3.new(0.45, 0.45, 0.45), CFrame.new(top + v(0, 6.2, 0)), Palette.HazardRed)
	g:light(beacon, "PointLight", { Color = Palette.HazardRed, Range = 7, Brightness = 1.2 })
	-- Small dishes and panels clamped to the mast.
	dish(g, base + v(half * 0.9, height * 0.55, 0), v(1, 0.1, 0.3), 1.8)
	dish(g, base + v(-half * 0.8, height * 0.75, half * 0.5), v(-0.6, 0.2, 1), 1.4)
	Kit.decor(g:block(Vector3.new(0.3, 2.4, 0.9), CFrame.new(base + v(0, height * 0.35, half * 0.95)), DISH, M.SmoothPlastic))
end

local function crate(g, low: Vector3, high: Vector3): BasePart
	local part = box(g, "crate", low, high)
	g:dirty(part, "block", 0.6)
	local strap = rgb(60, 64, 66)
	local middle = (low.X + high.X) / 2
	Kit.decor(g:box(v(middle - 0.12, low.Y + 0.05, low.Z - 0.12), v(middle + 0.12, high.Y + 0.12, high.Z + 0.12), strap, M.Fabric))
	return part
end

-- A potted plant. tall makes a small tree.
local function plant(g, base: Vector3, size: number, tall: boolean?)
	Kit.decor(g:post(base, size * 0.7, size * 0.9, g:vary(POT, 0.05), M.Slate))
	local soil = base + v(0, size * 0.7, 0)
	if tall then
		beam(g, soil, soil + v(g:range(-0.3, 0.3), size * 2.6, g:range(-0.3, 0.3)), 0.14, rgb(84, 66, 50), M.Wood)
		for _ = 1, 5 do
			local leaf = Kit.decor(g:ball(soil + v(g:range(-0.9, 0.9), size * g:range(1.9, 3), g:range(-0.9, 0.9)), size * g:range(0.9, 1.4), g:vary(LEAF, 0.06), M.Grass))
			leaf.Transparency = 0.1
		end
	else
		for _ = 1, 3 do
			Kit.decor(g:ball(soil + v(g:range(-0.25, 0.25), size * g:range(0.2, 0.45), g:range(-0.25, 0.25)), size * g:range(0.6, 0.95), g:vary(LEAF_DARK, 0.06), M.Grass))
		end
	end
end

-- A washing line from a to b with clothes pegged along it.
local function laundry(g, a: Vector3, b: Vector3, sag: number)
	g:cable(a, b, sag, 0.05, rgb(200, 200, 196))
	local along = b - a
	local count = math.floor(along.Magnitude / 1.3)
	local flat = Vector3.new(along.X, 0, along.Z).Unit
	for index = 1, count - 1 do
		if g:chance(0.75) then
			local share = index / count
			local hang = a:Lerp(b, share) - v(0, sag * 4 * share * (1 - share), 0)
			local width, height = g:range(0.7, 1.2), g:range(0.9, 1.9)
			local centre = hang - v(0, height / 2, 0)
			local cloth = g:block(Vector3.new(width, height, 0.05), CFrame.lookAt(centre, centre + flat:Cross(Vector3.yAxis)), CLOTHES[g.random:NextInteger(1, #CLOTHES)], M.Fabric)
			Kit.decor(cloth)
		end
	end
end

-- A strip light under a ceiling.
local function tube(g, position: Vector3, length: number, along: string, color: Color3, shadows: boolean?)
	local size = if along == "x" then Vector3.new(length, 0.2, 0.5) else Vector3.new(0.5, 0.2, length)
	local part = g:neon(size, CFrame.new(position), color)
	g:light(part, "SurfaceLight", { Face = Enum.NormalId.Bottom, Color = color, Brightness = 1.3, Range = 16, Angle = 110, Shadows = shadows == true })
end

-- A console you use to travel. Returns its prompt.
local function terminal(g, base: Vector3, facing: Vector3, text: string): ProximityPrompt
	local look = face(base + v(0, 2, 0), facing)
	local console = g:block(Vector3.new(2.4, 4, 2), look * CFrame.new(0, 0, 0.3), Palette.DeepNavy, M.Metal)
	g:sign(look * CFrame.new(0, 1, -0.75), 1.8, 0.9, {
		text = text,
		color = Palette.Bone,
		fill = Palette.DeepNavy,
		back = Palette.DeepNavy,
		light = Palette.Bone,
	})
	g:neon(Vector3.new(1.9, 0.08, 0.1), look * CFrame.new(0, 0.3, -0.82), Palette.DataCyan)
	return g:prompt(console, text, "Travel", 0.4)
end

-- One wall panel of the round wing, at angle (degrees, from +X toward +Z).
local function drumPoint(angle: number, radius: number, y: number): Vector3
	local radians = math.rad(angle)
	return DRUM + v(math.cos(radians) * radius, y, math.sin(radians) * radius)
end

-- The round wing on the tower's +Z side: two rooms and a terrace on top. Panels inside the main
-- block are left out. openingsAt maps an angle to { bottom, top, kind } openings.
local function drum(g)
	local width = 2 * (DRUM_RADIUS - T) * math.tan(math.pi / DRUM_SIDES)
	local openingsAt: { [number]: { { any } } } = {
		[0] = { { 3.6, 7.2, "pane" }, { 15.4, 19.6, "pane" } },
		[30] = { { 3.6, 7.2, "pane" }, { 15.4, 19.6, "pane" } },
		[60] = { { 3.6, 7.2, "pane" }, { 15.4, 19.6, "pane" } },
		[90] = { { 3.6, 7.2, "pane" }, { 15.4, 19.6, "pane" } },
		[120] = { { 15.4, 19.6, "pane" } },
		[150] = { { 3.6, 7.2, "pane" }, { 15.4, 19.6, "pane" } },
	}
	for angle = 0, 180, 30 do
		local centre = drumPoint(angle, DRUM_RADIUS - T / 2, 0)
		local spin = CFrame.new(centre) * CFrame.Angles(0, -math.rad(angle), 0)
		local holes = {}
		for _, hole in openingsAt[angle] or {} do
			table.insert(holes, { -width, width, hole[1], hole[2] })
		end
		local top = L3 + 0.8
		grid(-width / 2, width / 2, DRUM_BOTTOM, top, holes, function(a, b, c, d)
			local part = block(g, "hull", Vector3.new(T, d - c, b - a), spin * CFrame.new(0, (c + d) / 2, (a + b) / 2))
			g:dirty(part, "wall")
		end)
		for _, hole in openingsAt[angle] or {} do
			local y0, y1, kind = hole[1], hole[2], hole[3]
			local color = g:vary(TRIM, 0.04)
			Kit.decor(g:block(Vector3.new(0.5, 0.3, width), spin * CFrame.new(T / 2 + 0.25, y1 + 0.15, 0), color, M.Metal))
			if kind == "pane" then
				Kit.decor(g:block(Vector3.new(0.6, 0.25, width), spin * CFrame.new(T / 2 + 0.3, y0 - 0.12, 0), color, M.Metal))
				Kit.decor(g:block(Vector3.new(0.5, 0.15, width * 0.9), spin * CFrame.new(T / 2 + 0.3, y0 + 0.07, 0), g:vary(SNOW, 0.02), M.Snow))
				ghost(g:block(Vector3.new(0.2, y1 - y0, width), spin * CFrame.new(0, (y0 + y1) / 2, 0), GLASS, M.Glass), false)
			end
		end
		-- A ring of trim at each floor, like the bands on the main block.
		for _, y in { L2, L3 } do
			Kit.decor(g:block(Vector3.new(0.6, 0.5, width), spin * CFrame.new(T / 2 + 0.3, y - 0.25, 0), g:vary(TRIM, 0.03), M.Metal))
		end
	end
	-- A post at each seam between panels.
	local seam = (DRUM_RADIUS - T / 2) / math.cos(math.pi / DRUM_SIDES)
	for angle = -15, 195, 30 do
		local foot = drumPoint(angle, seam, DRUM_BOTTOM - 0.15)
		local color, material = paint(g, "hull")
		g:post(foot, L3 + 0.8 - DRUM_BOTTOM + 0.35, 1.6, color, material)
	end
	-- Fillers between the outermost panels and the main block's north wall.
	for _, angle in { -15, 195 } do
		local corner = drumPoint(angle, DRUM_RADIUS - T / 2, 0)
		local part = box(g, "hull", v(corner.X - T / 2, DRUM_BOTTOM, HALF), v(corner.X + T / 2, L3 + 0.8, corner.Z + 0.2))
		g:dirty(part, "wall")
	end
	-- Floors. Their tops sit well under the main block's where the two overlap, so they never flicker.
	local function disc(y: number, diameter: number, look: string)
		local color, material = paint(g, look)
		g:cylinder(CFrame.new(DRUM + v(0, y - 0.5, 0)) * CFrame.Angles(0, 0, math.pi / 2), 0.96, diameter, color, material)
	end
	disc(L1 - 0.12, DRUM_RADIUS * 2 - 0.2, "floor")
	disc(L2 - 0.12, DRUM_RADIUS * 2 - 0.2, "floor")
	disc(L3 - 0.12, DRUM_RADIUS * 2 + 1, "roof")
	disc(DRUM_BOTTOM, DRUM_RADIUS * 2 + 0.6, "hullDark")
	-- The wing narrows into a pod underneath.
	local color, material = paint(g, "hullDark")
	g:cylinder(CFrame.new(DRUM + v(0, DRUM_BOTTOM - 4, 0)) * CFrame.Angles(0, 0, math.pi / 2), 8, DRUM_RADIUS * 1.3, color, material)
	g:cylinder(CFrame.new(DRUM + v(0, DRUM_BOTTOM - 9, 0)) * CFrame.Angles(0, 0, math.pi / 2), 2, DRUM_RADIUS * 0.8, color, material)

	-- Terrace railing, round the outside of the wing.
	for angle = -30, 180, 30 do
		rail(g, drumPoint(angle, DRUM_RADIUS - 0.4, L3), drumPoint(angle + 30, DRUM_RADIUS - 0.4, L3), TRIM)
	end
	snowOn(g, drumPoint(60, 4, L3) - v(3, 0, 2), drumPoint(60, 4, L3) + v(3, 0.2, 2))
	dish(g, drumPoint(40, 5, L3 + 2.6), v(0.8, 0.25, 0.6), 4.5)
	Kit.decor(g:post(drumPoint(40, 5, L3), 2.4, 0.4, TRIM, M.Metal))
	box(g, "machine", drumPoint(100, 4.5, L3) - v(1.2, 0, 1), drumPoint(100, 4.5, L3) + v(1.2, 2.6, 1))
	airCon(g, CFrame.lookAt(drumPoint(130, 3.5, L3 + 0.85), drumPoint(130, 8, L3 + 0.85)), true)

	tube(g, DRUM + v(0, L2 - 1.2, 3), 4, "x", FLUORESCENT)
	tube(g, DRUM + v(0, L3 - 1.2, 3), 4, "x", FLUORESCENT)
	-- Air conditioners and pipes on the outside.
	for _, spot in { { 75, 10 }, { 135, 9.5 }, { 15, 21.5 }, { 105, 21.5 } } do
		local at = drumPoint(spot[1], DRUM_RADIUS, spot[2])
		airCon(g, face(at, at - DRUM - v(0, at.Y, 0)))
	end
	local pipe = rgb(120, 130, 128)
	Kit.decor(g:post(drumPoint(170, DRUM_RADIUS + 0.4, DRUM_BOTTOM - 6), L3 - DRUM_BOTTOM + 6, 0.45, pipe, M.Metal))
	Kit.decor(g:post(drumPoint(45, DRUM_RADIUS + 0.4, DRUM_BOTTOM - 14), L3 - DRUM_BOTTOM + 13, 0.3, pipe, M.Metal))
end

-- The main block: three floors, the roof and the closed lower floors.
local function tower(g)
	-- Floors. Slabs end at the walls' inside faces, so no floor top shares a plane with a wall's.
	local x0, x1, z0, z1 = BACK + T, FACADE - T, -HALF + T, HALF - T
	slab(g, "floor", x0, x1, z0, z1, L1 - 1, L1, nil, "floor")
	slab(g, "floor", x0, x1, z0, z1, L2 - 1, L2, { SHAFT_HOLE }, "shell")
	slab(g, "floor", x0, x1, z0, z1, L3 - 1, L3, { SHAFT_HOLE }, "shell")
	slab(g, "roof", BACK - 0.5, FACADE + 0.5, -HALF - 0.5, HALF + 0.5, ROOF - 1, ROOF, { STAIR_3 }, "floor")
	slab(g, "hullDark", x0, x1, z0, z1, HULL_BOTTOM - 1, HULL_BOTTOM)

	-- Walls, from the bottom of the closed floors to the underside of the roof.
	local facade = {
		{ -4, 4, L1, 9, "door" },
		{ -11, -6, 15.4, 20.5, "pane" },
		{ -2.5, 2.5, 15.4, 20.5, "open" },
		{ 6, 11, 15.4, 20.5, "pane" },
		{ -12, -2, 27.4, 31.6, "open" }, -- the top floor's long window, split by a door to the balcony
		{ -2, 2, L3, 31.6, "door" },
		{ 2, 12, 27.4, 31.6, "open" },
	}
	local back = {
		{ -11, -5, 3.6, 7.4, "pane" },
		{ 2, 8, 3.6, 7.4, "pane" },
		{ -12, 12, 27.4, 31.6, "pane" },
	}
	local south = {
		{ -52, -48, 4, 7.5, "pane" },
		{ -66, -60, 15.4, 19.6, "pane" },
		{ -54, -48, 15.4, 19.6, "pane" },
		{ -70, -64, 27.4, 31.6, "pane" },
		{ -58, -52, 27.4, 31.6, "pane" },
	}
	local north = {
		{ -56, -50, L1, 8, "door" },
		{ -52, -47, L2, L2 + 8, "door" },
		{ -58, -53, L3, L3 + 8, "door" },
		{ -72, -66, 4, 7.5, "pane" },
		{ -72, -66, 15.4, 19.6, "pane" },
		{ -72, -66, 27.4, 31.6, "pane" },
	}
	local top = ROOF - 1
	wall(g, "hull", "x", FACADE - T / 2, T, -HALF, HALF, HULL_BOTTOM - 1, top, facade)
	wall(g, "hull", "x", BACK + T / 2, T, -HALF, HALF, HULL_BOTTOM - 1, top, back)
	wall(g, "hull", "z", -HALF + T / 2, T, BACK + T, FACADE - T, HULL_BOTTOM - 1, top, south)
	wall(g, "hull", "z", HALF - T / 2, T, BACK + T, FACADE - T, HULL_BOTTOM - 1, top, north)
	-- The balcony door's head is drawn between the long window's two heads, which it would overlap.
	local framed = {}
	for _, hole in facade do
		if hole[3] ~= L3 then
			table.insert(framed, hole)
		end
	end
	openings(g, "x", FACADE - T / 2, 1, framed)
	Kit.decor(g:box(v(FACADE, 31.6, -1.7), v(FACADE + 0.3, 31.9, 1.7), g:vary(TRIM, 0.04), M.Metal))
	openings(g, "x", BACK + T / 2, -1, back)
	openings(g, "z", -HALF + T / 2, -1, south)
	openings(g, "z", HALF - T / 2, 1, north)
	-- Mullions in the top floor's long window, too thin to stop anyone.
	for z = -8, 8, 4 do
		if z ~= 0 then -- the facade's balcony door is there
			beam(g, v(FACADE - 0.3, 27.4, z), v(FACADE - 0.3, 31.6, z), 0.25, TRIM)
		end
		beam(g, v(BACK + 0.3, 27.4, z), v(BACK + 0.3, 31.6, z), 0.25, TRIM)
	end
	-- Inside faces get a lighter plaster lining on the lobby and top floors.
	Kit.decor(box(g, "inside", v(BACK + T, L1, -HALF + T), v(BACK + T + 0.2, L2 - 1, HALF - T)))

	-- Bands at each floor, and the corner seams, standing proud of the walls.
	for _, y in { L1, L2, L3 } do
		local band = g:vary(TRIM, 0.03)
		local fronts = if y == L1 then { { -HALF - 0.3, -BRIDGE_HALF } } elseif y == L2 then { { -HALF - 0.3, -5.4 }, { 5.4, HALF + 0.3 } } else {}
		for _, front in fronts do
			Kit.decor(g:box(v(FACADE, y - 0.7, front[1]), v(FACADE + 0.4, y, front[2]), band, M.Metal))
			snowOn(g, v(FACADE, y, math.max(front[1], -HALF)), v(FACADE + 0.38, y + 0.14, math.min(front[2], HALF)))
		end
		Kit.decor(g:box(v(BACK - 0.4, y - 0.7, -HALF - 0.3), v(BACK, y, HALF + 0.3), band, M.Metal))
		Kit.decor(g:box(v(BACK, y - 0.7, -HALF - 0.4), v(FACADE, y, -HALF), band, M.Metal))
		Kit.decor(g:box(v(BACK, y - 0.7, HALF), v(FACADE, y, HALF + 0.4), band, M.Metal))
		snowOn(g, v(BACK - 0.38, y, -HALF), v(BACK, y + 0.14, HALF))
	end

	-- The roof: a low lip, a railing, and drifts of snow along the edges.
	local lip = g:vary(TRIM, 0.03)
	local lips = {
		{ v(BACK - 0.5, ROOF, -HALF - 0.5), v(FACADE + 0.5, ROOF + 0.8, -HALF) },
		{ v(BACK - 0.5, ROOF, HALF), v(FACADE + 0.5, ROOF + 0.8, HALF + 0.5) },
		{ v(BACK - 0.5, ROOF, -HALF), v(BACK, ROOF + 0.8, HALF) },
		{ v(FACADE, ROOF, -HALF), v(FACADE + 0.5, ROOF + 0.8, HALF) },
	}
	for _, ends in lips do
		box(g, "roof", ends[1], ends[2])
		snowOn(g, ends[1] + v(0, 0.8, 0), ends[2] + v(0, 0.16, 0))
	end
	local inset = 0.2
	rail(g, v(BACK + inset, ROOF, -HALF + inset), v(FACADE - inset, ROOF, -HALF + inset), lip)
	rail(g, v(FACADE - inset, ROOF, -HALF + inset), v(FACADE - inset, ROOF, HALF - inset), lip)
	rail(g, v(FACADE - inset, ROOF, HALF - inset), v(BACK + inset, ROOF, HALF - inset), lip)
	rail(g, v(BACK + inset, ROOF, HALF - inset), v(BACK + inset, ROOF, -HALF + inset), lip)
	snowOn(g, v(FACADE - 3, ROOF, -HALF), v(FACADE, ROOF + 0.25, HALF))
	snowOn(g, v(BACK, ROOF, -6), v(BACK + 2.5, ROOF + 0.25, HALF))
	snowOn(g, v(-64, ROOF, HALF - 2.2), v(-44, ROOF + 0.22, HALF))

	-- A walkable balcony under the roof's edge, the facade's full width, over the bridge. A door
	-- in the middle of the long window leads out to it.
	local reach = FACADE + BALCONY_DEPTH
	box(g, "deck", v(FACADE, L3 - 0.4, -HALF), v(reach, L3, HALF))
	rail(g, v(reach - 0.2, L3, -HALF + 0.2), v(reach - 0.2, L3, HALF - 0.2), TRIM)
	rail(g, v(FACADE, L3, -HALF + 0.2), v(reach - 0.2, L3, -HALF + 0.2), TRIM)
	rail(g, v(FACADE, L3, HALF - 0.2), v(reach - 0.2, L3, HALF - 0.2), TRIM)
	for z = -12, 12, 6 do
		beam(g, v(FACADE, L3 - 3.5, z), v(reach - 0.4, L3 - 0.4, z), 0.25, TRIM)
	end
	snowOn(g, v(reach - 1, L3, -HALF + 0.5), v(reach - 0.45, L3 + 0.14, HALF - 0.5))

	-- The lobby's lit entrance from the bridge.
	g:sign(face(v(FACADE + 0.35, 10.5, 0), Vector3.xAxis), 9, 1.9, {
		text = "RELAY",
		color = Palette.Bone,
		fill = Palette.DeepNavy,
		back = Palette.DeepNavy,
		light = AMBER,
		style = "Title",
	})
	for _, z in { -4.8, 4.8 } do
		g:neon(Vector3.new(0.2, 2.2, 0.25), CFrame.new(FACADE + 0.4, 10.5, z), AMBER)
	end
	g:neon(Vector3.new(0.2, 0.18, 9.3), CFrame.new(FACADE + 0.4, 11.6, 0), AMBER)
	g:neon(Vector3.new(0.2, 0.18, 9.3), CFrame.new(FACADE + 0.4, 9.4, 0), AMBER)
	local porch = g:neon(Vector3.new(1.2, 0.2, 7), CFrame.new(FACADE - 1.5, 8.8, 0), AMBER)
	g:light(porch, "SurfaceLight", { Face = Enum.NormalId.Bottom, Color = AMBER, Brightness = 2.2, Range = 18, Angle = 120, Shadows = true })
	Kit.decor(g:box(v(FACADE + 0.35, 8.55, -5), v(FACADE + 2.2, 8.95, 5), g:vary(TRIM, 0.03), M.Metal)) -- awning
	snowOn(g, v(FACADE + 0.35, 8.95, -5), v(FACADE + 2.2, 9.15, 5))
	for _, x in { -68, -48 } do -- clear of the ladder's hole overhead
		tube(g, v(x, L2 - 1.15, 0), 5, "z", FLUORESCENT, x == -48)
	end

	-- One ladder up the middle, from the lobby through operations to the top floor, its rungs
	-- toward the bridge. It runs 4 past the top floor so you can climb over. Only the top floor
	-- has stairs, up to the roof's stair house.
	ladder(g, v(SHAFT.X, L1, SHAFT.Z), Vector3.xAxis, L3 - L1 + 4)
	flight(g, "stairs", "x", -46, L3, -66, ROOF, STAIR_3[3], STAIR_3[4], { STAIR_3[4] - 0.3 }, IRON, L3)

	-- Lights in operations and the top floor. The rooms are left empty.
	for _, x in { -64, -50 } do
		tube(g, v(x, L3 - 1.15, -2), 6, "z", FLUORESCENT, x == -50)
	end

	tube(g, v(-58, ROOF - 1.15, 2), 6, "z", FLUORESCENT, true)
	tube(g, v(-48, ROOF - 1.15, -2), 6, "z", WARM)

	-- The stair house on the roof.
	local cabinDoor = { { -71, -66.5, ROOF, ROOF + 7, "door" } }
	wall(g, "hull", "z", -6.5, T, -72, -44, ROOF, CABIN_TOP, cabinDoor)
	openings(g, "z", -6.5, 1, cabinDoor)
	wall(g, "hull", "z", -13.5, T, -72, -44, ROOF, CABIN_TOP)
	wall(g, "hull", "x", -71.5, T, -13, -7, ROOF, CABIN_TOP)
	wall(g, "hull", "x", -44.5, T, -13, -7, ROOF, CABIN_TOP, { { -12, -8, ROOF + 3.6, ROOF + 6.4, "pane" } })
	openings(g, "x", -44.5, 1, { { -12, -8, ROOF + 3.6, ROOF + 6.4, "pane" } })
	box(g, "roof", v(-72.5, CABIN_TOP, -14.2), v(-43.5, CABIN_TOP + 0.6, -5.8))
	snowOn(g, v(-72.3, CABIN_TOP + 0.6, -14), v(-43.7, CABIN_TOP + 0.85, -6))
	g:lamp(v(-68.5, ROOF + 7.6, -5.6), AMBER, 14, 1.2, true)
	tube(g, v(-58, CABIN_TOP - 0.15, -10), 5, "x", FLUORESCENT)

	-- The mast and dish stand on the stair house. The roof itself is left clear.
	mast(g, v(-51, CABIN_TOP + 0.6, -10), 22, 2.6)
	dish(g, v(-62, CABIN_TOP + 3.6, -10), v(1, 0.55, 0.15), 5.5)
	Kit.decor(g:post(v(-62, CABIN_TOP + 0.6, -10), 3, 0.5, TRIM, M.Metal))

	-- The outside: air conditioners, pipes, cables, and lit windows on the closed floors.
	for _, spot in { { -9, 22 }, { 8.5, 22 }, { -7, 9.6 }, { 9, 9.6 } } do
		airCon(g, face(v(FACADE, spot[2], spot[1]), Vector3.xAxis))
	end
	for _, spot in { { -68, 10 }, { -66, 22 }, { -61, 31.4 }, { -74, 21 } } do
		airCon(g, face(v(spot[1], spot[2], -HALF), -Vector3.zAxis))
	end
	for _, spot in { { -8, 9.8 }, { 6, 20.6 } } do
		airCon(g, face(v(BACK, spot[2], spot[1]), -Vector3.xAxis))
	end
	for _, z in { -13.2, 12.6 } do
		Kit.decor(g:post(v(FACADE + 0.45, HULL_BOTTOM - 6, z), ROOF - HULL_BOTTOM + 6, 0.4, rgb(120, 132, 130), M.Metal))
	end
	Kit.decor(g:post(v(BACK - 0.45, HULL_BOTTOM - 10, 11), ROOF - HULL_BOTTOM + 10, 0.5, rgb(112, 124, 122), M.Metal))
	for index, z in { -12, -8, -4, 4, 8, 12 } do
		local lit = index % 3 ~= 0
		fakeWindow(g, "x", FACADE - T / 2, 1, z - 1.2, z + 1.2, -8, -4.5, lit)
		fakeWindow(g, "x", BACK + T / 2, -1, z - 1.2, z + 1.2, -8, -4.5, not lit)
	end
	for index, x in { -72, -66, -60, -54, -48 } do
		fakeWindow(g, "z", -HALF + T / 2, -1, x - 1.2, x + 1.2, -8, -4.5, index % 2 == 0)
	end
	g:cable(v(FACADE + 0.5, 21, 13), v(FACADE + 0.5, 9.5, 6), 0.8, 0.14)
	g:cable(v(FACADE + 0.5, 33, -13.5), v(FACADE + 0.5, 21, -11.5), 1.2, 0.12)
	g:cable(v(BACK - 0.5, 30, -13.5), v(BACK - 0.5, 4, -10), 1.5, 0.16)
	-- Red and white marker on the facade, under the sign.
	Kit.decor(g:box(v(FACADE, -3.2, 5.5), v(FACADE + 0.12, -0.6, 12.5), ORANGE, M.SmoothPlastic))
	Kit.decor(g:box(v(FACADE, -3.2, 12.5), v(FACADE + 0.12, -0.6, 13.6), rgb(226, 226, 220), M.SmoothPlastic))

	-- The stem it all stands on, going down into the fog, with its banner.
	box(g, "hullDark", v(-74, HULL_BOTTOM - 8, -12), v(-44, HULL_BOTTOM - 1, 12))
	local stem = box(g, "hullDark", v(-70, -260, -10), v(-48, HULL_BOTTOM - 8, 10))
	g:dirty(stem, "block")
	Kit.decor(g:box(v(-48, -42, -7.2), v(-47.7, -34, 7.2), ORANGE, M.SmoothPlastic))
	g:sign(face(v(-47.55, -38, 0), Vector3.xAxis), 12, 5, {
		text = "RELAY 04",
		color = Palette.Bone,
		fill = Palette.DeepNavy,
		back = Palette.DeepNavy,
		style = "Title",
	})
	for y = -30, HULL_BOTTOM - 10, 1.2 do
		beam(g, v(-47.6, y, -9), v(-47.6, y, -8), 0.12, TRIM)
	end
	beam(g, v(-47.6, -60, -9.1), v(-47.6, HULL_BOTTOM - 9, -9.1), 0.12, TRIM)
	beam(g, v(-47.6, -60, -7.9), v(-47.6, HULL_BOTTOM - 9, -7.9), 0.12, TRIM)
	for index, y in { -26, -50, -78 } do
		g:lamp(v(-47.3, y, if index == 2 then 9 else -9.5), AMBER, 14, 1.4, false, 0.5)
	end
	for _, y in { -56, -70 } do
		fakeWindow(g, "x", -48.5, 1, -6, -2, y, y + 3, true)
		fakeWindow(g, "x", -48.5, 1, 2, 6, y, y + 3, false)
	end
end

-- The bridge from this side's tower to the middle, and half of the signal hut.
local function bridge(g)
	local deck = box(g, "deck", v(FACADE, -1, -BRIDGE_HALF), v(0, 0, BRIDGE_HALF))
	g:dirty(deck, "wet")
	local girder = box(g, "girder", v(FACADE, GIRDER_BOTTOM, -BRIDGE_HALF + 1), v(0, -1, BRIDGE_HALF - 1))
	g:dirty(girder, "wall")
	-- Rust-red marks and a panel on the girder's sides.
	for _, z in { -BRIDGE_HALF + 0.95, BRIDGE_HALF - 0.95 } do
		local out = if z > 0 then 1 else -1
		for _, x in { -31, -15 } do
			Kit.decor(g:cylinder(CFrame.new(x, -3.4, z + out * 0.06) * CFrame.Angles(0, math.pi / 2, 0), 0.1, 2.3, RUST, M.SmoothPlastic))
		end
		Kit.decor(g:box(v(-25, -5.4, z), v(-21, -1.6, z + out * 0.1), ORANGE, M.SmoothPlastic))
		Kit.decor(g:box(v(-24.6, -3.9, z), v(-21.4, -3.1, z + out * 0.25), rgb(226, 226, 220), M.SmoothPlastic))
	end
	-- Rails set into the deck, and a kerb along each edge.
	for _, z in { -2.2, 2.2 } do
		Kit.decor(g:box(v(FACADE, 0, z - 0.15), v(0, 0.12, z + 0.15), rgb(70, 74, 74), M.Metal))
	end
	for _, z in { -BRIDGE_HALF, BRIDGE_HALF - 0.6 } do
		Kit.decor(g:box(v(FACADE, 0, z), v(0, 0.4, z + 0.6), g:vary(TRIM, 0.03), M.Metal))
		snowOn(g, v(FACADE, 0.4, z), v(0, 0.55, z + 0.6))
	end
	-- Railings. The +Z side leaves a gap by the tower where the stairs come up from the flats.
	rail(g, v(STAIR_TOP, 0, BRIDGE_HALF - 0.2), v(0, 0, BRIDGE_HALF - 0.2), TRIM)
	rail(g, v(FACADE, 0, -BRIDGE_HALF + 0.2), v(0, 0, -BRIDGE_HALF + 0.2), TRIM)

	-- The only cover on this half of the lane: a crate stack and a cable spool.
	crate(g, v(-27, 0, -6.4), v(-23, 3.5, -3))
	crate(g, v(-26.5, 3.5, -6), v(-24, 6, -3.5))
	local spoolColor, spoolMaterial = paint(g, "crate")
	g:cylinder(CFrame.new(-16, 2, 2.5) * CFrame.Angles(0, math.pi / 2, 0), 2.6, 4, spoolColor, spoolMaterial)
	Kit.decor(g:cylinder(CFrame.new(-16, 2, 2.5) * CFrame.Angles(0, math.pi / 2, 0), 2.7, 2.2, rgb(40, 44, 46), M.Metal))

	-- A brace from the tower's stem up under the girder.
	local foot, head = v(-48, -46, 0), v(-22, GIRDER_BOTTOM + 0.5, 0)
	local brace = block(g, "girder", Vector3.new(7, 3, (head - foot).Magnitude), CFrame.lookAt((foot + head) / 2, head))
	g:dirty(brace, "block")
	for _, z in { -3.6, 3.6 } do
		beam(g, foot + v(0, 2, z), head + v(-6, -2.5, z), 0.4, TRIM)
	end

	-- Hangers from the bridge's edge down to the flats' roof, and lamps under the girder.
	for _, x in { -9.5, -1 } do
		beam(g, v(x, -1, BRIDGE_HALF - 1), v(x, -6, FLATS_HALF - 0.5), 0.18, IRON)
		beam(g, v(x, -1, -BRIDGE_HALF + 1), v(x, -6, -FLATS_HALF + 0.5), 0.18, IRON)
	end
	for _, x in { -30, -16 } do
		local lamp = g:neon(Vector3.new(0.8, 0.25, 0.5), CFrame.new(x, GIRDER_BOTTOM - 0.2, BRIDGE_HALF - 1.6), WARM)
		g:light(lamp, "SpotLight", { Face = Enum.NormalId.Bottom, Color = WARM, Range = 20, Brightness = 1.6, Angle = 120 })
	end
	-- Snow drifts against the kerbs.
	for _, x in { -36, -20, -13 } do
		snowOn(g, v(x, 0, -BRIDGE_HALF + 0.6), v(x + g:range(2, 5), 0.18, -BRIDGE_HALF + 1.4))
		snowOn(g, v(x + 3, 0, BRIDGE_HALF - 1.4), v(x + 3 + g:range(2, 5), 0.18, BRIDGE_HALF - 0.6))
	end
end

-- Under the bridge: fire stairs down the round wing, a catwalk, stairs back up to the bridge, and
-- this side's half of the hanging block of flats.
local function under(g)
	-- One wide straight flight from the bridge's edge by the tower down to a platform at the
	-- flats' door.
	local near, far = STAIR_SIDE[1], STAIR_SIDE[2]
	flight(g, "grating", "x", STAIR_FOOT, UNDER, STAIR_TOP, 0, near, far, { near, far })
	box(g, "grating", v(FACADE, -0.4, BRIDGE_HALF), v(STAIR_TOP, 0, far))
	rail(g, v(FACADE, 0, far), v(STAIR_TOP, 0, far), DARK_STEEL)
	box(g, "grating", v(STAIR_FOOT, UNDER - 0.4, near), v(FLATS_END, UNDER, FLATS_HALF))
	rail(g, v(STAIR_FOOT, UNDER, far), v(STAIR_FOOT, UNDER, FLATS_HALF - 0.2), DARK_STEEL)
	rail(g, v(STAIR_FOOT, UNDER, FLATS_HALF - 0.2), v(FLATS_END, UNDER, FLATS_HALF - 0.2), DARK_STEEL)
	rail(g, v(STAIR_FOOT, UNDER, near), v(FLATS_END, UNDER, near), DARK_STEEL)
	-- A truss under the platform, like a fire escape's.
	for _, z in { 8.2, 14, FLATS_HALF - 0.2 } do
		beam(g, v(STAIR_FOOT, UNDER - 0.6, z), v(FLATS_END, UNDER - 0.6, z), 0.25, DARK_STEEL)
	end
	beam(g, v(STAIR_FOOT, UNDER - 0.6, 8.2), v(FLATS_END, UNDER - 2.6, 14), 0.18, DARK_STEEL)
	beam(g, v(FLATS_END, UNDER - 0.6, 14), v(STAIR_FOOT, UNDER - 2.6, FLATS_HALF - 0.2), 0.18, DARK_STEEL)
	beam(g, v(STAIR_FOOT + 0.2, UNDER - 0.6, 12), v(FLATS_END + 0.2, UNDER - 4, 12), 0.2, DARK_STEEL)
	g:lamp(v(FLATS_END - 0.5, UNDER + 6, 18.5), WARM, 16, 1.2, true, 0.5)

	-- The flats: one floor you can walk through, closed floors hanging below it.
	local x0 = FLATS_END
	local inner = x0 + 0.8
	slab(g, "flatsFloor", inner, 0, -FLATS_HALF + 0.8, FLATS_HALF - 0.8, UNDER - 1, UNDER, nil, "floor")
	slab(g, "flatsInside", inner, 0, -FLATS_HALF + 0.8, FLATS_HALF - 0.8, -7, -6, nil, "shell")
	slab(g, "flats", inner, 0, -FLATS_HALF + 0.8, FLATS_HALF - 0.8, FLATS_BOTTOM - 1, FLATS_BOTTOM)
	local west = {
		{ 13, 17, UNDER, -8.5, "door" },
		{ -15, -11, -12.4, -9, "bars" },
		{ -6, -2, -12.4, -9, "bars" },
		{ 3, 7, -12.4, -9, "bars" },
	}
	local north = {
		{ -8, -4, -12.4, -9, "bars" },
		{ -3, -0.6, -12.4, -9, "bars" },
	}
	local south = {
		{ -8, -4, -12.4, -9, "bars" },
		{ -3, -0.6, -12.4, -9, "bars" },
	}
	wall(g, "flats", "x", x0 + 0.4, 0.8, -FLATS_HALF, FLATS_HALF, FLATS_BOTTOM - 1, -6, west)
	wall(g, "flats", "z", FLATS_HALF - 0.4, 0.8, inner, 0, FLATS_BOTTOM - 1, -6, north)
	wall(g, "flats", "z", -FLATS_HALF + 0.4, 0.8, inner, 0, FLATS_BOTTOM - 1, -6, south)
	openings(g, "x", x0 + 0.4, -1, west)
	openings(g, "z", FLATS_HALF - 0.4, 1, north)
	openings(g, "z", -FLATS_HALF + 0.4, -1, south)
	-- A partition across the middle, so the way through bends.
	wall(g, "flatsInside", "z", 0, 0.6, inner, -3, UNDER, -7, nil, "none")
	-- Inside: just the lights.
	local bulb = g:neon(Vector3.new(0.3, 0.4, 0.3), CFrame.new(-5, -7.6, 12), WARM)
	g:light(bulb, "PointLight", { Color = WARM, Range = 16, Brightness = 1.3, Shadows = true })
	tube(g, v(-5, -7.1, -10), 4, "z", DIM)

	-- The roof of the flats, out past the girder: a tank, clutter, plants, low walls.
	for _, z in { FLATS_HALF, -FLATS_HALF + 0.5 } do
		box(g, "flats", v(x0, -6, z - 0.5), v(0, -5.2, z))
	end
	box(g, "flats", v(x0, -6, BRIDGE_HALF - 1), v(x0 + 0.5, -5.2, FLATS_HALF - 0.5))
	box(g, "flats", v(x0, -6, -FLATS_HALF + 0.5), v(x0 + 0.5, -5.2, -BRIDGE_HALF + 1))
	local tankColor, tankMaterial = paint(g, "flats")
	g:cylinder(CFrame.new(-5, -4, 14) * CFrame.Angles(0, 0, math.pi / 2), 4, 3.4, tankColor, tankMaterial)
	snowOn(g, v(-6.2, -2, 12.8), v(-3.8, -1.85, 15.2))
	airCon(g, face(v(-8, -6 + 0.85, -12), Vector3.zAxis), true)
	plant(g, v(-9, -6, 9), 0.9)
	plant(g, v(-2, -6, 18.6), 1.1, true)
	laundry(g, v(-9.4, -2.8, 8.5), v(-1, -3, 19), 0.5)
	for _, post in { v(-9.4, -6, 8.5), v(-1, -6, 19) } do
		beam(g, post, post + v(0, 3.4, 0), 0.14, IRON)
	end

	-- The closed floors below: lit and dark windows, air conditioners, a lower balcony, pipes.
	for floor = 0, 2 do
		local y = -22 - floor * 6
		for _, z in { -14, -6, 3, 12 } do
			fakeWindow(g, "x", x0 + 0.4, -1, z - 1.4, z + 1.4, y, y + 2.6, g:chance(0.45))
		end
		fakeWindow(g, "z", FLATS_HALF - 0.4, 1, -7.5, -4.5, y, y + 2.6, g:chance(0.4))
		fakeWindow(g, "z", -FLATS_HALF + 0.4, -1, -7.5, -4.5, y, y + 2.6, g:chance(0.4))
		airCon(g, face(v(x0, y - 1.4, -10 + floor * 7), -Vector3.xAxis))
		if floor ~= 1 then -- the lower balcony is in the way on this floor
			airCon(g, face(v(-2.5, y - 1.2, FLATS_HALF), Vector3.zAxis))
		end
	end
	Kit.decor(g:box(v(x0, -29.3, FLATS_HALF), v(-2, -28.9, FLATS_HALF + 3), g:vary(TRIM, 0.03), M.Metal))
	for index = 0, 10 do
		local x = x0 + index * 0.8
		beam(g, v(x, -28.9, FLATS_HALF + 2.9), v(x, -25.9, FLATS_HALF + 2.9), 0.08, IRON)
	end
	beam(g, v(x0, -25.9, FLATS_HALF + 2.9), v(-2, -25.9, FLATS_HALF + 2.9), 0.12, IRON)
	for _, z in { -17, 9.5 } do
		Kit.decor(g:post(v(x0 - 0.4, FLATS_BOTTOM - 8, z), -6 - FLATS_BOTTOM + 8, 0.35, rgb(90, 100, 108), M.Metal))
	end
	g:cable(v(x0 - 0.5, -12, -18), v(x0 - 0.5, -30, -10), 1.5, 0.12)
	g:lamp(v(x0 - 0.6, -24, 0), AMBER, 12, 1, false, 0.45)
end

-- Fog drifting under the bridge, and snow falling on everything.
local function air(g)
	local fog = ghost(g:box(v(-70, -48, -30), v(0, -46, 30), DIM, M.SmoothPlastic), false)
	fog.CanCollide = false
	local wisps = Instance.new("ParticleEmitter")
	wisps.Texture = "rbxasset://textures/particles/smoke_main.dds"
	wisps.Rate = 3
	wisps.Lifetime = NumberRange.new(14, 22)
	wisps.Speed = NumberRange.new(1, 3)
	wisps.SpreadAngle = Vector2.new(30, 30)
	wisps.EmissionDirection = Enum.NormalId.Top
	wisps.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 16), NumberSequenceKeypoint.new(1, 34) })
	wisps.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.3, 0.86),
		NumberSequenceKeypoint.new(0.7, 0.9),
		NumberSequenceKeypoint.new(1, 1),
	})
	wisps.Color = ColorSequence.new(rgb(206, 236, 240))
	wisps.LightEmission = 0.15
	wisps.LightInfluence = 0.6
	wisps.RotSpeed = NumberRange.new(-6, 6)
	wisps.Rotation = NumberRange.new(0, 360)
	wisps.Acceleration = Vector3.new(0.4, 0.3, 0)
	wisps.Parent = fog

	local sky = ghost(g:box(v(-80, 70, -32), v(0, 71, 32), SNOW, M.SmoothPlastic), false)
	sky.CanCollide = false
	local snow = Instance.new("ParticleEmitter")
	snow.Rate = 45
	snow.Lifetime = NumberRange.new(10, 14)
	snow.Speed = NumberRange.new(5, 8)
	snow.SpreadAngle = Vector2.new(12, 12)
	snow.EmissionDirection = Enum.NormalId.Bottom
	snow.Size = NumberSequence.new(0.14)
	snow.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 0.6) })
	snow.Color = ColorSequence.new(SNOW)
	snow.LightEmission = 0.3
	snow.Acceleration = Vector3.new(1.2, -0.5, 0.6)
	snow.Drag = 0.4
	snow.Parent = sky
end

local function makeSpawn(g, position: Vector3): SpawnLocation
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "RelaySpawn"
	spawn.Anchored = true
	spawn.Size = Vector3.new(6, 1, 6)
	spawn.CFrame = g:frame(face(position, Vector3.xAxis)) * CFrame.new(0, -spawn.Size.Y / 2, 0)
	spawn.Transparency = 1
	spawn.CanCollide = false
	spawn.CanQuery = false
	spawn.CanTouch = false
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Parent = g.parent
	return spawn
end

local function side(kit)
	drum(kit:group("Drum"))
	tower(kit:group("Tower"))
	bridge(kit:group("Bridge"))
	under(kit:group("Under"))
	air(kit:group("Air"))
	local spawn = makeSpawn(kit, v(-66, L1, 2))
	local prompt = terminal(kit:group("Terminal"), v(-73, L1, 10), Vector3.xAxis, "OUTPOST")
	return spawn, prompt
end

local Relay = {}
Relay.fallDepth = FALL_DEPTH

-- Builds the map with its centre at origin. Returns a spawn and a return terminal for each side.
function Relay.build(origin: CFrame)
	Collision.setup()
	local folder = Instance.new("Folder")
	folder.Name = "Relay"
	local spawns, terminals = {}, {}
	for index, turn in { CFrame.identity, CFrame.Angles(0, math.pi, 0) } do
		local sideFolder = Instance.new("Folder")
		sideFolder.Name = "Side" .. index
		sideFolder.Parent = folder
		local kit = Kit.new(sideFolder, origin * turn, SEED)
		spawns[index], terminals[index] = side(kit)
		kit:finish(sideFolder)
	end
	folder.Parent = workspace
	return { folder = folder, spawns = spawns, terminals = terminals }
end

-- A console in another room that leads to the map.
function Relay.buildTerminal(parent: Instance, base: Vector3, facing: Vector3): ProximityPrompt
	local kit = Kit.new(parent, CFrame.identity, SEED)
	return terminal(kit, base, facing, "RELAY 1V1")
end

return Relay
