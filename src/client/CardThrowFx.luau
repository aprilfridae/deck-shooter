-- Draws Switchback's throw: the card itself spins flat through the air to its target, leaving a see-through blue
-- trail (River, 2026-11-12). It replaced a chain the same day. On a hit it flashes as the two players swap; on a
-- miss it fades where it lands. The flight time is CardAim's, the same the server waits before swapping.
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
local SPIN = 26 -- radians a second, about its flat face
local TILT = math.rad(12) -- it banks a little, like a thrown card
local BLUE = Color3.fromRGB(70, 150, 255)
local TRAIL_SECONDS = 0.45
local TRAIL_FADE = 0.45 -- how see-through the trail starts
local TRAIL_HALF = 0.7 -- studs from the card's middle to each edge of the trail
local GLOW_RANGE = 10
local END_SECONDS = 0.25
local FLASH_SIZE = 5 -- studs across, the burst on a hit

local CardThrowFx = {}

local function face(card: Part, side: Enum.NormalId, image: string)
	local decal = Instance.new("Decal")
	decal.Face = side
	decal.Texture = image
	decal.Parent = card
end

-- Throws the card from one point to another. `hit` is whether it caught someone.
function CardThrowFx.throw(from: Vector3, to: Vector3, hit: boolean, tier: any)
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
	card.Size = CARD_SIZE
	card.Material = Enum.Material.SmoothPlastic
	card.Color = BLUE
	local image = if type(tier) == "string" then CardArt.base("switchback", CardLook.look(tier, Variant.Base)) else nil
	if image then
		face(card, Enum.NormalId.Top, image)
		face(card, Enum.NormalId.Bottom, image)
	end
	local light = Instance.new("PointLight")
	light.Color = BLUE
	light.Range = GLOW_RANGE
	light.Parent = card

	-- The trail is drawn between two points on the card's edges, so it is a ribbon as wide as the card.
	local left, right = Instance.new("Attachment"), Instance.new("Attachment")
	left.Position, right.Position = Vector3.new(-TRAIL_HALF, 0, 0), Vector3.new(TRAIL_HALF, 0, 0)
	left.Parent, right.Parent = card, card
	local trail = Instance.new("Trail")
	trail.Attachment0, trail.Attachment1 = left, right
	trail.Color = ColorSequence.new(BLUE)
	trail.Transparency = NumberSequence.new(TRAIL_FADE, 1)
	trail.Lifetime = TRAIL_SECONDS
	trail.LightEmission = 0.7
	trail.FaceCamera = true
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
		card.CFrame = (level + forward * length * share) * CFrame.Angles(0, age * SPIN, TILT)
		if share < 1 then
			return
		end
		connection:Disconnect()
		-- Landed: the card goes, and its trail is left to fade out behind it.
		trail.Enabled = false
		local fade = TweenInfo.new(END_SECONDS, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		TweenService:Create(card, fade, { Transparency = 1 }):Play()
		for _, child in card:GetChildren() do
			if child:IsA("Decal") then
				TweenService:Create(child, fade, { Transparency = 1 }):Play()
			end
		end
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
