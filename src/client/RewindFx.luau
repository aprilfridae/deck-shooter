-- Rewind in the world and on your screen. Everyone sees a line of cyan afterimages from where the player was to
-- where they went back to, fading from the far end, with a ring at each end. Your own wind-up drains the colour
-- from the world and tints it cyan, more and more until the snap, then it comes back with a jolt of brightness.
local Debris = game:GetService("Debris")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Palette = require(ReplicatedStorage:WaitForChild("Guns"):WaitForChild("Palette"))

local GHOSTS = 7 -- afterimages along the way
local GHOST_SIZE = Vector3.new(2, 5.2, 1)
local GHOST_SECONDS = 0.5
local GHOST_GAP = 0.035 -- seconds between each one fading, from the start of the path back
local RING_SECONDS = 0.35
local CYAN = Palette.DataCyan
local SNAP_BACK = 0.3 -- seconds the screen takes to come back after the snap
local CLEAR_OF_EYE = 9 -- studs: your own afterimages stop this far short of your camera, or one fills the screen

local RewindFx = {}

local function neon(size: Vector3): Part
	local part = Instance.new("Part")
	part.Size = size
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Material = Enum.Material.Neon
	part.Color = CYAN
	return part
end

local function ring(at: Vector3)
	local part = neon(Vector3.new(0.1, 1.5, 1.5))
	part.Shape = Enum.PartType.Cylinder
	part.CFrame = CFrame.new(at - Vector3.new(0, 2.8, 0)) * CFrame.Angles(0, 0, math.rad(90))
	part.Transparency = 0.2
	part.Parent = workspace
	TweenService:Create(part, TweenInfo.new(RING_SECONDS, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
		Size = Vector3.new(0.05, 9, 9),
		Transparency = 1,
	}):Play()
	Debris:AddItem(part, RING_SECONDS + 0.1)
end

-- The body's shape, as glowing pieces placed from its root: a copy of each part you can see. A plain block for a
-- body that isn't there.
type Shape = { { size: Vector3, offset: CFrame, part: BasePart? } }

local function shapeOf(body: Model?): Shape
	local root = body and body:FindFirstChild("HumanoidRootPart")
	if not body or not root or not root:IsA("BasePart") then
		return { { size = GHOST_SIZE, offset = CFrame.identity } }
	end
	local shape: Shape = {}
	for _, part in body:GetDescendants() do
		if part:IsA("BasePart") and part ~= root and part.Transparency < 1 and part.Size.Magnitude > 0.3 then
			table.insert(shape, { size = part.Size, offset = root.CFrame:ToObjectSpace(part.CFrame), part = part })
		end
	end
	return shape
end

local function ghostPiece(piece: { size: Vector3, offset: CFrame, part: BasePart? }): BasePart
	local source = piece.part
	local ghost: BasePart
	if source and source:IsA("MeshPart") then
		ghost = source:Clone()
		ghost:ClearAllChildren()
		;(ghost :: MeshPart).TextureID = ""
	else
		ghost = neon(piece.size)
	end
	ghost.Anchored = true
	ghost.CanCollide = false
	ghost.CanQuery = false
	ghost.CanTouch = false
	ghost.CastShadow = false
	ghost.Material = Enum.Material.Neon
	ghost.Color = CYAN
	ghost.LocalTransparencyModifier = 0
	return ghost
end

-- The jump back, from `from` to `to` (both where the body's root was). body is who went back, for the afterimages'
-- shape; own is whether it was you, whose camera is at `to`, so no afterimage is drawn over your eyes.
function RewindFx.trail(from: Vector3, to: Vector3, body: Model?, own: boolean?)
	ring(from)
	ring(to)
	local way = to - from
	local flat = Vector3.new(way.X, 0, way.Z)
	-- They face the way they were going as they went back: toward where they went.
	local facing = if flat.Magnitude > 0.1 then CFrame.lookAt(Vector3.zero, flat) else CFrame.identity
	local shape = shapeOf(body)
	-- Your camera is still where you were when this arrives, and lands at `to` a frame later: keep clear of there.
	local eye = to
	for index = 1, GHOSTS do
		local share = (index - 1) / (GHOSTS - 1)
		local at = CFrame.new(from:Lerp(to, share)) * facing
		if own and (at.Position - eye).Magnitude < CLEAR_OF_EYE then
			continue
		end
		local transparency = 0.72 + 0.2 * (1 - share) -- neon reads bright: faint is enough
		-- The far end (where they left) goes first, so the line seems to run into them.
		local info = TweenInfo.new(GHOST_SECONDS, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, GHOST_GAP * (index - 1))
		local holder = Instance.new("Model")
		holder.Name = "RewindGhost"
		for _, piece in shape do
			local ghost = ghostPiece(piece)
			ghost.CFrame = at * piece.offset
			ghost.Transparency = transparency
			ghost.Parent = holder
			TweenService:Create(ghost, info, { Transparency = 1 }):Play()
		end
		holder.Parent = workspace
		Debris:AddItem(holder, GHOST_SECONDS + GHOST_GAP * GHOSTS + 0.1)
	end
end

-- Your own screen through the wind-up: `seconds` until the snap.
local grade: ColorCorrectionEffect? = nil
local windFrom = 0
local snapAt = 0

function RewindFx.windUp(seconds: number)
	if not grade or not grade.Parent then
		local effect = Instance.new("ColorCorrectionEffect")
		effect.Name = "Rewind"
		effect.Parent = Lighting
		grade = effect
	end
	windFrom = os.clock()
	snapAt = windFrom + seconds
end

RunService.RenderStepped:Connect(function()
	local effect = grade
	if not effect then
		return
	end
	local now = os.clock()
	if now > snapAt + SNAP_BACK then
		effect.Saturation, effect.Brightness, effect.Contrast = 0, 0, 0
		effect.TintColor = Color3.new(1, 1, 1)
		return
	end
	if now <= snapAt then
		local share = (now - windFrom) / math.max(snapAt - windFrom, 1e-3)
		share = share * share
		effect.Saturation = -0.7 * share
		effect.Contrast = 0.15 * share
		effect.Brightness = 0
		effect.TintColor = Color3.new(1, 1, 1):Lerp(Color3.fromRGB(170, 240, 255), share)
	else
		local back = 1 - (now - snapAt) / SNAP_BACK
		effect.Saturation = -0.7 * back
		effect.Contrast = 0.15 * back
		effect.Brightness = 0.25 * back
		effect.TintColor = Color3.new(1, 1, 1):Lerp(Color3.fromRGB(170, 240, 255), back)
	end
end)

return RewindFx
