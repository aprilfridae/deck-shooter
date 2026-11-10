-- The Outpost's wired look: walls of old CRT monitors stacked on each other with code running on their
-- screens, beige server towers with blinking lights, and cables everywhere, slung from the vault, hanging
-- loose with hard drives on the ends, and piled across the floor. Retro-futurist and lived in.
-- The client fills the screens and blinks the lights (OutpostWired.client.luau), and only while you're there.
-- Positions are the Outpost's own (Map.luau's local axes, full size). Each side hall gets the same set; the
-- East Hall is the West Hall turned round, so its set is turned with it.
local CollectionService = game:GetService("CollectionService")

local Kit = require(script.Parent.Kit)

local M = Enum.Material

local DECK = 6 -- the floors' top (Map.luau)
local CROSS_Z = 66 -- the side halls' centre line
local SOUTH_FACE = 46 -- inner face of a side hall's south wall
local NORTH_FACE = 86 -- and of its north wall
local END_FACE = -120 -- inner face of the West Hall's end wall
local SPRING = 24 -- where the side halls' vault starts
local VAULT_IN = 20 -- its inner radius

local SCREEN_TAG = "OutpostWiredScreen"
local LED_TAG = "OutpostWiredLed"

-- Old plastic in different greys, none of them bright (River found the beige-white ones too bright).
local CASES = {
	Color3.fromRGB(118, 120, 124),
	Color3.fromRGB(100, 102, 106),
	Color3.fromRGB(86, 88, 92),
	Color3.fromRGB(132, 132, 128),
	Color3.fromRGB(70, 72, 76),
	Color3.fromRGB(54, 56, 60),
}
local GLASS_DARK = Color3.fromRGB(14, 18, 24)
local SCREEN_LIGHT = Color3.fromRGB(120, 170, 255)
local CABLE_COLORS = { -- greys only
	Color3.fromRGB(22, 24, 26),
	Color3.fromRGB(40, 42, 46),
	Color3.fromRGB(64, 66, 70),
	Color3.fromRGB(92, 94, 98),
}

local function v(x: number, y: number, z: number): Vector3
	return Vector3.new(x, y, z)
end

-- The point on the side hall's vault above p. The East Hall's turn is a half turn about the centre line, so
-- the distance from it is the same in both halls.
local function ceiling(p: Vector3): Vector3
	local across = math.min(math.abs(p.Z - CROSS_Z), VAULT_IN - 1)
	return v(p.X, SPRING + math.sqrt(VAULT_IN * VAULT_IN - across * across) - 0.4, p.Z)
end

local function pick<T>(g, list: { T }): T
	return list[g.random:NextInteger(1, #list)]
end

-- A screen. kind is "Code" (lines of code scrolling), "Wave" (a scope of red-to-blue waves sliding across),
-- "Radar" (a sweep going round), "Bars" (a spectrum bouncing) or "Glow" (a blank blue glow, humming).
local function screen(g, cframe: CFrame, width: number, height: number, kind: string)
	local part = Kit.decor(g:block(v(width, height, 0.2), cframe, GLASS_DARK, M.Glass))
	part:SetAttribute("WiredKind", kind)
	part:SetAttribute("WiredSeed", g.random:NextInteger(1, 1e6))
	CollectionService:AddTag(part, SCREEN_TAG)
end

-- A CRT monitor: a deep case with its screen on the front. at is the bottom middle of its front face; the
-- frame's look direction is the way the screen faces.
local function crt(g, at: CFrame, size: number)
	local height, depth = size * 0.82, size * 0.9
	local color = g:vary(pick(g, CASES), 0.02)
	g:block(v(size, height, depth), at * CFrame.new(0, height / 2, depth / 2), color, M.SmoothPlastic)
	local roll = g.random:NextNumber()
	local kind = if roll < 0.4
		then "Code"
		elseif roll < 0.58 then "Wave"
		elseif roll < 0.68 then "Radar"
		elseif roll < 0.8 then "Bars"
		elseif roll < 0.92 then "Glow"
		else "Off"
	if kind ~= "Off" then
		screen(g, at * CFrame.new(0, height * 0.55, -0.06), size * 0.76, height * 0.66, kind)
	else
		Kit.decor(g:block(v(size * 0.76, height * 0.66, 0.2), at * CFrame.new(0, height * 0.55, -0.06), GLASS_DARK, M.Glass))
	end
	return height, depth
end

-- A beige server tower, with a column of status lights that blink.
local function tower(g, at: CFrame, height: number)
	local width, depth = 2.2, 3.4
	local color = g:vary(pick(g, CASES), 0.02)
	g:block(v(width, height, depth), at * CFrame.new(0, height / 2, depth / 2), color, M.SmoothPlastic)
	-- Drive bays.
	for bay = 1, math.floor(height / 1.1) - 1 do
		Kit.decor(g:block(v(width * 0.8, 0.5, 0.08), at * CFrame.new(0, height - bay * 1.05, -0.04), g:vary(color, 0.06), M.SmoothPlastic))
		local led = g:neon(v(0.12, 0.12, 0.06), at * CFrame.new(width * 0.32, height - bay * 1.05, -0.1), pick(g, {
			Color3.fromRGB(255, 190, 90),
			Color3.fromRGB(120, 255, 140),
			Color3.fromRGB(120, 255, 140),
			Color3.fromRGB(255, 70, 60),
		}))
		Kit.decor(led)
		led:SetAttribute("WiredSeed", g.random:NextInteger(1, 1e6))
		CollectionService:AddTag(led, LED_TAG)
	end
	return depth
end

-- A loose cable hanging from under the vault, some with a hard drive or a board on the end.
local function dangle(g, top: Vector3, length: number)
	local bottom = top - v(0, length, 0)
	g:cable(top, bottom + v(g:range(-0.6, 0.6), 0, g:range(-0.6, 0.6)), g:range(0, 0.4), g:range(0.08, 0.16), pick(g, CABLE_COLORS))
	if g:chance(0.45) then
		local board = g:chance(0.5)
		local size = if board then v(1.6, 2.2, 0.1) else v(1, 1.5, 0.3)
		local color = if board then Color3.fromRGB(52, 56, 58) else Color3.fromRGB(110, 112, 116)
		Kit.decor(g:block(size, CFrame.new(bottom - v(0, size.Y / 2, 0)) * CFrame.Angles(0, g:range(0, math.pi), g:range(-0.2, 0.2)), color, M.Metal))
	end
end

-- A wall of monitors and towers, width wide, against a wall. wall is a frame on the wall's face at floor
-- height, looking out into the room. Returns nothing; everything is built in g.
local function bank(g, wall: CFrame, width: number, tall: number)
	local x = -width / 2
	local tops = {}
	while x < width / 2 - 2 do
		local base = wall
		if g:chance(0.2) then
			local height = g:range(5, tall)
			local at = base * CFrame.new(x + 1.1, 0, -3.6) * CFrame.Angles(0, g:range(-0.08, 0.08), 0)
			tower(g, at, height)
			table.insert(tops, v(x + 1.1, height, 0))
			x += 2.4
		else
			-- A column of CRTs, each sat on the one below, a little askew.
			local size = g:range(2.6, 3.8)
			local y = 0
			local levels = 0
			while y + size * 0.82 <= tall and levels < 4 do
				local this = if levels == 0 then size else size * g:range(0.75, 1)
				local depth = this * 0.9
				local at = base * CFrame.new(x + size / 2 + g:range(-0.15, 0.15), y, -depth - 0.2) * CFrame.Angles(0, g:range(-0.1, 0.1), 0)
				local height = crt(g, at, this)
				y += height
				levels += 1
			end
			table.insert(tops, v(x + size / 2, y, 0))
			x += size + g:range(0, 0.3)
		end
	end
	-- One blue light for the whole bank, so the screens light the room without a light each.
	local glow = Kit.decor(g:block(v(0.2, 0.2, 0.2), wall * CFrame.new(0, tall * 0.5, -5), GLASS_DARK, M.SmoothPlastic))
	glow.Transparency = 1
	g:light(glow, "PointLight", { Color = SCREEN_LIGHT, Range = 18, Brightness = 1.6 })
	-- Cables from the tops up into the vault, and loose ones hanging in front.
	for _, top in tops do
		if g:chance(0.7) then
			local from = (wall * CFrame.new(top)).Position
			local to = ceiling((wall * CFrame.new(top.X + g:range(-3, 3), 0, g:range(-6, -2))).Position)
			g:cable(from, to, g:range(0.5, 2), g:range(0.1, 0.22), pick(g, CABLE_COLORS))
		end
	end
	for _ = 1, math.floor(width / 3) do
		local top = ceiling((wall * CFrame.new(g:range(-width / 2, width / 2), 0, g:range(-9, -5))).Position)
		-- Down to somewhere above head height.
		dangle(g, top, math.max(top.Y - DECK - g:range(9, 13), 2))
	end
	-- Cables across the floor in front, from the bank out into the room.
	for _ = 1, math.floor(width / 2.5) do
		local from = (wall * CFrame.new(g:range(-width / 2, width / 2), 0.08, -4.2)).Position
		local to = (wall * CFrame.new(g:range(-width / 2 - 3, width / 2 + 3), 0.08, g:range(-10, -6))).Position
		g:cable(from, to, g:range(-0.15, 0.15), g:range(0.1, 0.2), pick(g, CABLE_COLORS))
	end
	-- A desk chair left in front of one of them.
	if g:chance(0.6) then
		local seat = wall * CFrame.new(g:range(-width / 4, width / 4), 0, -7) * CFrame.Angles(0, g:range(-0.6, 0.6), 0)
		local dark = Color3.fromRGB(36, 38, 44)
		Kit.decor(g:block(v(1.8, 0.4, 1.8), seat * CFrame.new(0, 1.8, 0), dark, M.Fabric))
		Kit.decor(g:block(v(1.8, 2, 0.3), seat * CFrame.new(0, 3, 0.85), dark, M.Fabric))
		Kit.decor(g:block(v(0.25, 1.6, 0.25), seat * CFrame.new(0, 0.8, 0), Color3.fromRGB(70, 72, 76), M.Metal))
		Kit.decor(g:block(v(1.6, 0.15, 1.6), seat * CFrame.new(0, 0.08, 0) * CFrame.Angles(0, math.pi / 4, 0), Color3.fromRGB(70, 72, 76), M.Metal))
	end
end

local Wired = {}

-- Fills one side hall. turn is the East Hall's turn (nil for the West Hall), as in Map.luau.
function Wired.sideHall(kit, name: string, turn: CFrame?)
	local g = kit:group(name .. "Wired")
	local function on(face: CFrame): CFrame
		return if turn then turn * face else face
	end
	-- Between the pilasters, clear of the crates, drums and low walls already there.
	local south = CFrame.lookAt(v(0, DECK, SOUTH_FACE), v(0, DECK, SOUTH_FACE + 1))
	local north = CFrame.lookAt(v(0, DECK, NORTH_FACE), v(0, DECK, NORTH_FACE - 1))
	bank(g, on(CFrame.new(-82, 0, 0) * south), 13, 8.5)
	bank(g, on(CFrame.new(-46, 0, 0) * south), 13, 8.5)
	bank(g, on(CFrame.new(-100, 0, 0) * north), 12, 8.5)
	-- The West Hall's end wall gets the biggest wall of screens. The East Hall's has the corridor door in it.
	if not turn then
		local back = CFrame.lookAt(v(END_FACE, DECK, CROSS_Z), v(END_FACE + 1, DECK, CROSS_Z))
		bank(g, back, 30, 15)
	end
end

return Wired
