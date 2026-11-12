-- The trail a sliding body leaves where its hand drags the ground: orange sparks and a little dust, more of both
-- the faster it's going. Each body that slides gets one small unseen part carrying the two emitters; it is moved
-- to the hand's spot on the ground every frame the slide is drawn and switched off when it isn't.
local SPARK_COLOR = Color3.fromRGB(255, 150, 60) -- the maps' orange
local SPARK_GLOW = Color3.fromRGB(255, 230, 190)
local DUST_COLOR = Color3.fromRGB(150, 160, 165)
local FULL_SPEED = 28 -- studs a second that gives the full trail
local SPARKS_MOST = 70 -- a second
local DUST_MOST = 26

local SlideSparks = {}

type Trail = { part: Part, sparks: ParticleEmitter, dust: ParticleEmitter }

local trails: { [Model]: Trail } = {}

local function build(): Trail
	local part = Instance.new("Part")
	part.Name = "SlideSparks"
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Transparency = 1
	part.Size = Vector3.new(0.3, 0.1, 0.3)
	part.Parent = workspace

	local sparks = Instance.new("ParticleEmitter")
	sparks.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	sparks.Color = ColorSequence.new(SPARK_GLOW, SPARK_COLOR)
	sparks.LightEmission = 1
	sparks.LightInfluence = 0
	sparks.Lifetime = NumberRange.new(0.12, 0.32)
	sparks.Speed = NumberRange.new(6, 16)
	sparks.SpreadAngle = Vector2.new(35, 35)
	sparks.Acceleration = Vector3.new(0, -45, 0)
	sparks.Drag = 2
	sparks.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.22), NumberSequenceKeypoint.new(1, 0) })
	sparks.EmissionDirection = Enum.NormalId.Back -- thrown out behind, the part faces the way the body is going
	sparks.Rate = 0
	sparks.Parent = part

	local dust = Instance.new("ParticleEmitter")
	dust.Texture = "rbxasset://textures/particles/smoke_main.dds"
	dust.Color = ColorSequence.new(DUST_COLOR)
	dust.LightEmission = 0.1
	dust.Lifetime = NumberRange.new(0.3, 0.6)
	dust.Speed = NumberRange.new(1, 4)
	dust.SpreadAngle = Vector2.new(60, 60)
	dust.Drag = 4
	dust.Rotation = NumberRange.new(0, 360)
	dust.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 1.8) })
	dust.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 1) })
	dust.EmissionDirection = Enum.NormalId.Top
	dust.Rate = 0
	dust.Parent = part
	return { part = part, sparks = sparks, dust = dust }
end

-- at is the spot on the ground, going the unit direction the body is sliding, speed how fast.
function SlideSparks.show(character: Model, at: Vector3, going: Vector3, speed: number)
	local trail = trails[character]
	if not trail then
		trail = build()
		trails[character] = trail
	end
	local much = math.clamp(speed / FULL_SPEED, 0, 1)
	trail.part.CFrame = CFrame.lookAt(at, at + going)
	trail.sparks.Rate = SPARKS_MOST * much * much
	trail.dust.Rate = DUST_MOST * much
end

function SlideSparks.hide(character: Model)
	local trail = trails[character]
	if trail then
		trail.sparks.Rate = 0
		trail.dust.Rate = 0
	end
end

function SlideSparks.remove(character: Model)
	local trail = trails[character]
	if trail then
		trail.part:Destroy()
		trails[character] = nil
	end
end

return SlideSparks
