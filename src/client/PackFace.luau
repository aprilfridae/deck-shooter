-- A pack in the menus: its baked wrapper with the name, stripes, shine and effects live on top.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CardCore = ReplicatedStorage:WaitForChild("CardCore")
local PackArt = require(CardCore:WaitForChild("PackArt"))
local PackText = require(CardCore:WaitForChild("PackText"))
local Guns = ReplicatedStorage:WaitForChild("Guns")
local CardMotion = require(Guns:WaitForChild("Hud"):WaitForChild("CardMotion"))
local Palette = require(Guns:WaitForChild("Palette"))
local CardEffects = require(script.Parent.CardEffects)
local TypeLabel = require(script.Parent.TypeLabel)

-- In wrapper units: a pack is 150 wide and 230 tall.
local WIDTH = 150
local HEIGHT = 230
local CRIMP = 14 -- the pressed ends, which the shine stays out of
local STRIPE_AREA = Rect.new(14, 168, 136, 186)
local NAME_SIZE = 13
local NAME_LEFT = 14
local NAME_LINE = 204
local TRACKING = 0.04 -- of the size
local PING_FROM = Vector2.new(126, 42)
local EDGE_THICKNESS = 3
local EDGE_SPEED = 3 -- radians a second
local SHINE_HALF_WIDTH = 0.07 -- of the gradient
local FOIL_HALF_WIDTH = 0.25
local FOIL_STRENGTH = 0.55
local FOIL_BLUE = Color3.fromRGB(10, 34, 245)

local LOOKS = {
	Field = { ink = Palette.Bone, stripes = Palette.Bone, shine = 0.28 },
	BlackSite = { ink = Palette.DeepNavy, stripes = Palette.HazardRed, shine = 0.7 },
	Prototype = { ink = Palette.DeepNavy, stripes = Palette.DeepNavy, shine = 0.5 },
	ZeroDay = { ink = Palette.Bone, stripes = Palette.DataCyan, shine = 0.6 },
}

export type Options = {
	pack: string,
	width: number, -- pixels
	position: UDim2?,
}

local PackFace = {
	WIDTH = WIDTH,
	HEIGHT = HEIGHT,
}

-- A red line round the wrapper that swells and fades.
local function pulsingEdge(body: GuiObject, unit: number): (number) -> ()
	local stroke = Instance.new("UIStroke")
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Color = Palette.HazardRed
	stroke.Thickness = EDGE_THICKNESS * unit
	stroke.Parent = body
	return function(elapsed: number)
		stroke.Transparency = 0.5 + 0.5 * math.sin(elapsed * EDGE_SPEED)
	end
end

function PackFace.new(parent: Instance, options: Options): GuiObject
	local look = LOOKS[options.pack]
	local unit = options.width / WIDTH

	local root = Instance.new("Frame")
	root.Name = "PackFace"
	root.BackgroundTransparency = 1
	root.Size = UDim2.fromOffset(options.width, HEIGHT * unit)
	root.Position = options.position or UDim2.new()

	local art = Instance.new("ImageLabel")
	art.BackgroundTransparency = 1
	art.Size = UDim2.fromScale(1, 1)
	art.Image = PackArt.image(options.pack) or ""
	art.Parent = root

	local stripes = CardEffects.stripes(root, unit, look.stripes, STRIPE_AREA)
	local name = TypeLabel.new(root, {
		style = "LabelBold",
		size = NAME_SIZE * unit,
		tracking = NAME_SIZE * TRACKING * unit,
		color = look.ink,
		shadow = false,
		position = UDim2.fromOffset(NAME_LEFT * unit, NAME_LINE * unit),
	})
	name:set(PackText.name(options.pack))

	local body = Instance.new("Frame")
	body.BackgroundTransparency = 1
	body.Position = UDim2.fromOffset(0, CRIMP * unit)
	body.Size = UDim2.new(1, 0, 1, -2 * CRIMP * unit)
	body.Parent = root

	root.Parent = parent

	local shine = CardEffects.band(body, 0, SHINE_HALF_WIDTH, ColorSequence.new(Color3.new(1, 1, 1)), look.shine)
	local foil: UIGradient? = nil
	local parts: { (number) -> () } = {}
	if options.pack == "BlackSite" then
		table.insert(parts, pulsingEdge(body, unit))
	elseif options.pack == "Prototype" then
		table.insert(parts, CardEffects.scrolling(stripes, unit))
	elseif options.pack == "ZeroDay" then
		foil = CardEffects.band(
			body,
			0,
			FOIL_HALF_WIDTH,
			ColorSequence.new({
				ColorSequenceKeypoint.new(0, Palette.DataCyan),
				ColorSequenceKeypoint.new(0.5, FOIL_BLUE),
				ColorSequenceKeypoint.new(1, Palette.DataCyan),
			}),
			FOIL_STRENGTH
		)
		table.insert(parts, CardEffects.ping(root, unit, PING_FROM))
	end

	CardEffects.animate(root, function(elapsed: number)
		local offset = Vector2.new(CardMotion.shineOffset(elapsed), 0)
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

return PackFace
