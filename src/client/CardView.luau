-- The deck of cards held in view: one thin part per card, each showing one of the player's own cards.
local GeometryService = game:GetService("GeometryService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CardCore = ReplicatedStorage:WaitForChild("CardCore")
local Guns = ReplicatedStorage:WaitForChild("Guns")
local CardArt = require(CardCore:WaitForChild("CardArt"))
local CardIndex = require(CardCore:WaitForChild("CardIndex"))
local CardLook = require(CardCore:WaitForChild("CardLook"))
local CardFlourish = require(Guns:WaitForChild("CardFlourish"))
local SkipBurst = require(Guns:WaitForChild("SkipBurst"))
local Palette = require(Guns:WaitForChild("Palette"))
local Cards = require(CardCore:WaitForChild("Cards"))
local CardData = require(script.Parent.CardData)
local CardFace = require(script.Parent.CardFace)
local Perf = require(script.Parent.Perf)
local CardInHand = require(script.Parent.CardInHand)


local SHARDS = 14 -- bits of card thrown out of the fist
local SPARKS = 22

local parts: { BasePart } = {}
local fist: BasePart? = nil -- where the crushed card bursts from
local shards: ParticleEmitter? = nil
local sparks: ParticleEmitter? = nil
local burst = false -- whether this card has burst yet
-- Cutting the flourish short pops a burst off the deck in the left hand: flat pieces that face the eye (SkipBurst).
local SNAP_NEAR = 0.06 -- studs toward the eye from the deck, so the cards don't cut through it
local snaps: { BasePart } = {}
local snapAt: number? = nil -- when the burst went off
local faces: { Decal } = {}
local holder: Folder? = nil
local shown = false
local art: { string } = {} -- the image of the card in each deck slot
local topShown: number? = nil -- the card showing the held card's art
local slotShown: number? = nil -- and the slot it shows
local shrunk: number? = nil -- the card the crush has shrunk

-- A card that's face up gets its whole face printed on it, text and all, the same as in the menus. The rest show
-- only the baked image, which is all a card on its way over needs.
local PRINT_WIDTH = 300 -- pixels across a printed face
local entries: { any } = {} -- the card in each deck slot
local slots: { [number]: number } = {} -- the deck slot each card shows
local prints: { [number]: SurfaceGui } = {}
local printed: { [number]: string } = {} -- what each card has printed on it

-- Motion blur: each card has a few faint copies of itself, and while it moves fast they trail back along the way it
-- came.
local GHOSTS = 6 -- copies of each card
local FADES = { 0.92, 0.938, 0.954, 0.967, 0.978, 0.987 } -- how see-through each is, nearest the card first
local SHUTTER = 0.07 -- seconds of movement a card is smeared over
local BLUR_FROM = 0.5 -- studs a second a card has to move to blur
local STACKED = 0.02 -- cards this close move as one stack, and only one of them blurs
local AWAY = CFrame.new(0, 1e5, 0) -- where the copies wait
local CORNER_AT = CardFlourish.CARD_SIZE / 2 -- a card's corner, which moves when it only spins
local ghosts: { BasePart } = {}
local ghostFaces: { Decal } = {}
local history: { { at: number, cards: { CFrame } } } = {} -- where the cards were lately, oldest first
local BLUR_FADE = 14 -- how fast a card's blur fades in and out, a second
local strengths: { [number]: number } = {} -- how much of each card's blur shows, 0 to 1
local steppedAt = 0
local ghostsOut = false -- whether any blur copies were out last frame

-- A bent card is shown as a few strips along its length, each with its slice of the card's two images, and the card
-- itself is put away while they show.
local STRIPS = CardFlourish.STRIPS
local BENT_FROM = 0.01 -- radians a card has to be bent before it's shown in strips
local strips: { BasePart } = {}
local stripFaces: { Texture } = {}
local stripsOut = false -- whether any strips are showing

local CORNER = CardFlourish.CARD_SIZE.X * 10 / 150 -- the card art's corners (tools/make-card-art.py)
local rounded: BasePart? = nil -- a card cut with those corners, once it's made

local function block(size: Vector3, at: CFrame?): Part
	local part = Instance.new("Part")
	part.Size = size
	part.CFrame = at or CFrame.identity
	part.Anchored = true
	return part
end

-- Cuts the rounded card: two slabs in a cross, and a disc in each corner. The cards stay solid, so the outline on
-- the hands can't show through them, and they're square until this is done or if it can't be.
local function cut()
	local size = CardFlourish.CARD_SIZE
	local inX, inZ = size.X / 2 - CORNER, size.Z / 2 - CORNER
	local pieces: { Instance } = { block(Vector3.new(inX * 2, size.Y, size.Z)) }
	for _, x in { -inX, inX } do
		for _, z in { -inZ, inZ } do
			local disc = block(Vector3.new(size.Y, CORNER * 2, CORNER * 2), CFrame.new(x, 0, z) * CFrame.Angles(0, 0, math.pi / 2))
			disc.Shape = Enum.PartType.Cylinder
			table.insert(pieces, disc)
		end
	end
	local done, unions = pcall(function()
		return GeometryService:UnionAsync(block(Vector3.new(size.X, size.Y, inZ * 2)), pieces, {
			CollisionFidelity = Enum.CollisionFidelity.Box,
			RenderFidelity = Enum.RenderFidelity.Precise,
		})
	end)
	if not done or not unions[1] then
		return
	end
	rounded = unions[1]
	if holder then -- cards made square so far are made again
		holder:Destroy()
		holder, shown = nil, false
		table.clear(parts)
		table.clear(faces)
		table.clear(ghosts)
		table.clear(ghostFaces)
		table.clear(strips)
		table.clear(stripFaces)
		table.clear(prints)
		table.clear(printed)
	end
end

local function makeCard(): (BasePart, Decal)
	local part: BasePart = if rounded then rounded:Clone() else Instance.new("Part")
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
	local back = Instance.new("Decal") -- one image the card's own shape, so it can't stretch
	back.Face = Enum.NormalId.Bottom
	back.Texture = CardArt.HAND_BACK
	back.Parent = part
	return part, face
end

-- One strip of a bent card: `piece` of STRIPS along its length, showing that slice of the face and of the back.
local function makeStrip(piece: number): (BasePart, Texture)
	local size = CardFlourish.CARD_SIZE
	local part = Instance.new("Part")
	part.Name = "Strip"
	part.Size = Vector3.new(size.X, size.Y, size.Z / STRIPS)
	part.Color = Palette.Bone
	part.Material = Enum.Material.SmoothPlastic
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.CFrame = AWAY
	local images = {}
	for _, side in { Enum.NormalId.Top, Enum.NormalId.Bottom } do
		local image = Instance.new("Texture")
		image.Face = side
		image.StudsPerTileU = size.X
		image.StudsPerTileV = size.Z
		image.OffsetStudsV = (STRIPS - piece) * size.Z / STRIPS
		image.Parent = part
		table.insert(images, image)
	end
	images[2].Texture = CardArt.HAND_BACK
	return part, images[1]
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

	table.clear(snaps)
	for index, piece in SkipBurst.at(0) do
		local part = Instance.new("Part")
		part.Name = "Snap"
		part.Color = (Palette :: any)[piece.tone]
		part.Material = Enum.Material.Neon -- flat colour, whatever the light
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.CastShadow = false
		part.CFrame = AWAY
		part.Parent = folder
		snaps[index] = part
	end
end

local function make(): Folder
	local folder = Instance.new("Folder")
	folder.Name = "CardView"
	makeBurst(folder)
	for index = 1, CardFlourish.COUNT do
		local part, face = makeCard()
		part.Parent = folder
		parts[index], faces[index] = part, face
		for ghost = 1, GHOSTS do
			local copy, copyFace = makeCard()
			copy.Name = "Blur"
			copy.Transparency = FADES[ghost]
			-- Blur copies glow in one flat colour, white nearest the card and blue furthest back, with no picture.
			copy.Color = Palette.blur(1 - (ghost - 1) / (GHOSTS - 1))
			copy.Material = Enum.Material.Neon
			for _, image in copy:GetChildren() do
				(image :: Decal).Transparency = 1
			end
			copy.CFrame = AWAY
			copy.Parent = folder
			table.insert(ghosts, copy)
			table.insert(ghostFaces, copyFace)
		end
		for piece = 1, STRIPS do
			local strip, stripFace = makeStrip(piece)
			strip.Parent = folder
			table.insert(strips, strip)
			table.insert(stripFaces, stripFace)
		end
	end
	return folder
end

-- Prints a card's face on it, if it isn't already.
local function printFace(index: number)
	local entry = entries[slots[index] or 0]
	local key = if entry then entry.cardId .. entry.tier .. entry.variant else ""
	if printed[index] == key then
		return
	end
	printed[index] = key
	if prints[index] then
		prints[index]:Destroy()
		prints[index] = nil
	end
	faces[index].Transparency = 0
	if not entry or not Cards.byId[entry.cardId] then
		return
	end
	local gui = Instance.new("SurfaceGui")
	gui.Name = "Print"
	gui.Face = Enum.NormalId.Top
	gui.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
	-- The top of a card part runs its long way across, so the face is laid on it turned a quarter.
	local height = PRINT_WIDTH * 240 / 150
	gui.CanvasSize = Vector2.new(height, PRINT_WIDTH)
	local turned = Instance.new("Frame")
	turned.BackgroundTransparency = 1
	turned.AnchorPoint = Vector2.new(0.5, 0.5)
	turned.Position = UDim2.fromScale(0.5, 0.5)
	turned.Size = UDim2.fromOffset(PRINT_WIDTH, height)
	turned.Rotation = 90
	turned.Parent = gui
	gui.LightInfluence = 1
	gui.Parent = parts[index]
	CardFace.new(turned, {
		cardId = entry.cardId,
		tier = entry.tier,
		variant = entry.variant,
		width = PRINT_WIDTH,
		serial = CardData.serial(entry.cardId, entry.tier, entry.variant),
	})
	prints[index] = gui
	faces[index].Transparency = 1 -- the print has the image too
end

-- Sets which deck slot's card a card and its blur show.
local function setFace(index: number, slot: number?)
	local texture = slot and art[slot] or ""
	slots[index] = slot :: number
	faces[index].Texture = texture
	for ghost = 1, GHOSTS do
		ghostFaces[(index - 1) * GHOSTS + ghost].Texture = texture
	end
	for piece = 1, STRIPS do
		stripFaces[(index - 1) * STRIPS + piece].Texture = texture
	end
end

-- Where every card's blur copies go: trailing the cards that are moving fast, and away for the rest.
local function blur(view: CFrame, cards: { CFrame }): ({ CFrame }, boolean)
	local now = os.clock()
	local trail = table.create(#ghosts, AWAY)
	local any = false -- whether any copy is out this frame
	local was = history[1]
	if was and now - was.at < 0.2 then
		local span = now - was.at
		local back = math.min(SHUTTER / span, 1)
		local fadeStep = 1 - math.exp(-math.min(now - steppedAt, 0.1) * BLUR_FADE)
		steppedAt = now
		local blurred: { Vector3 } = {}
		for index = #cards, 1, -1 do -- top cards first, so a stack's blur shows the card on top
			local frame, old = cards[index], was.cards[index]
			local moved = math.max((frame.Position - old.Position).Magnitude, (frame * CORNER_AT - old * CORNER_AT).Magnitude)
			-- How much blur the card wants: none below BLUR_FROM, all of it at twice that.
			local wanted = 0
			if moved >= BLUR_FROM * span and index ~= shrunk then
				local alone = true
				for _, other in blurred do
					if (other - frame.Position).Magnitude < STACKED then
						alone = false
						break
					end
				end
				if alone then
					table.insert(blurred, frame.Position)
					wanted = math.clamp(moved / (BLUR_FROM * span) - 1, 0, 1)
				end
			end
			-- It fades in and out over a few frames, so the copies never flicker on and off.
			local shows = strengths[index] or 0
			shows += (wanted - shows) * fadeStep
			strengths[index] = shows
			if shows > 0.02 then
				any = true
				-- How many of each card's copies are used follows the machine; the rest stay put away.
				local used = Perf.pick(GHOSTS, 3, 1)
				for ghost = 1, used do
					local copy = (index - 1) * GHOSTS + ghost
					trail[copy] = view * frame:Lerp(old, back * ghost / used)
					ghosts[copy].Transparency = 1 - (1 - FADES[ghost]) * shows
				end
			end
		end
	end
	table.insert(history, { at = now, cards = table.clone(cards) })
	while history[2] and now - history[2].at >= SHUTTER do
		table.remove(history, 1)
	end
	return trail, any
end

-- Deals the player's deck through the cards over and over, with the card in hand on top of the right hand's half.
local function dress()
	local snapshot = CardData.get()
	table.clear(art)
	table.clear(entries)
	for index, gui in prints do
		gui:Destroy()
		faces[index].Transparency = 0
	end
	table.clear(prints)
	table.clear(printed)
	topShown, slotShown = nil, nil
	if snapshot then
		for slot, entry in snapshot.deck do
			local variant = CardIndex.variant(snapshot.stacks, entry.cardId, entry.tier)
			art[slot] = CardArt.base(entry.cardId, CardLook.look(entry.tier, variant)) or ""
			entries[slot] = { cardId = entry.cardId, tier = entry.tier, variant = variant }
		end
	end
	local chosen = CardInHand.slot or 1
	for index in faces do
		setFace(index, if #art > 0 then (index - CardFlourish.HALF + chosen - 1) % #art + 1 else nil)
	end
end

task.spawn(cut)

local CardView = {}

-- Puts the card in hand back to full size, ready for the next one.
local function restore()
	burst = false
	local card = shrunk and parts[shrunk]
	if card then
		card.Size = CardFlourish.CARD_SIZE
	end
	shrunk = nil
end

-- cards is where each card is, relative to view. crush is the card in hand being crushed, if it is. top is the card
-- that's face up on top in the right hand, which shows the card held. bends is how far each card is bent, if any are.
function CardView.show(
	camera: Camera,
	view: CFrame,
	cards: { CFrame },
	crush: CardFlourish.Crush?,
	top: number,
	bends: { number }?
)
	holder = holder or make()
	if not shown then
		shown = true
		table.clear(history)
		dress()
	end
	local slot = CardInHand.slot
	if slot and (top ~= topShown or slot ~= slotShown) then
		topShown, slotShown = top, slot
		setFace(top, slot)
	end
	for index = top, CardFlourish.CHOSEN do -- the cards that are face up, or turning
		printFace(index)
	end
	if crush then
		local left = math.max(1 - crush.crushed, 0.01)
		if shrunk ~= crush.card then
			restore()
			shrunk = crush.card
		end
		parts[crush.card].Size = CardFlourish.CARD_SIZE * Vector3.new(left, 1, left);
		(fist :: BasePart).CFrame = view * CFrame.new(crush.palm)
		if crush.crushed >= 1 and not burst then
			burst = true;
			(shards :: ParticleEmitter):Emit(SHARDS);
			(sparks :: ParticleEmitter):Emit(SPARKS)
		end
	elseif burst or shrunk then
		restore()
	end
	local placed = table.create(#cards)
	for index, frame in cards do
		placed[index] = view * frame
	end
	if snapAt then
		local share = (os.clock() - snapAt) / SkipBurst.LENGTH
		if share >= 1 then
			snapAt = nil
		end
		-- Square to the eye, at the top of the deck in the left hand.
		local middle = view * CFrame.new(cards[CardFlourish.COUNT].Position + Vector3.new(0, 0, SNAP_NEAR))
		local spots = table.create(#snaps, AWAY)
		for index, piece in SkipBurst.at(share) do
			if piece.shown then
				snaps[index].Size = Vector3.new(piece.width, piece.height, 0.002)
				spots[index] = middle * CFrame.new(piece.x, piece.y, 0) * CFrame.Angles(0, 0, piece.turn)
			end
		end
		workspace:BulkMoveTo(snaps, spots, Enum.BulkMoveMode.FireCFrameChanged)
	end
	if bends or stripsOut then
		local pieces = table.create(#strips, AWAY)
		stripsOut = false
		for index, bend in bends or {} do
			if math.abs(bend) >= BENT_FROM then
				stripsOut = true
				for piece, at in CardFlourish.strips(placed[index], bend) do
					pieces[(index - 1) * STRIPS + piece] = at
				end
				placed[index] = AWAY
			end
		end
		workspace:BulkMoveTo(strips, pieces, Enum.BulkMoveMode.FireCFrameChanged)
	end
	workspace:BulkMoveTo(parts, placed, Enum.BulkMoveMode.FireCFrameChanged)
	-- The copies are only moved while some are out, and once more after to put them away: with the cards held
	-- still, which is most of the time, none of the 192 of them is touched.
	local trail, blurring = blur(view, cards)
	if blurring or ghostsOut then
		workspace:BulkMoveTo(ghosts, trail, Enum.BulkMoveMode.FireCFrameChanged)
	end
	ghostsOut = blurring
	local folder = holder :: Folder
	folder.Parent = camera
end

-- Pops the burst for a flourish cut short, the next time the cards are shown.
function CardView.snap()
	snapAt = os.clock()
end

function CardView.hide()
	shown = false
	restore()
	if holder then
		holder.Parent = nil
	end
end

return CardView
