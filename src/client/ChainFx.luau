-- Draws Switchback's chain: a hook on a line of links that flies out, swings and hangs like a thrown chain, pulls
-- tight on its target, then breaks apart (a hit) or winds back in (a miss). The shape is ChainShape's; this
-- builds the parts and moves them. Dark metal links alternate with thin glowing ones, for the technology feel.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local ChainShape = require(ReplicatedStorage:WaitForChild("CardCore"):WaitForChild("ChainShape"))
local Palette = require(ReplicatedStorage:WaitForChild("Guns"):WaitForChild("Palette"))

local METAL_SIZE = Vector3.new(0.5, 0.16, ChainShape.LINK * 1.2) -- links overlap a little, like real ones
local GLOW_SIZE = Vector3.new(0.14, 0.42, ChainShape.LINK * 1.1)
local HOOK_SIZE = Vector3.new(0.9, 0.9, 1.6)
local HOOK_LIGHT = 12 -- studs
local BURST = 5 -- studs a link flies outward as the chain breaks apart
local QUARTER = CFrame.Angles(0, 0, math.rad(90))

local ChainFx = {}

local function part(folder: Instance, size: Vector3, glowing: boolean): Part
	local made = Instance.new("Part")
	made.Anchored = true
	made.CanCollide = false
	made.CanQuery = false
	made.CanTouch = false
	made.CastShadow = false
	made.Size = size
	made.Material = if glowing then Enum.Material.Neon else Enum.Material.Metal
	made.Color = if glowing then Palette.DataCyan else Palette.DeepNavy
	made.Transparency = 1
	made.Parent = folder
	return made
end

-- Throws a chain from one point to another. `hit` is whether it caught someone.
function ChainFx.throw(from: Vector3, to: Vector3, hit: boolean)
	local length = (to - from).Magnitude
	if length < 1 then
		return
	end
	local forward = (to - from).Unit
	-- Sideways and up, square to the throw. Thrown straight up or down there is no "up", so use another axis.
	local up = if math.abs(forward.Y) > 0.95 then Vector3.xAxis else Vector3.yAxis
	local side = forward:Cross(up).Unit
	up = side:Cross(forward).Unit

	local folder = Instance.new("Folder")
	folder.Name = "SwitchbackChain"
	folder.Parent = workspace
	local links: { Part } = {}
	for index = 1, ChainShape.links(length) do
		links[index] = part(folder, if index % 2 == 0 then GLOW_SIZE else METAL_SIZE, index % 2 == 0)
	end
	local hook = part(folder, HOOK_SIZE, true)
	local light = Instance.new("PointLight")
	light.Color = Palette.DataCyan
	light.Range = HOOK_LIGHT
	light.Parent = hook

	local function point(distance: number, reached: number, age: number): Vector3
		local swing, hang = ChainShape.offset(if reached > 0 then distance / reached else 0, age, length)
		return from + forward * distance + side * swing + up * hang
	end

	local started = os.clock()
	local connection: RBXScriptConnection
	connection = RunService.RenderStepped:Connect(function()
		local age = os.clock() - started
		if age >= ChainShape.life(length) then
			connection:Disconnect()
			folder:Destroy()
			return
		end
		local reached = ChainShape.reached(age, length, hit)
		local fade = ChainShape.fade(age, length, hit)
		local out = ChainShape.links(reached)
		local parts, frames = {}, {}

		local head = point(reached, reached, age)
		hook.Transparency = if reached > 0 then fade else 1
		light.Brightness = 2 * (1 - fade)
		table.insert(parts, hook)
		table.insert(frames, CFrame.lookAt(head, head + forward) * CFrame.Angles(0, 0, age * 14))

		-- Links trail back from the head, so they come out of the hand one after another.
		for index, link in links do
			local shown = index <= out
			link.Transparency = if shown then fade else 1
			if shown then
				local distance = reached - index * ChainShape.LINK
				local here = point(distance, reached, age)
				local ahead = point(distance + ChainShape.LINK, reached, age)
				local frame = CFrame.lookAt(here, ahead)
				if index % 4 >= 2 then
					frame *= QUARTER -- every other pair is turned, as chain links are
				end
				if fade > 0 then
					-- Breaking apart: each link drifts outward its own way.
					local angle = index * 2.4
					frame += (side * math.cos(angle) + up * math.sin(angle)) * BURST * fade * fade
				end
				table.insert(parts, link)
				table.insert(frames, frame)
			end
		end
		workspace:BulkMoveTo(parts, frames, Enum.BulkMoveMode.FireCFrameChanged)
	end)
end

return ChainFx
