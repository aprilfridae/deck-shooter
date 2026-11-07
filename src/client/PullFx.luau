-- Draws the burst when a pack's cards turn over. PullParticles says how far and how fast it goes.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local PullParticles = require(ReplicatedStorage:WaitForChild("CardCore"):WaitForChild("PullParticles"))

local LAYER = 15 -- over the screen's flash, under the buttons
local RING_THICKNESS = 0.02 -- of the screen's height, shrinking as the ring spreads
local DARK = 0.3 -- colours darker than this don't show against the dimmed world

local PullFx = {}

local function brightness(color: Color3): number
	return (color.R + color.G + color.B) / 3
end

local function shard(parent: Instance, particle: any, colour: Color3, height: number): Frame
	local frame = Instance.new("Frame")
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.BackgroundColor3 = colour
	frame.BorderSizePixel = 0
	frame.Size = UDim2.fromOffset(particle.width * height, particle.length * height)
	frame.ZIndex = LAYER
	frame.Parent = parent
	return frame
end

local function ring(parent: Instance, colour: Color3): (Frame, UIStroke)
	local frame = Instance.new("Frame")
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.BackgroundTransparency = 1
	frame.ZIndex = LAYER
	frame.Visible = false
	frame.Parent = parent
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = frame
	local stroke = Instance.new("UIStroke")
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Color = colour
	stroke.Parent = frame
	return frame, stroke
end

-- colours are the pack's two. x and y are in pixels.
function PullFx.burst(parent: Frame, power: number, colours: { Color3 }, x: number, y: number)
	local height = parent.AbsoluteSize.Y
	local random = Random.new()
	local particles = PullParticles.spawn(power, function(low: number, high: number): number
		return random:NextNumber(low, high)
	end)
	local shards = {}
	local longest = PullParticles.RING_GAP + PullParticles.RING_TIME
	for index, particle in particles do
		local frame = shard(parent, particle, if particle.first then colours[1] else colours[2], height)
		frame.Position = UDim2.fromOffset(x, y)
		shards[index] = frame
		longest = math.max(longest, particle.life)
	end

	local bright = if brightness(colours[1]) > brightness(colours[2]) then colours[1] else colours[2]
	local other = if bright == colours[1] then colours[2] else colours[1]
	local rings = {}
	for index, colour in { bright, if brightness(other) > DARK then other else bright } do
		local frame, stroke = ring(parent, colour)
		rings[index] = { frame = frame, stroke = stroke, delay = (index - 1) * PullParticles.RING_GAP }
	end
	local reach = PullParticles.ringReach(power) * height * 2

	local elapsed = 0
	local connection: RBXScriptConnection
	connection = RunService.RenderStepped:Connect(function(dt: number)
		elapsed += dt
		if not parent.Parent or elapsed >= longest then
			connection:Disconnect()
			for _, frame in shards do
				frame:Destroy()
			end
			for _, item in rings do
				item.frame:Destroy()
			end
			return
		end
		for index, particle in particles do
			local across, down = PullParticles.position(particle, elapsed)
			local frame = shards[index]
			frame.Position = UDim2.fromOffset(x + across * height, y + down * height)
			frame.Rotation = math.deg(particle.angle + particle.spin * elapsed)
			frame.BackgroundTransparency = PullParticles.fade(particle, elapsed)
		end
		for _, item in rings do
			local spread = math.clamp((elapsed - item.delay) / PullParticles.RING_TIME, 0, 1)
			local left = 1 - spread
			local size = reach * (1 - left * left * left)
			item.frame.Visible = spread > 0 and spread < 1
			item.frame.Position = UDim2.fromOffset(x, y)
			item.frame.Size = UDim2.fromOffset(size, size)
			item.stroke.Thickness = RING_THICKNESS * height * left
			item.stroke.Transparency = spread
		end
	end)
end

return PullFx
