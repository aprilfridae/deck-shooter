-- What each rarity adds to the front of a card, on top of the motion every card has
-- (docs/specs/card-face-redesign.md, "What each rarity adds"). Field adds nothing.
-- Nothing here may stick out past the card: the HUD tilts its cards, and Roblox doesn't clip rotated UI.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CardCore = ReplicatedStorage:WaitForChild("CardCore")
local CardArt = require(CardCore:WaitForChild("CardArt"))
local CardLayout = require(CardCore:WaitForChild("CardLayout"))
local Guns = ReplicatedStorage:WaitForChild("Guns")
local CardMotion = require(Guns:WaitForChild("Hud"):WaitForChild("CardMotion"))
local Palette = require(Guns:WaitForChild("Palette"))
local CardEffects = require(script.Parent.CardEffects)

export type Parts = {
	under: GuiObject, -- an empty layer behind everything on the card
	monogram: ImageLabel,
	starBig: ImageLabel,
	starSmall: ImageLabel,
	ink: Color3,
	mark: Color3,
}
type Update = (elapsed: number, shine: number) -> ()

local EMBERS = 24
local MARKS = 14
local TWINKLES = 9
local RED_BAND_HALF_WIDTH = 0.2
local RED_BAND_STRENGTH = 0.42
local GRID_TRANSPARENCY = 0.84
local GRID_PIXELS = 80 -- one tile of the grid image
local MARK_ARM = 36
local MARK_THICKNESS = 5
local HAIRLINE = 3
local HAIRLINE_TRANSPARENCY = 0.55
local HAIRLINE_GAP = 70 -- either side of the crosshair's centre
local PING_FROM = 56
local PING_TO = 134
local PING_TIME = 1.3
local PING_THICKNESS = 4
local SWIRL_TRANSPARENCY = 0.87
local LIGHT_HALF_WIDTH = 0.3
-- Cyan, violet, pink and gold, like the foil on a banknote. It ends where it starts so it can loop.
local FOIL = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Palette.DataCyan),
	ColorSequenceKeypoint.new(0.25, Color3.fromRGB(122, 92, 255)),
	ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 79, 216)),
	ColorSequenceKeypoint.new(0.75, Color3.fromRGB(255, 209, 102)),
	ColorSequenceKeypoint.new(1, Palette.DataCyan),
})

local function frame(parent: GuiObject, color: Color3): Frame
	local made = Instance.new("Frame")
	made.BackgroundColor3 = color
	made.BorderSizePixel = 0
	made.Parent = parent
	return made
end

local function image(parent: GuiObject, face: number, name: string, rect: any, color: Color3): ImageLabel
	local label = Instance.new("ImageLabel")
	label.BackgroundTransparency = 1
	label.Image = CardArt.layer(name)
	label.ImageColor3 = color
	label.Position = UDim2.fromOffset(rect.x * face, rect.y * face)
	label.Size = UDim2.fromOffset(rect.w * face, rect.h * face)
	label.Parent = parent
	return label
end

local function whole(parent: GuiObject, face: number, name: string, color: Color3): ImageLabel
	local label = image(parent, face, name, { x = 0, y = 0, w = CardLayout.WIDTH, h = CardLayout.HEIGHT }, color)
	CardEffects.rounded(label, UDim.new(0, CardLayout.CORNER * face))
	return label
end

local function redline(root: GuiObject, face: number, width: number, parts: Parts): { Update }
	local band = CardEffects.band(
		root,
		CardLayout.CORNER * face,
		RED_BAND_HALF_WIDTH,
		ColorSequence.new(Palette.HazardRed),
		RED_BAND_STRENGTH,
		90
	)
	local embers = {}
	for index = 1, CardLayout.count(EMBERS, width) do
		embers[index] = frame(root, Palette.HazardRed)
	end
	return {
		function(elapsed: number)
			-- Set on both axes: a band turned a quarter only shows movement along its own direction.
			local offset = CardMotion.sweepDown(elapsed)
			band.Offset = Vector2.new(offset, offset)
			for index, ember in embers do
				local x, y, size, clear = CardMotion.ember(index - 1, elapsed)
				ember.Position = UDim2.fromOffset(x * face, y * face)
				ember.Size = UDim2.fromOffset(size * face, size * face)
				ember.BackgroundTransparency = clear
			end
			parts.monogram.ImageTransparency = CardMotion.flicker(elapsed)
		end,
	}
end

local function prototype(root: GuiObject, face: number, width: number, parts: Parts): { Update }
	-- The grid never moves or sticks out: it slides which part of its image is the tile, as the stripes do.
	local grid = whole(parts.under, face, "grid", parts.ink)
	grid.ImageTransparency = GRID_TRANSPARENCY
	grid.ScaleType = Enum.ScaleType.Tile
	grid.ImageRectSize = Vector2.new(GRID_PIXELS, GRID_PIXELS)
	grid.TileSize = UDim2.fromOffset(CardLayout.GRID_TILE * face, CardLayout.GRID_TILE * face)

	local marks = {}
	for index = 1, CardLayout.count(MARKS, width) do
		local holder = Instance.new("Frame")
		holder.BackgroundTransparency = 1
		holder.Parent = root
		local x, y = CardMotion.mark(index - 1, 0)
		holder.Position = UDim2.fromOffset(x * face, y * face)
		for _, size in { Vector2.new(MARK_ARM, MARK_THICKNESS), Vector2.new(MARK_THICKNESS, MARK_ARM) } do
			local arm = frame(holder, parts.ink)
			arm.AnchorPoint = Vector2.new(0.5, 0.5)
			arm.Size = UDim2.fromOffset(size.X * face, size.Y * face)
		end
		marks[index] = holder
	end

	-- The crosshair stays locked on the globe (River, 2026-11-11), with hairlines out to the card's edges.
	local globe = CardLayout.GLOBE
	image(root, face, "crosshair", CardLayout.CROSSHAIR, parts.ink)
	local thin = math.max(1, HAIRLINE * face)
	for _, line in {
		{ 0, globe.y, globe.x - HAIRLINE_GAP, 0 },
		{ globe.x + HAIRLINE_GAP, globe.y, CardLayout.WIDTH - globe.x - HAIRLINE_GAP, 0 },
		{ globe.x, 0, 0, globe.y - HAIRLINE_GAP },
		{ globe.x, globe.y + HAIRLINE_GAP, 0, CardLayout.HEIGHT - globe.y - HAIRLINE_GAP },
	} do
		local hair = frame(root, parts.ink)
		hair.BackgroundTransparency = HAIRLINE_TRANSPARENCY
		hair.AnchorPoint = if line[3] > 0 then Vector2.new(0, 0.5) else Vector2.new(0.5, 0)
		hair.Position = UDim2.fromOffset(line[1] * face, line[2] * face)
		hair.Size = UDim2.fromOffset(math.max(line[3] * face, thin), math.max(line[4] * face, thin))
	end
	local ring = Instance.new("Frame")
	ring.BackgroundTransparency = 1
	ring.AnchorPoint = Vector2.new(0.5, 0.5)
	ring.Position = UDim2.fromOffset(globe.x * face, globe.y * face)
	ring.Parent = root
	CardEffects.rounded(ring, UDim.new(0.5, 0))
	local stroke = Instance.new("UIStroke")
	stroke.Color = parts.ink
	stroke.Thickness = math.max(1, PING_THICKNESS * face)
	stroke.Parent = ring

	-- The measuring line draws itself by sliding the clear part of a gradient off it.
	local measure = image(root, face, "measure", CardLayout.MEASURE, parts.ink)
	local wipe = Instance.new("UIGradient")
	wipe.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.5, 0),
		NumberSequenceKeypoint.new(0.501, 1),
		NumberSequenceKeypoint.new(1, 1),
	})
	wipe.Parent = measure

	return {
		function(elapsed: number)
			local shift = CardMotion.gridShift(elapsed) * GRID_PIXELS
			grid.ImageRectOffset = Vector2.new(shift, shift)
			for index, holder in marks do
				local _, _, shown = CardMotion.mark(index - 1, elapsed)
				holder.Visible = shown
			end
			local progress = (elapsed % PING_TIME) / PING_TIME
			local radius = (PING_FROM + (PING_TO - PING_FROM) * progress) * face
			ring.Size = UDim2.fromOffset(radius * 2, radius * 2)
			stroke.Transparency = 0.1 + 0.9 * progress
			local reveal, clear = CardMotion.measure(elapsed)
			wipe.Offset = Vector2.new(reveal - 0.5, 0)
			measure.ImageTransparency = clear
		end,
	}
end

local function zeroDay(root: GuiObject, face: number, width: number, parts: Parts): { Update }
	-- Banknote lines: barely there, until the light crosses and shows them in foil colours (River, 2026-11-11:
	-- "like EU currency where there's background stuff that's holographic depending on which way the light hits").
	local faint = whole(parts.under, face, "swirl", Palette.DataCyan)
	faint.ImageTransparency = SWIRL_TRANSPARENCY
	local lit = whole(parts.under, face, "swirl", Color3.new(1, 1, 1))
	local light = Instance.new("UIGradient")
	light.Rotation = 20 -- the shine's lean, so the two travel together
	light.Color = FOIL
	light.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.5 - LIGHT_HALF_WIDTH, 1),
		NumberSequenceKeypoint.new(0.5, 0),
		NumberSequenceKeypoint.new(0.5 + LIGHT_HALF_WIDTH, 1),
		NumberSequenceKeypoint.new(1, 1),
	})
	light.Offset = Vector2.new(-1, 0)
	light.Parent = lit

	local foils = {}
	for _, star in { parts.starBig, parts.starSmall } do
		star.ImageColor3 = Color3.new(1, 1, 1)
		local foil = Instance.new("UIGradient")
		foil.Rotation = 20
		foil.Color = FOIL
		foil.Parent = star
		table.insert(foils, foil)
	end

	local twinkles = {}
	for index = 1, CardLayout.count(TWINKLES, width) do
		local twinkle = image(root, face, "star_small", { x = 0, y = 0, w = 0, h = 0 }, Palette.Bone)
		twinkle.AnchorPoint = Vector2.new(0.5, 0.5)
		local x, y = CardMotion.twinkle(index - 1, 0)
		twinkle.Position = UDim2.fromOffset(x * face, y * face)
		twinkles[index] = twinkle
	end

	return {
		function(elapsed: number, shine: number)
			light.Offset = Vector2.new(shine, 0)
			local slide = CardMotion.foilShift(elapsed) * 2 - 1
			for _, foil in foils do
				foil.Offset = Vector2.new(slide, 0)
			end
			for index, twinkle in twinkles do
				local _, _, size = CardMotion.twinkle(index - 1, elapsed)
				twinkle.Size = UDim2.fromOffset(size * face, size * face)
			end
		end,
	}
end

local BUILDERS = { Redline = redline, Prototype = prototype, ZeroDay = zeroDay }

local CardFaceFx = {}

-- Builds this look's effects on a card `width` pixels wide, and returns what to call each frame with the time
-- since the card appeared and the shine's current offset.
function CardFaceFx.build(look: string, root: GuiObject, face: number, width: number, parts: Parts): { Update }
	local builder = BUILDERS[look]
	return if builder then builder(root, face, width, parts) else {}
end

return CardFaceFx
