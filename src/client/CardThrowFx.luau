-- Draws Switchback's throw: the card leaves the hand on its edge, tumbling, and in the air turns blue, glowing and
-- see-through, with a blue trail behind it (River, 2026-11-12: "in mid air it morphs blue and turns
-- transluscent but its like hitscan so you throw it really fast"). On a hit it flashes as the two players swap; on
-- a miss it fades where it lands. The flight time is CardAim's, the same the server waits before swapping.
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local CardCore = ReplicatedStorage:WaitForChild("CardCore")
local CardAim = require(CardCore:WaitForChild("CardAim"))
local CardArt = require(CardCore:WaitForChild("CardArt"))
local CardLook = require(CardCore:WaitForChild("CardLook"))
local Variant = require(CardCore:WaitForChild("Variant"))

local CARD_SIZE = Vector3.new(1.5, 0.05, 2.4) -- lying flat: wide, thin, long
-- It tumbles slowly: at 30 radians a second it was only a blur (River, 2026-11-12: "make the card look like a
-- card"). A little over half a turn in a long throw.
local SPIN = 7 -- radians a second, end over end
local CARD_SCALE = 1.5 -- bigger than a real card, so it reads at this speed
local EDGE = CFrame.Angles(0, 0, math.rad(90)) -- stands the card on its edge
local BLUE = Color3.fromRGB(70, 150, 255)
local PAPER = Color3.fromRGB(232, 230, 223) -- the card's own edge before it changes
local MORPH_FROM = 0.35 -- of the flight: until here it is plainly the card
local MORPH = 0.85 -- and by here it is all blue
local GHOST = 0.5 -- how see-through the blue card is
local OWN_REACH = 4 -- studs: a throw starting this near the camera is your own
local OWN_HAND = CFrame.new(0.4, 0.1, -1.6) -- where your right hand lets go, from the camera
local TRAIL_SECONDS = 0.45
local TRAIL_FADE = 0.45 -- how see-through the trail starts
local TRAIL_HALF = 0.7 -- studs from the card's middle to each edge of the trail
local GLOW_RANGE = 10
local END_SECONDS = 0.25
local FLASH_SIZE = 5 -- studs across, the burst on a hit

local CardThrowFx = {}

local function face(card: Part, side: Enum.NormalId, image: string): Decal
	local decal = Instance.new("Decal")
	decal.Face = side
	decal.Texture = image
	decal.Parent = card
	return decal
end

-- Throws the card from one point to another. `hit` is whether it caught someone.
function CardThrowFx.throw(from: Vector3, to: Vector3, hit: boolean, tier: any)
	-- Your own throw starts where your hand let go of it, not in your chest.
	local camera = workspace.CurrentCamera
	if camera and (camera.CFrame.Position - from).Magnitude < OWN_REACH then
		from = (camera.CFrame * OWN_HAND).Position
	end
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
	card.Size = CARD_SIZE * CARD_SCALE
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
	left.Position, right.Position = Vector3.new(-TRAIL_HALF * CARD_SCALE, 0, 0), Vector3.new(TRAIL_HALF * CARD_SCALE, 0, 0)
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
	local level = CFrame.lookAt(from, to)
	card.CFrame = level
	card.Parent = workspace

	local flight = CardAim.flight(length)
	local started = os.clock()
	local connection: RBXScriptConnection
	connection = RunService.RenderStepped:Connect(function()
		local age = os.clock() - started
		local share = math.min(age / flight, 1)
		card.CFrame = (level + forward * length * share) * CFrame.Angles(-age * SPIN, 0, 0) * EDGE
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

return CardThrowFx
