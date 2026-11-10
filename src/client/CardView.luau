-- The deck of cards held in view: one thin part per card, each showing one of the player's own cards.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CardCore = ReplicatedStorage:WaitForChild("CardCore")
local Guns = ReplicatedStorage:WaitForChild("Guns")
local CardArt = require(CardCore:WaitForChild("CardArt"))
local CardIndex = require(CardCore:WaitForChild("CardIndex"))
local CardLook = require(CardCore:WaitForChild("CardLook"))
local CardFlourish = require(Guns:WaitForChild("CardFlourish"))
local Palette = require(Guns:WaitForChild("Palette"))
local CardData = require(script.Parent.CardData)
local CardInHand = require(script.Parent.CardInHand)

local BACK_SIZE = Vector2.new(150, 240) -- the card's shape, in card units
local BACK_BORDER = 10

local parts: { BasePart } = {}
local faces: { Decal } = {}
local holder: Folder? = nil
local shown = false

local function makeCard(): (BasePart, Decal)
	local part = Instance.new("Part")
	part.Name = "Card"
	part.Size = CardFlourish.CARD_SIZE
	part.Color = Palette.Bone
	part.Material = Enum.Material.SmoothPlastic
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	local face = Instance.new("Decal")
	face.Face = Enum.NormalId.Top
	face.Parent = part
	local back = Instance.new("SurfaceGui")
	back.Face = Enum.NormalId.Bottom
	back.CanvasSize = BACK_SIZE
	back.LightInfluence = 1
	back.Parent = part
	local fill = Instance.new("Frame")
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = Palette.Bone
	fill.BorderSizePixel = 0
	fill.Parent = back
	local panel = Instance.new("Frame")
	panel.Position = UDim2.fromOffset(BACK_BORDER, BACK_BORDER)
	panel.Size = UDim2.new(1, -BACK_BORDER * 2, 1, -BACK_BORDER * 2)
	panel.BackgroundColor3 = Palette.DeepNavy
	panel.BorderSizePixel = 0
	panel.Parent = fill
	return part, face
end

local function make(): Folder
	local folder = Instance.new("Folder")
	folder.Name = "CardView"
	for index = 1, CardFlourish.COUNT do
		local part, face = makeCard()
		part.Parent = folder
		parts[index], faces[index] = part, face
	end
	return folder
end

-- Deals the player's deck through the cards over and over, with the card in hand on top of the right hand's half.
local function dress()
	local snapshot = CardData.get()
	local art = {}
	if snapshot then
		for slot, entry in snapshot.deck do
			local variant = CardIndex.variant(snapshot.stacks, entry.cardId, entry.tier)
			art[slot] = CardArt.base(entry.cardId, CardLook.look(entry.tier, variant)) or ""
		end
	end
	local chosen = CardInHand.slot or 1
	for index, face in faces do
		face.Texture = if #art > 0 then art[(index - CardFlourish.HALF + chosen - 1) % #art + 1] else ""
	end
end

local CardView = {}

-- cards is where each card is, relative to view.
function CardView.show(camera: Camera, view: CFrame, cards: { CFrame })
	holder = holder or make()
	if not shown then
		shown = true
		dress()
	end
	local placed = table.create(#cards)
	for index, frame in cards do
		placed[index] = view * frame
	end
	workspace:BulkMoveTo(parts, placed, Enum.BulkMoveMode.FireCFrameChanged)
	local folder = holder :: Folder
	folder.Parent = camera
end

function CardView.hide()
	shown = false
	if holder then
		holder.Parent = nil
	end
end

return CardView
