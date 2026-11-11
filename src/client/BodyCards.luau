-- The deck of cards a soldier body holds in third person: one thin part a card, placed where CardFlourish has
-- each, so other players (and you, in the test view) see the same flourish, turn and crush first person plays.
-- Plain cards: backs in the body's navy, and the card that ends face up in the right hand in bone. First person's
-- own deck (CardView) carries each card's art and bends; at third-person size neither would read.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Guns = ReplicatedStorage:WaitForChild("Guns")
local CardFlourish = require(Guns:WaitForChild("CardFlourish"))
local Palette = require(Guns:WaitForChild("Palette"))

local BACK = Palette.DeepNavy
local FACE = Palette.Bone
local THICK = 0.012 -- a little thicker than first person's, so a single card still shows at a distance

local BodyCards = {}

type Deck = { model: Model, cards: { BasePart }, frames: { CFrame } }

local folder = Instance.new("Folder")
folder.Name = "BodyCards"
folder.Parent = workspace

local decks: { [Model]: Deck } = {}

local function build(): Deck
	local model = Instance.new("Model")
	model.Name = "Deck"
	local cards = table.create(CardFlourish.COUNT)
	for index = 1, CardFlourish.COUNT do
		local card = Instance.new("Part")
		card.Name = "Card"
		card.Size = Vector3.new(CardFlourish.CARD_SIZE.X, THICK, CardFlourish.CARD_SIZE.Z)
		card.Color = BACK
		card.Material = Enum.Material.SmoothPlastic
		card.Anchored = true
		card.CanCollide = false
		card.CanQuery = false
		card.CanTouch = false
		card.CastShadow = false
		card.Parent = model
		cards[index] = card
	end
	return { model = model, cards = cards, frames = table.create(CardFlourish.COUNT) }
end

-- Shows a body's deck. view is the frame the flourish hangs from (first person's is the camera); frames are the
-- flourish's cards, from it. faceUp is the card showing its face, if one is, and gone is how far that card has
-- been crushed away, 0 to 1.
function BodyCards.show(character: Model, view: CFrame, frames: { CFrame }, faceUp: number?, gone: number?)
	local deck = decks[character]
	if not deck then
		deck = build()
		decks[character] = deck
	end
	for index, card in deck.cards do
		deck.frames[index] = view * frames[index]
		local isFace = index == faceUp
		card.Color = if isFace then FACE else BACK
		card.Transparency = if isFace and gone then math.clamp(gone, 0, 1) else 0
	end
	workspace:BulkMoveTo(deck.cards, deck.frames, Enum.BulkMoveMode.FireCFrameChanged)
	deck.model.Parent = folder
end

function BodyCards.hide(character: Model)
	local deck = decks[character]
	if deck then
		deck.model.Parent = nil
	end
end

function BodyCards.remove(character: Model)
	local deck = decks[character]
	if deck then
		deck.model:Destroy()
		decks[character] = nil
	end
end

return BodyCards
