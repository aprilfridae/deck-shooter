-- A card in the menus: its baked image with live text, stripes, shine and motion on top.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local CardCore = ReplicatedStorage:WaitForChild("CardCore")
local CardArt = require(CardCore:WaitForChild("CardArt"))
local CardLook = require(CardCore:WaitForChild("CardLook"))
local Cards = require(CardCore:WaitForChild("Cards"))
local CardText = require(CardCore:WaitForChild("CardText"))
local Guns = ReplicatedStorage:WaitForChild("Guns")
local CardMotion = require(Guns:WaitForChild("Hud"):WaitForChild("CardMotion"))
local Palette = require(Guns:WaitForChild("Palette"))
local TypeLabel = require(script.Parent.TypeLabel)

-- Everything below is in card units: a card is 150 wide and 240 tall.
local WIDTH = 150
local HEIGHT = 240
local CORNER = 10
local LEFT = 10
local RIGHT = 140
local TEXT_SIZE = 11
local SERIAL_SIZE = 12
local TRACKING = 0.04 -- of the size
local SERIAL_LINE = 19
local NAME_LINE = 218
local RARITY_LINE = 233
local BLOCK_LEFT = 12
local BLOCK_TOP = 160
local BLOCK_WIDTH = 92
local BLOCK_HEIGHT = 38
local STRIPE_TILE = 28
local STRIPE_TIME = 1.4 -- seconds for Prototype's stripes to move one tile
local BIG_SERIAL_LINE = 198
local BIG_SERIAL_SIZE = 58
local MONOGRAM_CENTRE = Vector2.new(58, 85)
local CROSSHAIR = Vector2.new(130, 42)
local CROSSHAIR_FILL = 6.4 -- radius, inside the baked ring
local RING_THICKNESS = 1.2
local OUTLINE_THICKNESS = 2

local BLOCK_BOTTOM = 86 -- the back's coloured block
local BACK_ICON = Vector2.new(24, 24)
local BACK_ICON_ARM = 10
local BACK_LINE_THICKNESS = 1.2
local BACK_COPIES_LINE = 19
local BACK_NAME_LINE = 64
local BACK_NAME_SIZE = 13
local BACK_RARITY_LINE = 78
local MAIN_LABEL_LINE = 106
local MAIN_VALUE_LINE = 140
local MAIN_VALUE_SIZE = 34
local SMALL_LABEL_LINE = 156
local SMALL_VALUE_LINE = 178
local SMALL_VALUE_SIZE = 22
local SMALL_SECOND_LEFT = 80
local UNIT_GAP = 3
local BLURB_SIZE = 9
local BLURB_BOTTOM = 208
local BLURB_STEP = 11
local BLURB_WIDTH = 22 -- letters
local BACK_STRIPES_TOP = 214
local BACK_STRIPES_HEIGHT = 12

local SET_CODES = { set_01 = "S01" }
local GHOST_TRANSPARENCY = 0.75
local SHINE_ROTATION = 20 -- degrees, so the band leans as it crosses the card
local SHINE_HALF_WIDTH = 0.07 -- of the gradient
local FOIL_HALF_WIDTH = 0.25
local FOIL_STRENGTH = 0.55
local FOIL_BLUE = Color3.fromRGB(10, 34, 245)
local SHINE_LAYER = 5

local LOOKS = {
	Field = { back = Palette.DeepNavy, ink = Palette.Bone, rarity = Palette.Bone, stripes = Palette.Bone, shine = 0.28 },
	Redline = {
		back = Palette.Bone,
		ink = Palette.DeepNavy,
		rarity = Palette.HazardRed,
		stripes = Palette.HazardRed,
		outline = Palette.HazardRed,
		shine = 0.7,
	},
	Prototype = {
		back = Palette.SignalAcid,
		ink = Palette.DeepNavy,
		rarity = Palette.DeepNavy,
		stripes = Palette.DeepNavy,
		outline = Palette.DeepNavy,
		shine = 0.5,
	},
	ZeroDay = {
		back = Palette.ZeroDayBack,
		ink = Palette.Bone,
		rarity = Palette.DataCyan,
		outline = Palette.DataCyan,
		shine = 0.6,
	},
}

export type Options = {
	cardId: string,
	tier: string,
	variant: string,
	width: number, -- pixels
	position: UDim2?,
	serial: number?,
	corner: string?, -- shown where the small serial goes
	ghost: boolean?, -- an unowned card: faded and still
	shineAt: (() -> number?)?, -- where to hold the shine, or nil for its timed sweep
}

-- Every moving face, walked by one connection that only exists while there are any.
local live: { any } = {}
local stepping: RBXScriptConnection? = nil

local function isShown(gui: Instance): boolean
	local current: Instance? = gui
	while current do
		if current:IsA("GuiObject") and not current.Visible then
			return false
		elseif current:IsA("LayerCollector") then
			return current.Enabled
		end
		current = current.Parent
	end
	return false
end

local function step()
	local now = os.clock()
	for _, face in live do
		if isShown(face.root) then
			face.update(now - face.started)
		end
	end
end

local function stopAnimating(face: any)
	table.remove(live, table.find(live, face))
	if #live == 0 and stepping then
		stepping:Disconnect()
		stepping = nil
	end
end

local function animate(root: GuiObject, update: (number) -> ())
	local face = { root = root, started = os.clock(), update = update }
	table.insert(live, face)
	root.Destroying:Once(function()
		stopAnimating(face)
	end)
	if not stepping then
		stepping = RunService.RenderStepped:Connect(step)
	end
end

local function rounded(gui: GuiObject, radius: UDim)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = radius
	corner.Parent = gui
end

local function text(root: GuiObject, unit: number, style: string, size: number, color: Color3, x: number, y: number, right: boolean?): any
	return TypeLabel.new(root, {
		style = style,
		size = size * unit,
		tracking = size * TRACKING * unit,
		color = color,
		right = right,
		shadow = false,
		position = UDim2.fromOffset(x * unit, y * unit),
	})
end

-- A card-sized frame showing only a slanted band. Moving the gradient's offset moves the band.
local function band(root: GuiObject, unit: number, halfWidth: number, color: ColorSequence, strength: number): UIGradient
	local frame = Instance.new("Frame")
	frame.BackgroundColor3 = Color3.new(1, 1, 1)
	frame.BorderSizePixel = 0
	frame.Size = UDim2.fromScale(1, 1)
	frame.ZIndex = SHINE_LAYER
	frame.Parent = root
	rounded(frame, UDim.new(0, CORNER * unit))
	local gradient = Instance.new("UIGradient")
	gradient.Rotation = SHINE_ROTATION
	gradient.Color = color
	gradient.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.5 - halfWidth, 1),
		NumberSequenceKeypoint.new(0.5, 1 - strength),
		NumberSequenceKeypoint.new(0.5 + halfWidth, 1),
		NumberSequenceKeypoint.new(1, 1),
	})
	gradient.Offset = Vector2.new(-1, 0)
	gradient.Parent = frame
	return gradient
end

local function stripes(root: GuiObject, unit: number, color: Color3, area: Rect): ImageLabel
	local block = Instance.new("Frame")
	block.BackgroundTransparency = 1
	block.Position = UDim2.fromOffset(area.Min.X * unit, area.Min.Y * unit)
	block.Size = UDim2.fromOffset(area.Width * unit, area.Height * unit)
	block.ClipsDescendants = true
	block.Parent = root
	local image = Instance.new("ImageLabel")
	image.BackgroundTransparency = 1
	image.Image = CardArt.STRIPES
	image.ImageColor3 = color
	image.ScaleType = Enum.ScaleType.Tile
	image.TileSize = UDim2.fromOffset(STRIPE_TILE * unit, STRIPE_TILE * unit)
	image.Size = UDim2.new(1, STRIPE_TILE * unit, 1, 0)
	image.Parent = block
	return image
end

-- Drawn just inside the card's edge, because a ghosted card clips whatever falls outside it.
local function outline(root: GuiObject, unit: number, color: Color3)
	local thickness = OUTLINE_THICKNESS * unit
	local frame = Instance.new("Frame")
	frame.BackgroundTransparency = 1
	frame.Position = UDim2.fromOffset(thickness, thickness)
	frame.Size = UDim2.new(1, -thickness * 2, 1, -thickness * 2)
	frame.Parent = root
	rounded(frame, UDim.new(0, (CORNER - OUTLINE_THICKNESS) * unit))
	local stroke = Instance.new("UIStroke")
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Color = color
	stroke.Thickness = thickness
	stroke.Parent = frame
end

local function crosshairFill(root: GuiObject, unit: number)
	local fill = Instance.new("Frame")
	fill.BackgroundColor3 = Palette.DataCyan
	fill.BorderSizePixel = 0
	fill.AnchorPoint = Vector2.new(0.5, 0.5)
	fill.Position = UDim2.fromOffset(CROSSHAIR.X * unit, CROSSHAIR.Y * unit)
	fill.Size = UDim2.fromOffset(CROSSHAIR_FILL * 2 * unit, CROSSHAIR_FILL * 2 * unit)
	fill.Parent = root
	rounded(fill, UDim.new(0.5, 0))
end

-- The monogram's outline swelling out of it and fading. Prototype only.
local function pulse(root: GuiObject, unit: number, cardId: string, color: Color3): (number) -> ()
	local outline = Instance.new("ImageLabel")
	outline.BackgroundTransparency = 1
	outline.Image = CardArt.outline(cardId) or ""
	outline.ImageColor3 = color
	outline.AnchorPoint = Vector2.new(MONOGRAM_CENTRE.X / WIDTH, MONOGRAM_CENTRE.Y / HEIGHT)
	outline.Position = UDim2.fromOffset(MONOGRAM_CENTRE.X * unit, MONOGRAM_CENTRE.Y * unit)
	outline.Parent = root
	return function(elapsed: number)
		local scale, transparency = CardMotion.pulse(elapsed)
		outline.Size = UDim2.fromOffset(WIDTH * unit * scale, HEIGHT * unit * scale)
		outline.ImageTransparency = transparency
	end
end

-- A ring spreading from the crosshair. Zero-Day only.
local function ping(root: GuiObject, unit: number): (number) -> ()
	local ring = Instance.new("Frame")
	ring.BackgroundTransparency = 1
	ring.AnchorPoint = Vector2.new(0.5, 0.5)
	ring.Position = UDim2.fromOffset(CROSSHAIR.X * unit, CROSSHAIR.Y * unit)
	ring.Parent = root
	rounded(ring, UDim.new(0.5, 0))
	local stroke = Instance.new("UIStroke")
	stroke.Color = Palette.DataCyan
	stroke.Thickness = RING_THICKNESS * unit
	stroke.Parent = ring
	return function(elapsed: number)
		local radius, transparency = CardMotion.ping(elapsed)
		ring.Size = UDim2.fromOffset(radius * 2 * unit, radius * 2 * unit)
		stroke.Transparency = transparency
	end
end

local function scrolling(image: ImageLabel, unit: number): (number) -> ()
	return function(elapsed: number)
		image.Position = UDim2.fromOffset(-STRIPE_TILE * unit * ((elapsed % STRIPE_TIME) / STRIPE_TIME), 0)
	end
end

local function scrambling(label: any, serial: string): (number) -> ()
	local shown = serial
	return function(elapsed: number)
		local value = CardMotion.scramble(serial, elapsed)
		if value ~= shown then
			shown = value
			label:set(value)
		end
	end
end

local CardFace = {}

function CardFace.new(parent: Instance, options: Options): GuiObject
	local card = Cards.byId[options.cardId]
	local look = CardLook.look(options.tier, options.variant)
	local style = LOOKS[look]
	local unit = options.width / WIDTH
	local serial = CardLook.serialText(options.serial)

	-- A CanvasGroup fades the image and text together.
	local root: any = Instance.new(if options.ghost then "CanvasGroup" else "Frame")
	root.Name = "CardFace"
	root.BackgroundColor3 = style.back
	root.BorderSizePixel = 0
	root.Size = UDim2.fromOffset(options.width, HEIGHT * unit)
	root.Position = options.position or UDim2.new()
	rounded(root, UDim.new(0, CORNER * unit))

	local art = Instance.new("ImageLabel")
	art.BackgroundTransparency = 1
	art.Size = UDim2.fromScale(1, 1)
	art.Image = CardArt.base(options.cardId, look) or ""
	art.Parent = root
	if style.outline then
		outline(root, unit, style.outline)
	end

	local stripesImage: ImageLabel? = nil
	local bigSerial: any = nil
	if look == "ZeroDay" then
		crosshairFill(root, unit)
		local size = BIG_SERIAL_SIZE * CardLook.bigSerialSize(serial)
		bigSerial = text(root, unit, "LabelBold", size, style.ink, BLOCK_LEFT, BIG_SERIAL_LINE)
		bigSerial:set(serial)
	else
		local area = Rect.new(BLOCK_LEFT, BLOCK_TOP, BLOCK_LEFT + BLOCK_WIDTH, BLOCK_TOP + BLOCK_HEIGHT)
		stripesImage = stripes(root, unit, style.stripes, area)
	end

	local corner = options.corner or if look == "ZeroDay" then nil else serial
	if corner then
		text(root, unit, "Label", SERIAL_SIZE, style.ink, RIGHT, SERIAL_LINE, true):set(corner)
	end
	text(root, unit, "LabelBold", TEXT_SIZE, style.ink, LEFT, NAME_LINE):set(string.upper(card.name))
	text(root, unit, "Label", TEXT_SIZE, style.rarity, LEFT, RARITY_LINE):set(CardLook.rarityText(options.tier, options.variant))
	if CardLook.showsSetCode(options.tier, options.variant) then
		text(root, unit, "Label", TEXT_SIZE, style.ink, RIGHT, RARITY_LINE, true):set(SET_CODES[card.set] or "")
	end

	root.Parent = parent
	if options.ghost then
		root.GroupTransparency = GHOST_TRANSPARENCY
		return root
	end

	local shine = band(root, unit, SHINE_HALF_WIDTH, ColorSequence.new(Color3.new(1, 1, 1)), style.shine)
	local foil: UIGradient? = nil
	local parts: { (number) -> () } = {}
	if look == "Prototype" then
		table.insert(parts, pulse(root, unit, options.cardId, style.ink))
		table.insert(parts, scrolling(stripesImage :: ImageLabel, unit))
	elseif look == "ZeroDay" then
		foil = band(
			root,
			unit,
			FOIL_HALF_WIDTH,
			ColorSequence.new({
				ColorSequenceKeypoint.new(0, Palette.DataCyan),
				ColorSequenceKeypoint.new(0.5, FOIL_BLUE),
				ColorSequenceKeypoint.new(1, Palette.DataCyan),
			}),
			FOIL_STRENGTH
		)
		table.insert(parts, ping(root, unit))
		table.insert(parts, scrambling(bigSerial, serial))
	end

	animate(root, function(elapsed: number)
		local held = options.shineAt and options.shineAt()
		local offset = Vector2.new(held or CardMotion.shineOffset(elapsed), 0)
		shine.Offset = offset
		if foil then
			foil.Offset = offset
		end
		for _, part in parts do
			part(elapsed)
		end
	end)
	return root
end

-- The back's top: a block of the rarity's colour, square along its bottom edge.
local function backBlock(root: GuiObject, unit: number, color: Color3)
	local top = Instance.new("Frame")
	top.BackgroundColor3 = color
	top.BorderSizePixel = 0
	top.Size = UDim2.fromOffset(WIDTH * unit, (CORNER * 2) * unit)
	top.Parent = root
	rounded(top, UDim.new(0, CORNER * unit))
	local square = Instance.new("Frame")
	square.BackgroundColor3 = color
	square.BorderSizePixel = 0
	square.Position = UDim2.fromOffset(0, CORNER * unit)
	square.Size = UDim2.fromOffset(WIDTH * unit, (BLOCK_BOTTOM - CORNER) * unit)
	square.Parent = root
end

local function backIcon(root: GuiObject, unit: number, color: Color3)
	local thickness = BACK_LINE_THICKNESS * unit
	local function centred(size: Vector2): Frame
		local frame = Instance.new("Frame")
		frame.BackgroundColor3 = color
		frame.BorderSizePixel = 0
		frame.AnchorPoint = Vector2.new(0.5, 0.5)
		frame.Position = UDim2.fromOffset(BACK_ICON.X * unit, BACK_ICON.Y * unit)
		frame.Size = UDim2.fromOffset(size.X, size.Y)
		frame.Parent = root
		return frame
	end
	centred(Vector2.new(thickness, BACK_ICON_ARM * 2 * unit))
	centred(Vector2.new(BACK_ICON_ARM * 2 * unit, thickness))
	local ring = centred(Vector2.new(CROSSHAIR_FILL * 2 * unit, CROSSHAIR_FILL * 2 * unit))
	ring.BackgroundTransparency = 1
	rounded(ring, UDim.new(0.5, 0))
	local stroke = Instance.new("UIStroke")
	stroke.Color = color
	stroke.Thickness = thickness
	stroke.Parent = ring
end

-- A stat's label with its value below, and the value's unit small beside it.
local function backStat(root: GuiObject, unit: number, ink: Color3, stat: any, left: number, labelLine: number, valueLine: number, size: number)
	text(root, unit, "Label", TEXT_SIZE, ink, left, labelLine):set(stat.label)
	local parts = string.split(stat.value, " ")
	local value = text(root, unit, "LabelBold", size, ink, left, valueLine)
	value:set(parts[1])
	local after = left + value:width() / unit + UNIT_GAP
	text(root, unit, "Label", TEXT_SIZE, ink, after, valueLine):set(parts[2] or "")
end

-- The card's reverse, drawn the same size as its face.
function CardFace.back(parent: Instance, options: Options, count: number): GuiObject
	local card = Cards.byId[options.cardId]
	local style = LOOKS[CardLook.look(options.tier, options.variant)]
	local unit = options.width / WIDTH
	local root = Instance.new("Frame")
	root.Name = "CardBack"
	root.BackgroundColor3 = style.back
	root.BorderSizePixel = 0
	root.Size = UDim2.fromOffset(options.width, HEIGHT * unit)
	rounded(root, UDim.new(0, CORNER * unit))

	backBlock(root, unit, style.rarity)
	backIcon(root, unit, style.back)
	text(root, unit, "Label", TEXT_SIZE, style.back, RIGHT, BACK_COPIES_LINE, true):set(CardText.copies(count))
	text(root, unit, "LabelBold", BACK_NAME_SIZE, style.back, LEFT, BACK_NAME_LINE):set(string.upper(card.name))
	text(root, unit, "Label", TEXT_SIZE, style.back, LEFT, BACK_RARITY_LINE)
		:set(CardLook.rarityText(options.tier, options.variant))
	if CardLook.showsSetCode(options.tier, options.variant) then
		text(root, unit, "Label", TEXT_SIZE, style.back, RIGHT, BACK_RARITY_LINE, true):set(SET_CODES[card.set] or "")
	end

	local stats = CardText.stats(options.cardId, options.tier)
	backStat(root, unit, style.ink, stats[1], LEFT, MAIN_LABEL_LINE, MAIN_VALUE_LINE, MAIN_VALUE_SIZE)
	for index = 2, #stats do
		local left = if index == 2 then LEFT else SMALL_SECOND_LEFT
		backStat(root, unit, style.ink, stats[index], left, SMALL_LABEL_LINE, SMALL_VALUE_LINE, SMALL_VALUE_SIZE)
	end

	local lines = CardText.wrap(CardText.blurb(options.cardId), BLURB_WIDTH)
	for index, line in lines do
		text(root, unit, "Label", BLURB_SIZE, style.ink, LEFT, BLURB_BOTTOM - (#lines - index) * BLURB_STEP):set(line)
	end
	stripes(root, unit, style.ink, Rect.new(LEFT, BACK_STRIPES_TOP, RIGHT, BACK_STRIPES_TOP + BACK_STRIPES_HEIGHT))
	if style.outline then
		outline(root, unit, style.outline)
	end
	root.Parent = parent
	return root
end

return CardFace
