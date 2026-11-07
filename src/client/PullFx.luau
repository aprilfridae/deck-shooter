-- Draws a pack opening's particles over the screen. PullParticles says how each rarity moves.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local PullParticles = require(ReplicatedStorage:WaitForChild("CardCore"):WaitForChild("PullParticles"))
local Palette = require(ReplicatedStorage:WaitForChild("Guns"):WaitForChild("Palette"))

local LAYER = 15 -- over the screen's flash, under the buttons

local PullFx = {}

local function piece(parent: Instance, style: any, particle: any, height: number): Frame
	local frame = Instance.new("Frame")
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.BackgroundColor3 = Palette[particle.colour]
	frame.BorderSizePixel = 0
	frame.Size = UDim2.fromOffset(style.width * height, style.length * height)
	if style.alongTravel then
		frame.Rotation = math.deg(math.atan2(particle.vy, particle.vx)) + 90
	end
	frame.ZIndex = LAYER
	frame.Parent = parent
	return frame
end

-- share is how much of the style's full burst to make, from the point x, y in pixels.
function PullFx.burst(parent: Frame, style: any, share: number, x: number, y: number)
	local height = parent.AbsoluteSize.Y
	local random = Random.new()
	local particles = PullParticles.spawn(style, share, function(low: number, high: number): number
		return random:NextNumber(low, high)
	end)
	local frames = {}
	local longest = 0
	for index, particle in particles do
		frames[index] = piece(parent, style, particle, height)
		frames[index].Position = UDim2.fromOffset(x + particle.x * height, y + particle.y * height)
		longest = math.max(longest, particle.life)
	end

	local elapsed = 0
	local connection: RBXScriptConnection
	local function clear()
		connection:Disconnect()
		for _, frame in frames do
			frame:Destroy()
		end
	end
	connection = RunService.RenderStepped:Connect(function(dt: number)
		elapsed += dt
		if not parent.Parent or elapsed >= longest then
			clear()
			return
		end
		for index, particle in particles do
			local across, down = PullParticles.position(style, particle, elapsed)
			local frame = frames[index]
			frame.Position = UDim2.fromOffset(x + across * height, y + down * height)
			frame.BackgroundTransparency = PullParticles.fade(particle, elapsed)
			if style.spin then
				frame.Rotation = elapsed * style.spin * particle.turn * 180 / math.pi
			end
		end
	end)
end

return PullFx
