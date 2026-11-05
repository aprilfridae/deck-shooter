-- The bending card and the deck held in view. Uses the Card model in ReplicatedStorage.GunModels, or a plain block until it's imported.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CARD_LENGTH = 0.32
local BLOCK_SIZE = Vector3.new(0.3, 0.012, CARD_LENGTH)
local BLOCK_COLOR = Color3.fromRGB(20, 60, 120)
local DECK_SIZE = Vector3.new(0.22, 0.1, CARD_LENGTH)
local DECK_COLOR = Color3.fromRGB(205, 210, 220)
local BEND_SIGN = -1 -- the imported bones turn the opposite way to the ones in Blender

local card: BasePart? = nil
local model: Instance? = nil
local deck: BasePart? = nil
local bones: { Bone } = {}

local function setUp(part: BasePart)
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
end

local function makeBlock()
	local part = Instance.new("Part")
	part.Name = "CardView"
	part.Size = BLOCK_SIZE
	part.Color = BLOCK_COLOR
	part.Material = Enum.Material.SmoothPlastic
	setUp(part)
	card, model = part, part
end

local function make()
	local folder = ReplicatedStorage:FindFirstChild("GunModels")
	local source = folder and folder:FindFirstChild("Card")
	local mesh = source and (if source:IsA("MeshPart") then source else source:FindFirstChildWhichIsA("MeshPart", true))
	if not source or not mesh then
		makeBlock()
		return
	end
	local copy = Instance.new("Model")
	copy.Name = "CardView"
	local part = mesh:Clone() :: MeshPart
	part.Parent = copy
	copy.PrimaryPart = part
	copy:ScaleTo(CARD_LENGTH / math.max(part.Size.X, part.Size.Y, part.Size.Z))
	setUp(part)
	local found = {}
	for _, child in part:GetDescendants() do
		if child:IsA("Bone") then
			table.insert(found, child)
		end
	end
	table.sort(found, function(a, b)
		return a.Name < b.Name
	end)
	card, model, bones = part, copy, found
end

-- A block with the card's art on top. The deck never bends, so it needs no bones.
local function makeDeck(): BasePart
	local part = Instance.new("Part")
	part.Name = "DeckView"
	part.Size = DECK_SIZE
	part.Color = DECK_COLOR
	part.Material = Enum.Material.SmoothPlastic
	setUp(part)
	if card and card:IsA("MeshPart") then
		local art = Instance.new("Decal")
		art.Face = Enum.NormalId.Top
		art.Texture = card.TextureID
		art.Parent = part
	end
	return part
end

local CardView = {}

function CardView.show(camera: Camera, frame: any, jitter: CFrame)
	if not card then
		make()
	end
	deck = deck or makeDeck()
	local part = card :: BasePart
	part.CFrame = camera.CFrame * frame.card * jitter
	local held = deck :: BasePart
	held.CFrame = camera.CFrame * frame.deck * jitter
	held.Parent = camera
	-- The first bone stays put, and each one after it bows a little further.
	for index = 2, #bones do
		bones[index].Transform = CFrame.Angles(frame.bend * BEND_SIGN, 0, 0)
	end
	local shown = model :: Instance
	shown.Parent = camera
end

function CardView.hide()
	if model then
		model.Parent = nil
	end
	if deck then
		deck.Parent = nil
	end
end

return CardView
