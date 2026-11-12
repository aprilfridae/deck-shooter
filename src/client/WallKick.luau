-- The burst a wall jump leaves on the wall: a puff of concrete dust, chips flung off it, and a spit of sparks,
-- all thrown out from the wall where the feet hit it. River asked for particles and effects on the wall jump
-- (2026-11-11). Only you see your own; one set of emitters serves every jump.
local DUST = 14
local CHIPS = 10
local SPARKS = 16
local DUST_COLOR = Color3.fromRGB(150, 160, 165)
local CHIP_COLOR = Color3.fromRGB(90, 98, 104)
local SPARK_COLOR = Color3.fromRGB(255, 150, 60) -- the maps' orange
local SPARK_GLOW = Color3.fromRGB(255, 230, 190)

local WallKick = {}

local anchor: Part? = nil
local dust: ParticleEmitter, chips: ParticleEmitter, sparks: ParticleEmitter

local function sizes(from: number, to: number): NumberSequence
	return NumberSequence.new({ NumberSequenceKeypoint.new(0, from), NumberSequenceKeypoint.new(1, to) })
end

local function build()
	local part = Instance.new("Part")
	part.Name = "WallKick"
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Transparency = 1
	part.Size = Vector3.new(2.5, 2.5, 0.2)
	part.Parent = workspace
	anchor = part

	dust = Instance.new("ParticleEmitter")
	dust.Texture = "rbxasset://textures/particles/smoke_main.dds"
	dust.Color = ColorSequence.new(DUST_COLOR)
	dust.LightEmission = 0.15
	dust.Lifetime = NumberRange.new(0.35, 0.7)
	dust.Speed = NumberRange.new(4, 13)
	dust.SpreadAngle = Vector2.new(65, 65)
	dust.Drag = 5
	dust.Rotation = NumberRange.new(0, 360)
	dust.RotSpeed = NumberRange.new(-60, 60)
	dust.Size = sizes(0.9, 3.4)
	dust.Transparency = sizes(0.45, 1)
	dust.EmissionDirection = Enum.NormalId.Front
	dust.Rate = 0
	dust.Parent = part

	chips = Instance.new("ParticleEmitter")
	chips.Texture = "rbxasset://textures/particles/smoke_main.dds"
	chips.Color = ColorSequence.new(CHIP_COLOR)
	chips.LightEmission = 0
	chips.Lifetime = NumberRange.new(0.4, 0.8)
	chips.Speed = NumberRange.new(10, 26)
	chips.SpreadAngle = Vector2.new(50, 50)
	chips.Acceleration = Vector3.new(0, -60, 0)
	chips.Drag = 1.5
	chips.Rotation = NumberRange.new(0, 360)
	chips.RotSpeed = NumberRange.new(-500, 500)
	chips.Size = sizes(0.22, 0.12)
	chips.Transparency = sizes(0, 1)
	chips.EmissionDirection = Enum.NormalId.Front
	chips.Rate = 0
	chips.Parent = part

	sparks = Instance.new("ParticleEmitter")
	sparks.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	sparks.Color = ColorSequence.new(SPARK_GLOW, SPARK_COLOR)
	sparks.LightEmission = 1
	sparks.LightInfluence = 0
	sparks.Lifetime = NumberRange.new(0.15, 0.4)
	sparks.Speed = NumberRange.new(18, 44)
	sparks.SpreadAngle = Vector2.new(40, 40)
	sparks.Acceleration = Vector3.new(0, -40, 0)
	sparks.Drag = 3
	sparks.Size = sizes(0.3, 0)
	sparks.EmissionDirection = Enum.NormalId.Front
	sparks.Rate = 0
	sparks.Parent = part
end

-- at is the spot on the wall, away the unit direction out of it.
function WallKick.play(at: Vector3, away: Vector3)
	if not anchor or not anchor.Parent then
		build()
	end
	local part = anchor :: Part
	part.CFrame = CFrame.lookAt(at + away * 0.15, at + away)
	dust:Emit(DUST)
	chips:Emit(CHIPS)
	sparks:Emit(SPARKS)
end

return WallKick
