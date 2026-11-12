-- The moving parts cards and pack wrappers share: shine bands, stripes, pings and the step that
-- drives them. Sizes are in the art's own units, which `unit` turns into pixels.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local CardArt = require(ReplicatedStorage:WaitForChild("CardCore"):WaitForChild("CardArt"))
local Guns = ReplicatedStorage:WaitForChild("Guns")
local CardMotion = require(Guns:WaitForChild("Hud"):WaitForChild("CardMotion"))
local Palette = require(Guns:WaitForChild("Palette"))

local STRIPE_TILE = 28
-- The stripes image is 112 pixels square and holds two repeats of the pattern side by side. Only one repeat is shown
-- as the tile, and the stripes move by sliding which 56 pixels of the image that is. The label itself never moves or
-- sticks out of its block, so nothing depends on clipping, which Roblox drops for anything rotated (the HUD's tilted
-- cards) and which let the stripes run off the card.
local STRIPE_PIXELS = 112
local STRIPE_REPEAT = 56
local STRIPE_TIME = 1.4 -- seconds for stripes to move one tile
local RING_THICKNESS = 1.2
local SHINE_ROTATION = 20 -- degrees, so the band leans as it crosses
local SHINE_LAYER = 5

local CardEffects = {}

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

function CardEffects.animate(root: GuiObject, update: (number) -> ())
	local face = { root = root, started = os.clock(), update = update }
	table.insert(live, face)
	root.Destroying:Once(function()
		stopAnimating(face)
	end)
	if not stepping then
		stepping = RunService.RenderStepped:Connect(step)
	end
end

function CardEffects.rounded(gui: GuiObject, radius: UDim)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = radius
	corner.Parent = gui
end

-- A root-sized frame showing only a slanted band. Moving the gradient's offset moves the band.
-- `rotation` is the band's lean in degrees: the shine's 20 unless given.
function CardEffects.band(root: GuiObject, corner: number, halfWidth: number, color: ColorSequence, strength: number, rotation: number?): UIGradient
	local frame = Instance.new("Frame")
	frame.BackgroundColor3 = Color3.new(1, 1, 1)
	frame.BorderSizePixel = 0
	frame.Size = UDim2.fromScale(1, 1)
	frame.ZIndex = SHINE_LAYER
	frame.Parent = root
	CardEffects.rounded(frame, UDim.new(0, corner))
	local gradient = Instance.new("UIGradient")
	gradient.Rotation = rotation or SHINE_ROTATION
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

function CardEffects.stripes(root: GuiObject, unit: number, color: Color3, area: Rect): ImageLabel
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
	image.ImageRectSize = Vector2.new(STRIPE_REPEAT, STRIPE_PIXELS)
	image.TileSize = UDim2.fromOffset(STRIPE_TILE * unit * STRIPE_REPEAT / STRIPE_PIXELS, STRIPE_TILE * unit)
	image.Size = UDim2.fromScale(1, 1)
	image.Parent = block
	return image
end

function CardEffects.scrolling(image: ImageLabel, unit: number): (number) -> ()
	return function(elapsed: number)
		-- The same speed as before: one whole tile, two repeats, every STRIPE_TIME.
		local repeatTime = STRIPE_TIME * STRIPE_REPEAT / STRIPE_PIXELS
		image.ImageRectOffset = Vector2.new(STRIPE_REPEAT * ((elapsed % repeatTime) / repeatTime), 0)
	end
end

-- A ring spreading from a point.
function CardEffects.ping(root: GuiObject, unit: number, centre: Vector2): (number) -> ()
	local ring = Instance.new("Frame")
	ring.BackgroundTransparency = 1
	ring.AnchorPoint = Vector2.new(0.5, 0.5)
	ring.Position = UDim2.fromOffset(centre.X * unit, centre.Y * unit)
	ring.Parent = root
	CardEffects.rounded(ring, UDim.new(0.5, 0))
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

return CardEffects
