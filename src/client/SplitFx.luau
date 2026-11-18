-- Split in the world: the copy card drops from the hand to the floor in front of its thrower, tumbling, lands flat,
-- and the double builds up out of it in a column of cyan pixels as the server stands the body up there.
--
-- Your own copy leaves the first-person hand (`release`) where the hand let go of it, as Switchback's card does;
-- everyone else's falls from the thrower's chest after the same wind-up.
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local CardCore = ReplicatedStorage:WaitForChild("CardCore")
local CardArt = require(CardCore:WaitForChild("CardArt"))
local CardLook = require(CardCore:WaitForChild("CardLook"))
local Config = require(CardCore:WaitForChild("Config"))
local Variant = require(CardCore:WaitForChild("Variant"))
local Guns = ReplicatedStorage:WaitForChild("Guns")
local CardFlourish = require(Guns:WaitForChild("CardFlourish"))
local Palette = require(Guns:WaitForChild("Palette"))

local CARD_SIZE = Vector3.new(1.4, 0.04, 2.24)
local FEET_BELOW_ROOT = 3 -- the double's root stands this far above the floor
local TUMBLE = 9 -- radians a second, end over end as it drops
local PIXELS = 26
local PIXEL_SIZE = 0.32
local BUILD_SECONDS = 0.45
local BODY_HEIGHT = 6.2
local BODY_WIDTH = 2.2
local COLORS = { Palette.DataCyan, Palette.DataCyan, Palette.SignalAcid, Palette.Bone }
local REPORT_KEPT = 1

local SplitFx = {}

local reported: { to: Vector3, tier: any, at: number }? = nil
local random = Random.new()

local function neon(size: Vector3, color: Color3): Part
	local part = Instance.new("Part")
	part.Size = size
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Material = Enum.Material.Neon
	part.Color = color
	return part
end

-- The floor under a point, or a body's height below it if there's none near.
local function floorUnder(at: Vector3): Vector3
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { workspace.CurrentCamera }
	params.RespectCanCollide = true
	local down = workspace:Raycast(at + Vector3.new(0, 1, 0), Vector3.new(0, -12, 0), params)
	return if down then down.Position else at - Vector3.new(0, FEET_BELOW_ROOT, 0)
end

-- The double builds up out of the floor: pixels rise through where its body will be, and a ring opens at its feet.
local function build(floor: Vector3)
	local ring = neon(Vector3.new(0.1, 1, 1), Palette.DataCyan)
	ring.Shape = Enum.PartType.Cylinder
	ring.CFrame = CFrame.new(floor + Vector3.new(0, 0.05, 0)) * CFrame.Angles(0, 0, math.rad(90))
	ring.Transparency = 0.3
	ring.Parent = workspace
	TweenService:Create(ring, TweenInfo.new(BUILD_SECONDS, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
		Size = Vector3.new(0.05, 7, 7),
		Transparency = 1,
	}):Play()
	Debris:AddItem(ring, BUILD_SECONDS + 0.1)
	for _ = 1, PIXELS do
		local pixel = neon(Vector3.one * PIXEL_SIZE, COLORS[random:NextInteger(1, #COLORS)])
		local x, z = random:NextNumber(-0.5, 0.5) * BODY_WIDTH, random:NextNumber(-0.5, 0.5) * BODY_WIDTH * 0.5
		local start = floor + Vector3.new(x, 0.1, z)
		local top = random:NextNumber(0.3, 1) * BODY_HEIGHT
		pixel.Position = start
		pixel.Transparency = 0.1
		pixel.Parent = workspace
		local seconds = BUILD_SECONDS * random:NextNumber(0.6, 1)
		TweenService:Create(pixel, TweenInfo.new(seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Position = start + Vector3.new(0, top, 0),
			Size = Vector3.one * 0.05,
			Transparency = 1,
		}):Play()
		Debris:AddItem(pixel, seconds + 0.1)
	end
end

-- Drops the copy from `start` to the floor under `to`, then builds the double.
local function drop(start: CFrame, startSize: Vector3, to: Vector3, tier: any)
	local floor = floorUnder(to)
	local card = Instance.new("Part")
	card.Name = "SplitCard"
	card.Anchored = true
	card.CanCollide = false
	card.CanQuery = false
	card.CanTouch = false
	card.CastShadow = false
	card.Size = startSize
	card.Material = Enum.Material.SmoothPlastic
	card.Color = Palette.Bone
	local image = if type(tier) == "string" then CardArt.base("split", CardLook.look(tier, Variant.Base)) else nil
	if image then
		local face = Instance.new("Decal")
		face.Face = Enum.NormalId.Top
		face.Texture = image
		face.Parent = card
	end
	local back = Instance.new("Decal")
	back.Face = Enum.NormalId.Bottom
	back.Texture = CardArt.HAND_BACK
	back.Parent = card
	card.CFrame = start
	card.Parent = workspace

	local from = start.Position
	local lying = CFrame.new(floor + Vector3.new(0, CARD_SIZE.Y / 2 + 0.02, 0)) * CFrame.Angles(0, random:NextNumber(0, math.pi * 2), 0)
	local fall = Config.DecoyFall
	local started = os.clock()
	local connection: RBXScriptConnection
	connection = RunService.RenderStepped:Connect(function()
		local age = os.clock() - started
		local share = math.min(age / fall, 1)
		card.Size = startSize:Lerp(CARD_SIZE, math.min(share * 2, 1))
		-- Falling: slow at first and fast at the end, tumbling, then it lands flat.
		local dropped = from:Lerp(lying.Position, share * share)
		local turned = start.Rotation:Lerp(lying.Rotation, share) * CFrame.Angles(TUMBLE * age * (1 - share), 0, 0)
		card.CFrame = CFrame.new(dropped) * turned
		if share < 1 then
			return
		end
		connection:Disconnect()
		card.CFrame = lying
		build(floor)
		-- The card glows cyan and is gone as the double stands up out of it.
		card.Material = Enum.Material.Neon
		card.Color = Palette.DataCyan
		for _, decal in card:GetChildren() do
			if decal:IsA("Decal") then
				decal.Transparency = 1
			end
		end
		TweenService:Create(card, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Transparency = 1,
			Size = Vector3.new(CARD_SIZE.X * 1.4, 0.02, CARD_SIZE.Z * 1.4),
		}):Play()
		Debris:AddItem(card, 0.4)
	end)
end

-- Someone else's copy: it drops from their chest after the wind-up.
function SplitFx.throw(from: Vector3, to: Vector3, tier: any)
	task.delay(CardFlourish.SPLIT_RELEASE, drop, CFrame.lookAt(from, to), CARD_SIZE * 0.5, to, tier)
end

function SplitFx.report(to: Vector3, tier: any)
	reported = { to = to, tier = tier, at = os.clock() }
end

function SplitFx.release(card: CFrame, size: Vector3, look: CFrame)
	local known = reported
	reported = nil
	if known and os.clock() - known.at <= REPORT_KEPT then
		drop(card, size, known.to, known.tier)
	else
		-- Late word from the server: it lands in front of you anyway, and the double still comes.
		local flat = Vector3.new(look.LookVector.X, 0, look.LookVector.Z)
		local way = if flat.Magnitude > 0.01 then flat.Unit else Vector3.zAxis
		drop(card, size, look.Position + way * Config.DecoyAhead, nil)
	end
end

return SplitFx
