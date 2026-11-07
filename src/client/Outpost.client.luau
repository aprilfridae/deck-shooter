-- The Outpost on this screen: its fog and colour while you're there, and the text on its
-- signs and screens. The server builds the place itself.
local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Guns = ReplicatedStorage:WaitForChild("Guns")
local Hud = Guns:WaitForChild("Hud")
local GlyphData = require(Hud:WaitForChild("GlyphData"))
local Palette = require(Guns:WaitForChild("Palette"))
local TypeLayout = require(Hud:WaitForChild("TypeLayout"))
local Zones = require(Guns:WaitForChild("Zones"))
local TypeLabel = require(script.Parent.TypeLabel)

local SIGN_TAG = "OutpostSign"
local SCREEN_TAG = "OutpostScreen"
local PIXELS_PER_STUD = 40
local GLOW = 2 -- signs and screens ignore the scene's light, and this bright they bloom a little
local TEXT_SHARE = 0.55 -- of the sign's height
local FIT_SHARE = 0.88 -- of the sign's width, at most
local TRACKING_SHARE = 0.08 -- of the text size
local VERTICAL_WIDTH = 0.62
local VERTICAL_FILL = 0.86

-- While you're in the Outpost. The test room keeps the place's own lighting.
local OUTPOST_LIGHTING = {
	Ambient = Color3.fromRGB(38, 46, 50),
	OutdoorAmbient = Color3.fromRGB(96, 110, 112),
	Brightness = 1.4,
	ClockTime = 8,
	EnvironmentDiffuseScale = 0.45,
	EnvironmentSpecularScale = 1,
	ExposureCompensation = -0.1,
	GlobalShadows = true,
	ShadowSoftness = 0.4,
}
-- Effects the Outpost replaces while you're there.
local REPLACED = {
	Atmosphere = true,
	Sky = true,
	BloomEffect = true,
	BlurEffect = true,
	ColorCorrectionEffect = true,
	DepthOfFieldEffect = true,
	SunRaysEffect = true,
}

local player = Players.LocalPlayer

local function effect(className: string, props: { [string]: any }): Instance
	local instance = Instance.new(className)
	for key, value in props do
		(instance :: any)[key] = value
	end
	return instance
end

local effects = {
	effect("Atmosphere", {
		Density = 0.44,
		Offset = 0.12,
		Color = Color3.fromRGB(148, 170, 170),
		Decay = Color3.fromRGB(88, 106, 110),
		Glare = 0,
		Haze = 2.6,
	}),
	effect("Sky", { CelestialBodiesShown = false, StarCount = 0 }),
	effect("ColorCorrectionEffect", {
		Saturation = -0.2,
		Contrast = 0.1,
		Brightness = -0.02,
		TintColor = Color3.fromRGB(226, 240, 238),
	}),
	effect("BloomEffect", { Intensity = 0.9, Size = 28, Threshold = 1.3 }),
}

local original: { [string]: any } = {}
for name in OUTPOST_LIGHTING do
	original[name] = (Lighting :: any)[name]
end
local replaced: { Instance } = {}
for _, child in Lighting:GetChildren() do
	if REPLACED[child.ClassName] then
		table.insert(replaced, child)
	end
end

local shownZone: string? = nil
local function applyZone()
	local zone = Zones.of(player)
	if zone == shownZone then
		return
	end
	shownZone = zone
	local here = zone == Zones.Outpost
	for name, value in OUTPOST_LIGHTING do
		(Lighting :: any)[name] = if here then value else original[name]
	end
	for _, instance in effects do
		instance.Parent = if here then Lighting else nil
	end
	for _, instance in replaced do
		instance.Parent = if here then nil else Lighting
	end
end
player:GetAttributeChangedSignal("Zone"):Connect(applyZone)
applyZone()

-- Text on parts, drawn with the HUD's fonts.
local function capShare(style: string): number
	local font = GlyphData[style]
	local glyph = font.glyphs["0"] or font.glyphs["A"]
	return -glyph.oy / font.source
end

local function textLayer(part: BasePart, name: string, fill: Color3?): (Frame, number, number)
	local gui = Instance.new("SurfaceGui")
	gui.Name = name
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = PIXELS_PER_STUD
	gui.LightInfluence = 0
	gui.Brightness = GLOW
	gui.ClipsDescendants = true
	gui.Parent = part
	local frame = Instance.new("Frame")
	frame.Size = UDim2.fromScale(1, 1)
	frame.BorderSizePixel = 0
	frame.BackgroundTransparency = if fill then 0 else 1
	frame.BackgroundColor3 = fill or Color3.new()
	frame.Parent = gui
	return frame, part.Size.X * PIXELS_PER_STUD, part.Size.Y * PIXELS_PER_STUD
end

-- Text centred on (x, y), shrunk if it would be wider than fit.
local function centred(frame: Frame, style: string, text: string, color: Color3, size: number, x: number, y: number, fit: number): any
	local width = TypeLayout.lay(text, style, size, size * TRACKING_SHARE)
	if width > fit then
		size *= fit / width
		width = fit
	end
	local label = TypeLabel.new(frame, {
		style = style,
		size = size,
		tracking = size * TRACKING_SHARE,
		color = color,
		position = UDim2.fromOffset(math.round(x - width / 2), math.round(y + size * capShare(style) / 2)),
	})
	label:set(text)
	return label
end

-- Text that starts at x, its baseline at y.
local function line(frame: Frame, style: string, text: string, color: Color3, size: number, x: number, y: number): any
	local label = TypeLabel.new(frame, {
		style = style,
		size = size,
		tracking = size * TRACKING_SHARE,
		color = color,
		position = UDim2.fromOffset(math.round(x), math.round(y)),
	})
	label:set(text)
	return label
end

local function decorateSign(part: Instance)
	if not part:IsA("BasePart") or part:FindFirstChild("SignText") then
		return
	end
	local text = part:GetAttribute("SignText")
	if type(text) ~= "string" then
		return
	end
	local style = part:GetAttribute("SignStyle") or "LabelBold"
	local color = part:GetAttribute("SignColor") or Palette.Bone
	local fill = part:GetAttribute("SignFill")
	local frame, width, height = textLayer(part, "SignText", if typeof(fill) == "Color3" then fill else nil)
	if part:GetAttribute("SignVertical") then
		local count = #text
		local size = math.min(width * VERTICAL_WIDTH, height * VERTICAL_FILL / count)
		local step = height / count
		for index = 1, count do
			centred(frame, style, text:sub(index, index), color, size, width / 2, (index - 0.5) * step, width)
		end
	else
		local share = part:GetAttribute("SignScale") or TEXT_SHARE
		centred(frame, style, text, color, height * share, width / 2, height / 2, width * FIT_SHARE)
	end
end

-- The latest numbers from the server (currently unused but may be needed for future screens).
local snapshot: any = nil

-- A readout whose label is rebuilt when its text changes length, so it always fits (currently unused).
local function readout(frame: Frame, style: string, color: Color3, size: number, x: number, y: number, fit: number)
	local shown: string? = nil
	local label: any = nil
	return function(text: string)
		if text == shown then
			return
		end
		if label and shown and #shown == #text then
			label:set(text)
		else
			if label then
				label.frame:Destroy()
			end
			label = centred(frame, style, text, color, size, x, y, fit)
		end
		shown = text
	end
end

local updaters: { () -> () } = {}

local screens = {
	Name = function(frame: Frame, width: number, height: number)
		centred(frame, "Title", "SPLIT", Palette.Bone, height * 0.32, width / 2, height * 0.32, width * FIT_SHARE)
		centred(frame, "Title", "DECK", Palette.Bone, height * 0.32, width / 2, height * 0.7, width * FIT_SHARE)
	end,
}

local function decorateScreen(part: Instance)
	if not part:IsA("BasePart") or part:FindFirstChild("ScreenText") then
		return
	end
	local build = screens[part:GetAttribute("ScreenKind")]
	if build then
		local frame, width, height = textLayer(part, "ScreenText", Palette.DeepNavy)
		build(frame, width, height)
	end
end

CollectionService:GetInstanceAddedSignal(SIGN_TAG):Connect(decorateSign)
for _, part in CollectionService:GetTagged(SIGN_TAG) do
	decorateSign(part)
end
CollectionService:GetInstanceAddedSignal(SCREEN_TAG):Connect(decorateScreen)
for _, part in CollectionService:GetTagged(SCREEN_TAG) do
	decorateScreen(part)
end
