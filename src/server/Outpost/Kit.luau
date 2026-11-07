-- Helpers for building the Outpost out of parts. Every position is local to the kit's origin.
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local OutpostAssets = require(ReplicatedStorage:WaitForChild("Guns"):WaitForChild("OutpostAssets"))
local LightShaft = require(script.Parent.LightShaft)

local M = Enum.Material

local SIGN_TAG = "OutpostSign"
local SCREEN_TAG = "OutpostScreen"
local SIGN_DEPTH = 0.3
local CABLE_WIDTH = 0.12
local CABLE_COLOR = Color3.fromRGB(22, 24, 26)
local CABLE_SEGMENTS = 12
local SHAFT_SPREAD = 1.35 -- how much wider a light shaft is at the bottom
local BEZIER_DROP = 0.75 -- a beam's middle sags this share of its curve size
local COLOR_SHIFT = 0.035
local GRIME_COLOR = Color3.fromRGB(34, 30, 26)
local GRIME_TILE = 28
local STREAK_COLOR = Color3.fromRGB(40, 34, 28)
local PUDDLE_COLOR = Color3.fromRGB(30, 40, 42)
local CRACK_COLOR = Color3.fromRGB(28, 28, 26)
local PAINT_PIXELS = 12 -- per stud, for marks painted on floors
local WEAR_TILE = 7 -- studs

-- Looks to pick from for each kind of surface. Each part takes one, then a slight colour shift.
-- Floors keep to one material, so neighbouring panels differ only in shade.
local SURFACES: { [string]: { { any } } } = {
	concrete = {
		{ M.Concrete, Color3.fromRGB(118, 126, 123) },
		{ M.Concrete, Color3.fromRGB(106, 113, 109) },
		{ M.Concrete, Color3.fromRGB(127, 130, 123) },
		{ M.Concrete, Color3.fromRGB(98, 108, 106) },
		{ M.Plaster, Color3.fromRGB(114, 121, 117) },
	},
	darkConcrete = {
		{ M.Concrete, Color3.fromRGB(86, 93, 92) },
		{ M.Concrete, Color3.fromRGB(78, 84, 82) },
		{ M.Concrete, Color3.fromRGB(93, 96, 90) },
	},
	-- Smooth, so the floor reads as one pour. Its look comes from the overlays, not a tiling material.
	floor = {
		{ M.SmoothPlastic, Color3.fromRGB(98, 105, 103) },
		{ M.SmoothPlastic, Color3.fromRGB(102, 106, 101) },
	},
	steel = {
		{ M.Metal, Color3.fromRGB(56, 60, 62) },
		{ M.Metal, Color3.fromRGB(66, 68, 68) },
		{ M.CorrodedMetal, Color3.fromRGB(74, 67, 60) },
	},
	plate = {
		{ M.DiamondPlate, Color3.fromRGB(58, 62, 64) },
		{ M.DiamondPlate, Color3.fromRGB(68, 70, 70) },
		{ M.DiamondPlate, Color3.fromRGB(64, 63, 60) },
	},
	rust = {
		{ M.CorrodedMetal, Color3.fromRGB(178, 86, 34) },
		{ M.CorrodedMetal, Color3.fromRGB(150, 72, 34) },
		{ M.CorrodedMetal, Color3.fromRGB(166, 98, 50) },
		{ M.Metal, Color3.fromRGB(142, 70, 36) },
	},
	sheet = {
		{ M.Metal, Color3.fromRGB(92, 96, 94) },
		{ M.CorrodedMetal, Color3.fromRGB(98, 90, 80) },
		{ M.Metal, Color3.fromRGB(80, 88, 86) },
	},
	tile = {
		{ M.CeramicTiles, Color3.fromRGB(152, 168, 154) },
		{ M.CeramicTiles, Color3.fromRGB(140, 156, 144) },
		{ M.CeramicTiles, Color3.fromRGB(160, 166, 150) },
	},
	tileFloor = {
		{ M.CeramicTiles, Color3.fromRGB(88, 99, 94) },
		{ M.CeramicTiles, Color3.fromRGB(96, 102, 92) },
		{ M.CeramicTiles, Color3.fromRGB(82, 92, 88) },
	},
	wood = {
		{ M.WoodPlanks, Color3.fromRGB(78, 62, 48) },
		{ M.Wood, Color3.fromRGB(70, 56, 44) },
		{ M.WoodPlanks, Color3.fromRGB(92, 74, 56) },
	},
}

export type SignOptions = {
	text: string,
	color: Color3, -- the text
	style: string?, -- a font style from GlyphData
	back: Color3?,
	fill: Color3?, -- a lit background, for lightboxes
	light: Color3?, -- a glow cast forward
	vertical: boolean?, -- one letter per line
	scale: number?, -- text height as a share of the sign's
}

local Kit = {}
Kit.__index = Kit
Kit.signTag = SIGN_TAG
Kit.screenTag = SCREEN_TAG

-- scale shrinks everything the kit builds, about the origin. Positions and sizes passed in stay
-- at full size.
function Kit.new(parent: Instance, origin: CFrame, seed: number, scale: number?)
	return setmetatable({ parent = parent, origin = origin, random = Random.new(seed), scale = scale or 1 }, Kit)
end

-- The same kit, building into a new folder.
function Kit:group(name: string)
	local folder = Instance.new("Folder")
	folder.Name = name
	folder.Parent = self.parent
	return setmetatable({ parent = folder, origin = self.origin, random = self.random, scale = self.scale }, Kit)
end

function Kit:point(position: Vector3): Vector3
	return self.origin * (position * self.scale)
end

-- Where a full-size cframe lands in the world.
function Kit:frame(cframe: CFrame): CFrame
	return self.origin * (cframe - cframe.Position + cframe.Position * self.scale)
end

function Kit:range(low: number, high: number): number
	return low + self.random:NextNumber() * (high - low)
end

function Kit:chance(share: number): boolean
	return self.random:NextNumber() < share
end

-- Weathers a colour a little, so long runs of the same part don't look flat.
function Kit:vary(color: Color3, amount: number?): Color3
	local shift = (self.random:NextNumber() - 0.5) * 2 * (amount or 0.04)
	return Color3.new(
		math.clamp(color.R + shift, 0, 1),
		math.clamp(color.G + shift, 0, 1),
		math.clamp(color.B + shift, 0, 1)
	)
end

-- Looks only: nothing collides with it, raycasts pass through and it casts no shadow.
function Kit.decor(part: BasePart): BasePart
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	return part
end

function Kit:place(part: BasePart, size: Vector3, cframe: CFrame, color: Color3, material: Enum.Material?): BasePart
	part.Anchored = true
	part.Size = size * self.scale
	part.CFrame = self:frame(cframe)
	part.Color = color
	part.Material = material or Enum.Material.Concrete
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = self.parent
	return part
end

function Kit:block(size: Vector3, cframe: CFrame, color: Color3, material: Enum.Material?): BasePart
	return self:place(Instance.new("Part"), size, cframe, color, material)
end

-- An axis-aligned block between two opposite corners.
function Kit:box(a: Vector3, b: Vector3, color: Color3, material: Enum.Material?): BasePart
	local size = Vector3.new(math.abs(b.X - a.X), math.abs(b.Y - a.Y), math.abs(b.Z - a.Z))
	return self:block(size, CFrame.new((a + b) / 2), color, material)
end

-- One of a surface kind's looks, with a slight colour shift.
function Kit:surface(kind: string): (Color3, Enum.Material)
	local choices = SURFACES[kind]
	local pick = choices[self.random:NextInteger(1, #choices)]
	return self:vary(pick[2], COLOR_SHIFT), pick[1]
end

-- A block with one of a surface kind's looks.
function Kit:solid(kind: string, size: Vector3, cframe: CFrame): BasePart
	local color, material = self:surface(kind)
	return self:block(size, cframe, color, material)
end

-- An axis-aligned box with one of a surface kind's looks.
function Kit:boxOf(kind: string, a: Vector3, b: Vector3): BasePart
	local color, material = self:surface(kind)
	return self:box(a, b, color, material)
end

local function grimeTexture(kit: any, part: BasePart, face: Enum.NormalId, transparency: number?)
	local texture = Instance.new("Texture")
	texture.Name = "Grime"
	texture.Texture = OutpostAssets.grime
	texture.Face = face
	texture.StudsPerTileU = GRIME_TILE
	texture.StudsPerTileV = GRIME_TILE
	texture.OffsetStudsU = kit:range(0, GRIME_TILE)
	texture.OffsetStudsV = kit:range(0, GRIME_TILE)
	texture.Color3 = GRIME_COLOR
	texture.Transparency = transparency or kit:range(0.3, 0.55)
	texture.Parent = part
end

local function streakTexture(kit: any, part: BasePart, face: Enum.NormalId)
	local texture = Instance.new("Texture")
	texture.Name = "Streaks"
	texture.Texture = OutpostAssets.streaks
	texture.Face = face
	-- One tile covers the face's height, so every run starts at its top edge.
	texture.StudsPerTileU = kit:range(14, 22)
	texture.StudsPerTileV = part.Size.Y / kit.scale
	texture.OffsetStudsU = kit:range(0, 22)
	texture.Color3 = STREAK_COLOR
	texture.Transparency = kit:range(0.2, 0.45)
	texture.Parent = part
end

-- The two biggest upright faces of an upright part.
local function wallFaces(part: BasePart): { Enum.NormalId }
	if part.Size.X >= part.Size.Z then
		return { Enum.NormalId.Front, Enum.NormalId.Back }
	end
	return { Enum.NormalId.Left, Enum.NormalId.Right }
end

local ALL_SIDES = { Enum.NormalId.Front, Enum.NormalId.Back, Enum.NormalId.Left, Enum.NormalId.Right }

-- Weathers a part with grime, and water streaks on its walls.
-- how: "floor" for the top face, "wet" for the top face with puddles too, "wall" for the two big
-- upright faces, "block" for every upright face and the top, "shell" for the top and bottom.
function Kit:dirty(part: BasePart, how: string, transparency: number?): BasePart
	if how == "floor" or how == "wet" then
		grimeTexture(self, part, Enum.NormalId.Top, transparency)
		if how == "wet" then
			self:wet(part)
		end
	elseif how == "wall" then
		for _, face in wallFaces(part) do
			grimeTexture(self, part, face, transparency)
			streakTexture(self, part, face)
		end
	elseif how == "block" then
		for _, face in ALL_SIDES do
			grimeTexture(self, part, face, transparency)
			streakTexture(self, part, face)
		end
		grimeTexture(self, part, Enum.NormalId.Top, transparency)
	elseif how == "shell" then
		grimeTexture(self, part, Enum.NormalId.Top, transparency)
		grimeTexture(self, part, Enum.NormalId.Bottom, transparency)
	elseif how == "wedgeShell" then -- a wedge's two big faces are its sides
		grimeTexture(self, part, Enum.NormalId.Left, transparency)
		grimeTexture(self, part, Enum.NormalId.Right, transparency)
	end
	return part
end

-- An axis-aligned box cut into panels of about cell studs across X and Z, each with its own look.
function Kit:panels(kind: string, a: Vector3, b: Vector3, cell: number, how: string?): { BasePart }
	local low = Vector3.new(math.min(a.X, b.X), math.min(a.Y, b.Y), math.min(a.Z, b.Z))
	local high = Vector3.new(math.max(a.X, b.X), math.max(a.Y, b.Y), math.max(a.Z, b.Z))
	local across = math.max(1, math.round((high.X - low.X) / cell))
	local along = math.max(1, math.round((high.Z - low.Z) / cell))
	local parts = {}
	for i = 0, across - 1 do
		for k = 0, along - 1 do
			local x0 = low.X + (high.X - low.X) * i / across
			local x1 = low.X + (high.X - low.X) * (i + 1) / across
			local z0 = low.Z + (high.Z - low.Z) * k / along
			local z1 = low.Z + (high.Z - low.Z) * (k + 1) / along
			local part = self:boxOf(kind, Vector3.new(x0, low.Y, z0), Vector3.new(x1, high.Y, z1))
			if how then
				self:dirty(part, how)
			end
			table.insert(parts, part)
		end
	end
	return parts
end

local function overlay(kit: any, part: BasePart, face: Enum.NormalId, image: string, tile: number, color: Color3, transparency: number, layer: number)
	local texture = Instance.new("Texture")
	texture.Texture = image
	texture.Face = face
	texture.StudsPerTileU = tile
	texture.StudsPerTileV = tile
	texture.OffsetStudsU = kit:range(0, tile)
	texture.OffsetStudsV = kit:range(0, tile)
	texture.Color3 = color
	texture.Transparency = transparency
	texture.ZIndex = layer
	texture.Parent = part
	return texture
end

-- Marks painted on a floor slab, placed in the kit's local studs.
local Painter = {}
Painter.__index = Painter

-- A floor as one slab, so it reads as a single pour rather than a grid of squares.
-- Its front faces up, so painted marks land where they're asked to.
-- Returns the slab and a painter for it.
function Kit:floor(kind: string, low: Vector3, high: Vector3, wet: boolean?): (BasePart, any)
	local color, material = self:surface(kind)
	local size = Vector3.new(high.X - low.X, high.Z - low.Z, high.Y - low.Y)
	-- Right along X and up along Z, which leaves the front facing straight up.
	local cframe = CFrame.fromMatrix((low + high) / 2, Vector3.xAxis, Vector3.zAxis)
	local slab = self:block(size, cframe, color, material)
	slab.Reflectance = 0.04 -- a faint damp sheen
	-- Big tiles, so nothing visibly repeats across a floor.
	local up = Enum.NormalId.Front
	overlay(self, slab, up, OutpostAssets.grime, 96, GRIME_COLOR, 0.5, 1)
	overlay(self, slab, up, OutpostAssets.cracks, 90, CRACK_COLOR, 0.5, 2)
	if wet then
		overlay(self, slab, up, OutpostAssets.puddles, 64, PUDDLE_COLOR, 0.25, 3)
	end

	local gui = Instance.new("SurfaceGui")
	gui.Name = "Paint"
	gui.Face = up
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = PAINT_PIXELS
	gui.LightInfluence = 1
	gui.ClipsDescendants = true
	gui.Parent = slab
	-- Looking down at the front, its left edge is the slab's high X and its top edge the high Z.
	return slab, setmetatable({ gui = gui, maxX = high.X, maxZ = high.Z, floor = color, kit = self }, Painter)
end

function Painter:frame(x0: number, z0: number, x1: number, z1: number): Frame
	local frame = Instance.new("Frame")
	frame.BorderSizePixel = 0
	frame.Position = UDim2.fromOffset((self.maxX - math.max(x0, x1)) * PAINT_PIXELS, (self.maxZ - math.max(z0, z1)) * PAINT_PIXELS)
	frame.Size = UDim2.fromOffset(math.abs(x1 - x0) * PAINT_PIXELS, math.abs(z1 - z0) * PAINT_PIXELS)
	frame.Parent = self.gui
	return frame
end

-- Old paint: blotches of the floor's own colour show through.
function Painter:wear(frame: Frame, amount: number?)
	local tile = WEAR_TILE * PAINT_PIXELS
	frame.ClipsDescendants = true
	local wear = Instance.new("ImageLabel")
	wear.BackgroundTransparency = 1
	wear.Image = OutpostAssets.grime
	wear.ImageColor3 = self.floor
	wear.ImageTransparency = amount or 0
	wear.ScaleType = Enum.ScaleType.Tile
	wear.TileSize = UDim2.fromOffset(tile, tile)
	wear.Position = UDim2.fromOffset(-self.kit:range(0, tile), -self.kit:range(0, tile))
	wear.Size = UDim2.new(1, tile, 1, tile)
	wear.Parent = frame
end

-- A painted strip between two corners.
function Painter:mark(x0: number, z0: number, x1: number, z1: number, color: Color3, transparency: number): Frame
	local frame = self:frame(x0, z0, x1, z1)
	frame.BackgroundColor3 = color
	frame.BackgroundTransparency = transparency
	self:wear(frame)
	return frame
end

-- A dashed line running along Z at x.
function Painter:dashes(x: number, z0: number, z1: number, width: number, dash: number, gap: number, color: Color3, transparency: number)
	local z = math.min(z0, z1)
	while z < math.max(z0, z1) do
		local finish = math.min(z + dash, math.max(z0, z1))
		self:mark(x - width / 2, z, x + width / 2, finish, color, transparency)
		z = finish + gap
	end
end

-- A painted box outline.
function Painter:outline(x0: number, z0: number, x1: number, z1: number, width: number, color: Color3, transparency: number)
	self:mark(x0, z0, x1, z0 + width, color, transparency)
	self:mark(x0, z1 - width, x1, z1, color, transparency)
	self:mark(x0, z0 + width, x0 + width, z1 - width, color, transparency)
	self:mark(x1 - width, z0 + width, x1, z1 - width, color, transparency)
end

-- A round patch, such as a manhole cover or a damp spot.
function Painter:disc(x: number, z: number, diameter: number, color: Color3, transparency: number): Frame
	local half = diameter / 2
	local frame = self:frame(x - half, z - half, x + half, z + half)
	frame.BackgroundColor3 = color
	frame.BackgroundTransparency = transparency
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = frame
	return frame
end

-- A drain grate: a dark slot with bars across it.
function Painter:grate(x0: number, z0: number, x1: number, z1: number)
	local frame = self:frame(x0, z0, x1, z1)
	frame.BackgroundColor3 = Color3.fromRGB(20, 22, 24)
	frame.BackgroundTransparency = 0.1
	local across = math.abs(x1 - x0) >= math.abs(z1 - z0)
	local length = if across then math.abs(x1 - x0) else math.abs(z1 - z0)
	local bars = math.floor(length / 0.4)
	for index = 1, bars - 1 do
		local bar = Instance.new("Frame")
		bar.BorderSizePixel = 0
		bar.BackgroundColor3 = Color3.fromRGB(78, 82, 82)
		bar.Size = if across then UDim2.new(0, 2, 1, 0) else UDim2.new(1, 0, 0, 2)
		bar.Position = if across then UDim2.fromScale(index / bars, 0) else UDim2.fromScale(0, index / bars)
		bar.Parent = frame
	end
end

-- A dark irregular stain, like oil or old water.
function Painter:stain(x: number, z: number, width: number, length: number, transparency: number?)
	local frame = self:frame(x - width / 2, z - length / 2, x + width / 2, z + length / 2)
	frame.BackgroundTransparency = 1
	local stain = Instance.new("ImageLabel")
	stain.BackgroundTransparency = 1
	stain.Image = OutpostAssets.grime
	stain.ImageColor3 = Color3.fromRGB(18, 20, 20)
	stain.ImageTransparency = transparency or 0.3
	stain.ImageRectOffset = Vector2.new(self.kit:range(0, 256), self.kit:range(0, 256))
	stain.ImageRectSize = Vector2.new(256, 256)
	stain.Size = UDim2.fromScale(1, 1)
	stain.Parent = frame
end

function Kit:wedge(size: Vector3, cframe: CFrame, color: Color3, material: Enum.Material?): BasePart
	return self:place(Instance.new("WedgePart"), size, cframe, color, material)
end

-- A cylinder along the cframe's X axis.
function Kit:cylinder(cframe: CFrame, length: number, diameter: number, color: Color3, material: Enum.Material?): BasePart
	local part = Instance.new("Part")
	part.Shape = Enum.PartType.Cylinder
	return self:place(part, Vector3.new(length, diameter, diameter), cframe, color, material)
end

-- An upright cylinder standing on base.
function Kit:post(base: Vector3, height: number, diameter: number, color: Color3, material: Enum.Material?): BasePart
	local cframe = CFrame.new(base + Vector3.new(0, height / 2, 0)) * CFrame.Angles(0, 0, math.pi / 2)
	return self:cylinder(cframe, height, diameter, color, material)
end

function Kit:ball(position: Vector3, diameter: number, color: Color3, material: Enum.Material?): BasePart
	local part = Instance.new("Part")
	part.Shape = Enum.PartType.Ball
	return self:place(part, Vector3.one * diameter, CFrame.new(position), color, material)
end

-- A lit strip, or a plain matte one while a group has `noNeon` set.
function Kit:neon(size: Vector3, cframe: CFrame, color: Color3): BasePart
	local material = if self.noNeon then Enum.Material.SmoothPlastic else Enum.Material.Neon
	return Kit.decor(self:block(size, cframe, color, material))
end

function Kit:light(part: BasePart, className: string, props: { [string]: any }): Instance
	local light = Instance.new(className)
	for key, value in props do
		(light :: any)[key] = value
	end
	light.Parent = part
	return light
end

-- A small glowing housing with a point light in it.
function Kit:lamp(position: Vector3, color: Color3, range: number, brightness: number, shadows: boolean?, size: number?): BasePart
	local width = size or 0.7
	local bulb = self:neon(Vector3.new(width, width * 0.6, width), CFrame.new(position), color)
	self:light(bulb, "PointLight", { Color = color, Range = range, Brightness = brightness, Shadows = shadows == true })
	return bulb
end

-- Wet pools drawn on a part's top face. Being a texture, they can't flicker against the floor.
function Kit:wet(part: BasePart, tile: number?): BasePart
	local size = tile or 34
	local texture = Instance.new("Texture")
	texture.Name = "Puddles"
	texture.Texture = OutpostAssets.puddles
	texture.Face = Enum.NormalId.Top
	texture.StudsPerTileU = size
	texture.StudsPerTileV = size
	texture.OffsetStudsU = self:range(0, size)
	texture.OffsetStudsV = self:range(0, size)
	texture.Color3 = PUDDLE_COLOR
	texture.Transparency = self:range(0.15, 0.35)
	texture.ZIndex = 2 -- over the grime
	texture.Parent = part
	return part
end

local function anchorPoint(kit: any, position: Vector3): Attachment
	local attachment = Instance.new("Attachment")
	-- Pointing down, so a positive curve size makes the beam sag.
	attachment.CFrame = CFrame.fromMatrix(kit:point(position), Vector3.new(0, -1, 0), Vector3.new(1, 0, 0))
	attachment.Parent = workspace.Terrain
	return attachment
end

-- A slack cable between two points, drawn as a beam. It costs no parts.
function Kit:cable(a: Vector3, b: Vector3, sag: number, width: number?, color: Color3?): Beam
	local beam = Instance.new("Beam")
	beam.Attachment0 = anchorPoint(self, a)
	beam.Attachment1 = anchorPoint(self, b)
	beam.CurveSize0 = sag * self.scale / BEZIER_DROP
	beam.CurveSize1 = -sag * self.scale / BEZIER_DROP
	beam.Width0 = (width or CABLE_WIDTH) * self.scale
	beam.Width1 = (width or CABLE_WIDTH) * self.scale
	beam.Segments = CABLE_SEGMENTS
	beam.FaceCamera = true
	beam.Color = ColorSequence.new(color or CABLE_COLOR)
	beam.LightInfluence = 1
	beam.Texture = ""
	beam.Parent = beam.Attachment0
	return beam
end

-- A round cone of light, like daylight through a hole in the roof. It widens toward the bottom.
function Kit:shaft(top: Vector3, bottom: Vector3, radius: number, color: Color3)
	for _, column in LightShaft.columns(radius) do
		local offset = Vector3.new(column.x, 0, column.z)
		local beam = self:cable(top + offset, bottom + offset * SHAFT_SPREAD, 0, column.width, color)
		beam.Width1 = column.width * SHAFT_SPREAD * self.scale
		beam.Segments = 1
		beam.LightInfluence = 0
		beam.LightEmission = 1
		beam.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, column.transparency),
			NumberSequenceKeypoint.new(0.7, (column.transparency + 1) / 2),
			NumberSequenceKeypoint.new(1, 1),
		})
	end
end

-- A sign whose front faces the cframe's look direction. The client draws its text.
function Kit:sign(cframe: CFrame, width: number, height: number, options: SignOptions): BasePart
	local back = Kit.decor(self:block(
		Vector3.new(width, height, SIGN_DEPTH),
		cframe,
		options.back or Color3.fromRGB(18, 20, 24),
		Enum.Material.SmoothPlastic
	))
	back:SetAttribute("SignText", options.text)
	back:SetAttribute("SignStyle", options.style or "LabelBold")
	back:SetAttribute("SignColor", options.color)
	back:SetAttribute("SignFill", options.fill)
	back:SetAttribute("SignVertical", options.vertical)
	back:SetAttribute("SignScale", options.scale)
	CollectionService:AddTag(back, SIGN_TAG)

	if options.light then
		self:light(back, "SurfaceLight", {
			Face = Enum.NormalId.Front,
			Color = options.light,
			Brightness = 1.2,
			Range = 12,
			Angle = 120,
		})
	end
	return back
end

-- A screen the client fills with live numbers. kind says which.
function Kit:screen(cframe: CFrame, width: number, height: number, kind: string): BasePart
	local screen = Kit.decor(self:block(
		Vector3.new(width, height, SIGN_DEPTH),
		cframe,
		Color3.fromRGB(18, 20, 24),
		Enum.Material.SmoothPlastic
	))
	screen:SetAttribute("ScreenKind", kind)
	CollectionService:AddTag(screen, SCREEN_TAG)
	return screen
end

local function scaledSequence(sequence: NumberSequence, scale: number): NumberSequence
	local keys = {}
	for index, key in sequence.Keypoints do
		keys[index] = NumberSequenceKeypoint.new(key.Time, key.Value * scale, key.Envelope * scale)
	end
	return NumberSequence.new(keys)
end

-- Shrinks what can only be set once everything exists: tiles, light reach, particles and painted
-- floors, whose marks are laid out in full-size studs.
function Kit:finish(folder: Instance)
	local scale = self.scale
	for _, item in folder:GetDescendants() do
		if item:IsA("Texture") then
			item.StudsPerTileU *= scale
			item.StudsPerTileV *= scale
			item.OffsetStudsU *= scale
			item.OffsetStudsV *= scale
		elseif item:IsA("PointLight") or item:IsA("SpotLight") or item:IsA("SurfaceLight") then
			item.Range *= scale
		elseif item:IsA("SurfaceGui") then
			item.PixelsPerStud /= scale
		elseif item:IsA("ParticleEmitter") then
			item.Size = scaledSequence(item.Size, scale)
			item.Speed = NumberRange.new(item.Speed.Min * scale, item.Speed.Max * scale)
			item.Acceleration *= scale
		end
	end
end

function Kit:prompt(part: BasePart, objectText: string, actionText: string, hold: number?): ProximityPrompt
	local prompt = Instance.new("ProximityPrompt")
	prompt.ObjectText = objectText
	prompt.ActionText = actionText
	prompt.HoldDuration = hold or 0
	prompt.MaxActivationDistance = 9
	prompt.RequiresLineOfSight = false
	prompt.Parent = part
	return prompt
end

return Kit
