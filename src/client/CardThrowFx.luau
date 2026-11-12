-- Draws Switchback's throw in the world: the card flies on its edge, tumbling slowly, and on the way turns from
-- itself into a blue, glowing, see-through card with a blue trail (River, 2026-11-12). On a hit it flashes as the
-- two players swap; on a miss it fades where it lands.
--
-- Your own throw is one motion with the first-person hand. The server's report of where the card goes is kept
-- here (`report`), and the hand's view hands over the very card it was holding, where it was and how it was
-- turned, at the moment it lets go (`release`). A separate card used to appear in front of the camera.
-- Everyone else's throw starts at the thrower's chest after the same wind-up.
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local CardCore = ReplicatedStorage:WaitForChild("CardCore")
local CardAim = require(CardCore:WaitForChild("CardAim"))
local CardArt = require(CardCore:WaitForChild("CardArt"))
local CardLook = require(CardCore:WaitForChild("CardLook"))
local Variant = require(CardCore:WaitForChild("Variant"))

local CARD_SIZE = Vector3.new(2.25, 0.07, 3.6) -- in the world: far bigger than a real card, so it reads at this speed
local GROW = 0.45 -- of the flight: a card that left a hand has grown to that size by here
local SETTLE = 0.25 -- of the flight: by here it has eased from how the hand held it onto its edge, down the throw
local SPIN = 7 -- radians a second, end over end. Faster was only a blur.
local EDGE = CFrame.Angles(0, 0, math.rad(90)) -- stands the card on its edge
local BLUE = Color3.fromRGB(70, 150, 255)
local PAPER = Color3.fromRGB(232, 230, 223) -- the card's own edge before it changes
local MORPH_FROM = 0.35 -- of the flight: until here it is plainly the card
local MORPH = 0.85 -- and by here it is all blue
local GHOST = 0.5 -- how see-through the blue card is
local TRAIL_SECONDS = 0.45
local TRAIL_FADE = 0.45 -- how see-through the trail starts
local TRAIL_HALF = 0.31 -- of the card's width, from its middle to each edge of the trail
local GLOW_RANGE = 10
local END_SECONDS = 0.25
local FLASH_SIZE = 5 -- studs across, the burst on a hit
local REPORT_KEPT = 1 -- seconds a report waits for the hand to let go before it is forgotten
local BLIND_RANGE = 80 -- studs your own card flies if the server's report hasn't arrived by the release

local CardThrowFx = {}

local reported: { to: Vector3, hit: boolean, tier: any, at: number }? = nil

local function face(card: Part, side: Enum.NormalId, image: string): Decal
	local decal = Instance.new("Decal")
	decal.Face = side
	decal.Texture = image
	decal.Parent = card
	return decal
end

-- Flies a card from `start` (where it is and how it is turned, at `startSize`) to `to`.
local function fly(start: CFrame, startSize: Vector3, to: Vector3, hit: boolean, tier: any)
	local from = start.Position
	local length = (to - from).Magnitude
	if length < 1 then
		return
	end
	local card = Instance.new("Part")
	card.Name = "SwitchbackCard"
	card.Anchored = true
	card.CanCollide = false
	card.CanQuery = false
	card.CanTouch = false
	card.CastShadow = false
	card.Size = startSize
	-- Plain card stock to begin with. Glowing from the start, it was a white smear.
	card.Material = Enum.Material.SmoothPlastic
	card.Color = PAPER
	local image = if type(tier) == "string" then CardArt.base("switchback", CardLook.look(tier, Variant.Base)) else nil
	local faces: { Decal } = {}
	if image then
		faces = { face(card, Enum.NormalId.Top, image), face(card, Enum.NormalId.Bottom, image) }
	end
	local light = Instance.new("PointLight")
	light.Color = BLUE
	light.Range = GLOW_RANGE
	light.Brightness = 0
	light.Parent = card

	-- The trail is drawn between two points on the card's edges, so it is a ribbon as wide as the card.
	local left, right = Instance.new("Attachment"), Instance.new("Attachment")
	left.Parent, right.Parent = card, card
	local trail = Instance.new("Trail")
	trail.Attachment0, trail.Attachment1 = left, right
	trail.Color = ColorSequence.new(BLUE)
	trail.Transparency = NumberSequence.new(TRAIL_FADE, 1)
	trail.Lifetime = TRAIL_SECONDS
	trail.LightEmission = 0.7
	trail.FaceCamera = true
	trail.Enabled = false -- it starts once the card has begun to change
	trail.Parent = card

	local forward = (to - from).Unit
	-- On its edge, pointing down the throw. It starts turned the way the hand had it and eases onto that.
	local level = (CFrame.lookAt(from, to) * EDGE).Rotation
	local held = start.Rotation
	card.CFrame = start
	card.Parent = workspace

	local flight = CardAim.flight(length)
	local started = os.clock()
	local connection: RBXScriptConnection
	connection = RunService.RenderStepped:Connect(function()
		local age = os.clock() - started
		local share = math.min(age / flight, 1)
		local size = startSize:Lerp(CARD_SIZE, math.min(share / GROW, 1))
		card.Size = size
		left.Position, right.Position = Vector3.new(-size.X * TRAIL_HALF, 0, 0), Vector3.new(size.X * TRAIL_HALF, 0, 0)
		-- Tumbling end over end: about the card's own thin axis, which lies level once it is on its edge.
		local turned = held:Lerp(level, math.min(share / SETTLE, 1)) * CFrame.Angles(0, -age * SPIN, 0)
		card.CFrame = CFrame.new(from + forward * length * share) * turned
		-- The change: its print fades, and the card goes blue, bright and see-through.
		local changed = math.clamp((share - MORPH_FROM) / (MORPH - MORPH_FROM), 0, 1)
		card.Material = if changed > 0.4 then Enum.Material.Neon else Enum.Material.SmoothPlastic
		card.Color = PAPER:Lerp(BLUE, changed)
		card.Transparency = GHOST * changed
		light.Brightness = 3 * changed
		trail.Enabled = changed > 0.15
		for _, decal in faces do
			decal.Transparency = changed
		end
		if share < 1 then
			return
		end
		connection:Disconnect()
		-- Landed: the card goes, and its trail is left to fade out behind it.
		trail.Enabled = false
		local fade = TweenInfo.new(END_SECONDS, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		TweenService:Create(card, fade, { Transparency = 1 }):Play()
		TweenService:Create(light, fade, { Brightness = 0 }):Play()
		Debris:AddItem(card, math.max(END_SECONDS, TRAIL_SECONDS) + 0.1)
		if hit then
			local flash = Instance.new("Part")
			flash.Anchored = true
			flash.CanCollide = false
			flash.CanQuery = false
			flash.CanTouch = false
			flash.CastShadow = false
			flash.Shape = Enum.PartType.Ball
			flash.Material = Enum.Material.Neon
			flash.Color = BLUE
			flash.Transparency = 0.4
			flash.Size = Vector3.one
			flash.Position = to
			flash.Parent = workspace
			TweenService:Create(flash, fade, { Size = Vector3.one * FLASH_SIZE, Transparency = 1 }):Play()
			Debris:AddItem(flash, END_SECONDS + 0.1)
		end
	end)
end

-- Someone else's throw: from their chest to where it lands, after the wind-up.
function CardThrowFx.throw(from: Vector3, to: Vector3, hit: boolean, tier: any)
	if (to - from).Magnitude < 1 then
		return
	end
	task.delay(CardAim.THROW_WINDUP, fly, CFrame.lookAt(from, to) * EDGE, CARD_SIZE, to, hit, tier)
end

-- The server's word on where your own throw goes. It is drawn when your hand lets go.
function CardThrowFx.report(to: Vector3, hit: boolean, tier: any)
	reported = { to = to, hit = hit, tier = tier, at = os.clock() }
end

-- Your hand has let go of the card: `card` is where it was and how it was turned, `size` its size in the hand,
-- and `look` the way you are looking. It carries on from exactly there.
function CardThrowFx.release(card: CFrame, size: Vector3, look: CFrame)
	local known = reported
	reported = nil
	if known and os.clock() - known.at <= REPORT_KEPT then
		fly(card, size, known.to, known.hit, known.tier)
	else
		-- The report is late: fly it the way you're looking, as a miss. The swap, if there is one, still happens.
		fly(card, size, look.Position + look.LookVector * BLIND_RANGE, false, nil)
	end
end

return CardThrowFx
