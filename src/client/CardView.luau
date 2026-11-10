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

local SHARDS = 14 -- bits of card thrown out of the fist
local SPARKS = 22

local parts: { BasePart } = {}
local fist: BasePart? = nil -- where the crushed card bursts from
local shards: ParticleEmitter? = nil
local sparks: ParticleEmitter? = nil
local burst = false -- whether this card has burst yet
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

-- Bits of card and bright specks that fly out of the closing fist. They ride along with the hand.
local function makeBurst(folder: Folder)
	local anchor = Instance.new("Part")
	anchor.Name = "Fist"
	anchor.Size = Vector3.one * 0.05
	anchor.Transparency = 1
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.CastShadow = false
	anchor.Parent = folder
	local bits = Instance.new("ParticleEmitter")
	bits.Texture = "rbxasset://textures/particles/smoke_main.dds"
	bits.Color = ColorSequence.new(Palette.Bone)
	bits.LightEmission = 0.3
	bits.LightInfluence = 0
	bits.Lifetime = NumberRange.new(0.25, 0.45)
	bits.Speed = NumberRange.new(0.6, 1.6)
	bits.SpreadAngle = Vector2.new(180, 180)
	bits.Drag = 5
	bits.Rotation = NumberRange.new(0, 360)
	bits.RotSpeed = NumberRange.new(-400, 400)
	bits.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.05), NumberSequenceKeypoint.new(1, 0.16) })
	bits.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) })
	bits.LockedToPart = true
	bits.Rate = 0
	bits.Parent = anchor
	local specks = Instance.new("ParticleEmitter")
	specks.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	specks.Color = ColorSequence.new(Color3.new(1, 1, 1), Palette.Bone)
	specks.LightEmission = 1
	specks.LightInfluence = 0
	specks.Lifetime = NumberRange.new(0.2, 0.4)
	specks.Speed = NumberRange.new(1.5, 4)
	specks.SpreadAngle = Vector2.new(180, 180)
	specks.Drag = 6
	specks.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.07), NumberSequenceKeypoint.new(1, 0) })
	specks.LockedToPart = true
	specks.Rate = 0
	specks.Parent = anchor
	fist, shards, sparks = anchor, bits, specks
end

local function make(): Folder
	local folder = Instance.new("Folder")
	folder.Name = "CardView"
	makeBurst(folder)
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
	faces[CardFlourish.CHOSEN].Texture = faces[CardFlourish.HALF].Texture -- the card that gets flipped face up
end

local CardView = {}

-- Puts the card in hand back to full size, ready for the next one.
local function restore()
	burst = false
	local card = parts[CardFlourish.CHOSEN]
	if card then
		card.Size = CardFlourish.CARD_SIZE
	end
end

-- cards is where each card is, relative to view. crush is the card in hand being crushed, if it is.
function CardView.show(camera: Camera, view: CFrame, cards: { CFrame }, crush: CardFlourish.Crush?)
	holder = holder or make()
	if not shown then
		shown = true
		dress()
	end
	if crush then
		local left = math.max(1 - crush.crushed, 0.01)
		parts[CardFlourish.CHOSEN].Size = CardFlourish.CARD_SIZE * Vector3.new(left, 1, left);
		(fist :: BasePart).CFrame = view * CFrame.new(crush.palm)
		if crush.crushed >= 1 and not burst then
			burst = true;
			(shards :: ParticleEmitter):Emit(SHARDS);
			(sparks :: ParticleEmitter):Emit(SPARKS)
		end
	elseif burst or parts[CardFlourish.CHOSEN].Size ~= CardFlourish.CARD_SIZE then
		restore()
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
	restore()
	if holder then
		holder.Parent = nil
	end
end

return CardView
