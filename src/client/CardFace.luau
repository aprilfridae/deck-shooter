-- A card in the menus. The front is baked layers tinted and moved here, with live text for the rarity and serial
-- (docs/specs/card-face-redesign.md). The back is drawn whole.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local CardCore = ReplicatedStorage:WaitForChild("CardCore")
local CardArt = require(CardCore:WaitForChild("CardArt"))
local CardLayout = require(CardCore:WaitForChild("CardLayout"))
local CardLook = require(CardCore:WaitForChild("CardLook"))
local Cards = require(CardCore:WaitForChild("Cards"))
local CardText = require(CardCore:WaitForChild("CardText"))
local Guns = ReplicatedStorage:WaitForChild("Guns")
local CardMotion = require(Guns:WaitForChild("Hud"):WaitForChild("CardMotion"))
local Palette = require(Guns:WaitForChild("Palette"))
local CardEffects = require(script.Parent.CardEffects)
local TypeLabel = require(script.Parent.TypeLabel)

-- The back is in its own units: a card is 150 wide and 240 tall.
local WIDTH = 150
local HEIGHT = 240
local CORNER = 10
local LEFT = 10
local RIGHT = 140
local TEXT_SIZE = 11
local TRACKING = 0.04 -- of the size
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
local BLURB_SIZE = 6.5
local BLURB_BOTTOM = 208
local BLURB_STEP = 8.5
local BLURB_WIDTH = 30 -- letters
local BACK_STRIPES_TOP = 214
local BACK_STRIPES_HEIGHT = 12

local SET_CODES = { set_01 = "S01" }
local GHOST_TRANSPARENCY = 0.75
local SHINE_HALF_WIDTH = 0.07 -- of the gradient
local WHOLE = { x = 0, y = 0, w = CardLayout.WIDTH, h = CardLayout.HEIGHT }

-- `mark` colours the acronym and serial on the front. `rarity` and `outline` are the back's.
local LOOKS = {
	Field = { back = Palette.DeepNavy, ink = Palette.Bone, mark = Palette.Bone, rarity = Palette.Bone, shine = 0.28 },
	Redline = {
		back = Palette.Bone,
		ink = Palette.DeepNavy,
		mark = Palette.HazardRed,
		rarity = Palette.HazardRed,
		outline = Palette.HazardRed,
		shine = 0.7,
	},
	Prototype = {
		back = Palette.SignalAcid,
		ink = Palette.DeepNavy,
		mark = Palette.DeepNavy,
		rarity = Palette.DeepNavy,
		outline = Palette.DeepNavy,
		shine = 0.5,
	},
	ZeroDay = {
		back = Palette.ZeroDayBack,
		ink = Palette.Bone,
		mark = Palette.DataCyan,
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
	corner: string?, -- shown in place of the serial
	ghost: boolean?, -- an unowned card: faded and still
	shineAt: (() -> number?)?, -- where to hold the shine, or nil for its timed sweep
}

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

-- Drawn just inside the card's edge, because a ghosted card clips whatever falls outside it.
local function outline(root: GuiObject, unit: number, color: Color3)
	local thickness = OUTLINE_THICKNESS * unit
	local frame = Instance.new("Frame")
	frame.BackgroundTransparency = 1
	frame.Position = UDim2.fromOffset(thickness, thickness)
	frame.Size = UDim2.new(1, -thickness * 2, 1, -thickness * 2)
	frame.Parent = root
	CardEffects.rounded(frame, UDim.new(0, (CORNER - OUTLINE_THICKNESS) * unit))
	local stroke = Instance.new("UIStroke")
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Color = color
	stroke.Thickness = thickness
	stroke.Parent = frame
end

-- The front is drawn in the units of River's drawing (CardLayout), `face` pixels to each. The back keeps its own.
local function placed(root: GuiObject, face: number, image: string?, rect: any, color: Color3): ImageLabel
	local label = Instance.new("ImageLabel")
	label.BackgroundTransparency = 1
	label.Image = image or "" -- a card with no art yet still draws
	label.ImageColor3 = color
	label.Position = UDim2.fromOffset(rect.x * face, rect.y * face)
	label.Size = UDim2.fromOffset(rect.w * face, rect.h * face)
	label.Parent = root
	return label
end

-- Held by its middle, so it can grow and shrink in place.
local function centred(root: GuiObject, face: number, image: string?, rect: any, color: Color3): ImageLabel
	local label = placed(root, face, image, rect, color)
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Position = UDim2.fromOffset((rect.x + rect.w / 2) * face, (rect.y + rect.h / 2) * face)
	return label
end

local function faceText(root: GuiObject, face: number, style: string, size: number, tracking: number, color: Color3, x: number, line: number, right: boolean?): any
	return TypeLabel.new(root, {
		style = style,
		size = size * face,
		tracking = size * tracking * face,
		color = color,
		right = right,
		shadow = false,
		position = UDim2.fromOffset(x * face, line * face),
	})
end

local CardFace = {}

function CardFace.new(parent: Instance, options: Options): GuiObject
	local look = CardLook.look(options.tier, options.variant)
	local style = LOOKS[look]
	local face = options.width / CardLayout.WIDTH
	-- Real serials aren't built yet, so Studio shows stand-ins (see CardLook.studioSerial).
	local serial = options.serial or if RunService:IsStudio() then CardLook.studioSerial(options.cardId) else nil
	-- The index shows a copy count where the serial goes, and that is never a low serial.
	local low = options.corner == nil and CardLook.isLowSerial(serial)

	-- A CanvasGroup fades the image and text together.
	local root: any = Instance.new(if options.ghost then "CanvasGroup" else "Frame")
	root.Name = "CardFace"
	root.BackgroundColor3 = style.back
	root.BorderSizePixel = 0
	root.Size = UDim2.fromOffset(options.width, CardLayout.HEIGHT * face)
	root.Position = options.position or UDim2.new()
	CardEffects.rounded(root, UDim.new(0, CardLayout.CORNER * face))

	placed(root, face, CardArt.layer("still"), WHOLE, style.ink)
	placed(root, face, CardArt.layer("rays"), CardLayout.RAYS, style.ink)
	local dot = Instance.new("Frame")
	dot.BackgroundColor3 = style.ink
	dot.BorderSizePixel = 0
	dot.AnchorPoint = Vector2.new(0.5, 0.5)
	dot.Position = UDim2.fromOffset(CardLayout.BURST_DOT.x * face, CardLayout.BURST_DOT.y * face)
	dot.Size = UDim2.fromOffset(CardLayout.BURST_DOT.r * 2 * face, CardLayout.BURST_DOT.r * 2 * face)
	dot.Parent = root
	CardEffects.rounded(dot, UDim.new(0.5, 0))
	centred(root, face, CardArt.layer("star_big"), CardLayout.STAR_BIG, style.ink)
	centred(root, face, CardArt.layer("star_small"), CardLayout.STAR_SMALL, style.ink)
	placed(root, face, CardArt.monogram(options.cardId), CardLayout.MONOGRAM, style.mark)

	local name = CardArt.name(options.cardId)
	if name then
		placed(root, face, name, CardLayout.NAME, style.ink)
	else
		-- A card whose name hasn't been baked yet: the bold sheet stands in for the medium weight.
		local card = Cards.byId[options.cardId]
		faceText(root, face, "LabelBold", CardLayout.SERIAL.size, 0, style.ink, CardLayout.NAME.x, CardLayout.SERIAL.line)
			:set(CardLook.faceName(if card then card.name else options.cardId))
	end
	local rarity = CardLayout.RARITY
	faceText(root, face, "Label", rarity.size, rarity.tracking, style.ink, rarity.x, rarity.line)
		:set(CardLook.faceRarity(options.tier, options.variant))

	if low then
		placed(root, face, CardArt.lowSerial(serial :: number), CardLayout.LOW_SERIAL, style.mark)
	else
		placed(root, face, CardArt.layer("barcode"), CardLayout.BARCODE, style.ink)
		local place = CardLayout.SERIAL
		faceText(root, face, "LabelLarge", place.size, 0, style.mark, place.right, place.line, true)
			:set(options.corner or CardLook.faceSerial(serial))
	end

	root.Parent = parent
	if options.ghost then
		root.GroupTransparency = GHOST_TRANSPARENCY
		return root
	end

	local shine = CardEffects.band(root, CardLayout.CORNER * face, SHINE_HALF_WIDTH, ColorSequence.new(Color3.new(1, 1, 1)), style.shine)
	CardEffects.animate(root, function(elapsed: number)
		local held = options.shineAt and options.shineAt()
		shine.Offset = Vector2.new(held or CardMotion.shineOffset(elapsed), 0)
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
	CardEffects.rounded(top, UDim.new(0, CORNER * unit))
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
	CardEffects.rounded(ring, UDim.new(0.5, 0))
	local stroke = Instance.new("UIStroke")
	stroke.Color = color
	stroke.Thickness = thickness
	stroke.Parent = ring
end

-- A stat's label with its value below, and the value's unit small beside it.
local function backStat(root: GuiObject, unit: number, ink: Color3, stat: any, left: number, labelLine: number, valueLine: number, size: number)
	text(root, unit, "Label", TEXT_SIZE, ink, left, labelLine):set(stat.label)
	local parts = string.split(stat.value, " ")
	local value = text(root, unit, "LabelLarge", size, ink, left, valueLine)
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
	CardEffects.rounded(root, UDim.new(0, CORNER * unit))

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
	if stats[1] then
		backStat(root, unit, style.ink, stats[1], LEFT, MAIN_LABEL_LINE, MAIN_VALUE_LINE, MAIN_VALUE_SIZE)
	end
	for index = 2, #stats do
		local left = if index == 2 then LEFT else SMALL_SECOND_LEFT
		backStat(root, unit, style.ink, stats[index], left, SMALL_LABEL_LINE, SMALL_VALUE_LINE, SMALL_VALUE_SIZE)
	end

	local lines = CardText.wrap(CardText.blurb(options.cardId), BLURB_WIDTH)
	for index, line in lines do
		text(root, unit, "Label", BLURB_SIZE, style.ink, LEFT, BLURB_BOTTOM - (#lines - index) * BLURB_STEP):set(line)
	end
	CardEffects.stripes(root, unit, style.ink, Rect.new(LEFT, BACK_STRIPES_TOP, RIGHT, BACK_STRIPES_TOP + BACK_STRIPES_HEIGHT))
	if style.outline then
		outline(root, unit, style.outline)
	end
	root.Parent = parent
	return root
end

return CardFace
