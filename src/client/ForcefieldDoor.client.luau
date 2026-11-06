-- Draws the glitchy forcefield in the Outpost's doorway: a sheet of tiny spheres, each its own
-- shade of blue, with bands tearing sideways, held in stop-motion like the arms. A sphere that
-- jumps between held frames leaves a fading streak, the way the gun smears. The server only marks
-- where it goes. It never collides.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Guns = ReplicatedStorage:WaitForChild("Guns")
local ArmPose = require(Guns:WaitForChild("ArmPose"))
local BodyStyle = require(Guns:WaitForChild("BodyStyle"))
local Forcefield = require(Guns:WaitForChild("Forcefield"))
local Palette = require(Guns:WaitForChild("Palette"))

local TAG = "OutpostForcefield"
local FPS = 12
local SPACING = 0.24 -- studs between spheres
local DOT = 0.12 -- studs across
local TOUCH_MARGIN = 2 -- how far past the opening's edges a body still counts
local NEAR_CAMERA = 180 -- past this nobody can see it move
local SMEAR_MIN = 0.2 -- studs a cell has to jump to leave a streak
local SMEAR_TRANSPARENCY = 0.6
local SMEAR_COUNT = 600 -- streaks at once

-- Repeats weight the mix: mostly plain cyan.
local CYAN = Palette.DataCyan
local LIGHT = CYAN:Lerp(Palette.Bone, 0.55)
local DARK = CYAN:Lerp(Palette.DeepNavy, 0.55)
local SHADES = { CYAN, CYAN, CYAN, CYAN, LIGHT, LIGHT, DARK, DARK, DARK, Palette.DeepNavy }
local SHADE_FRAMES = 14 -- held frames before a sphere picks a new shade

-- Noise is -1 to 1, so a higher chance here is a rarer glitch.
local TEAR_ROWS = 5 -- rows that tear sideways together
local TEAR_CHANCE = 0.72
local IDLE_TEAR = 0.3
local GLITCH_TEAR = 1.8
local SHARD_CHANCE = 0.92 -- cells that jut out of the sheet
local IDLE_SHARD = 0.3
local GLITCH_SHARD = 1.1
local IDLE_RIPPLE = 0.02
local GLITCH_RIPPLE = 0.25
local GLOW = 2
local GLITCH_GLOW = 5

type Cell = {
	part: BasePart,
	x: number,
	y: number,
	row: number,
	shade: Color3,
	phase: number,
	delay: number,
	pose: Vector3,
}
type Smear = { part: BasePart, spot: Vector3, trail: Vector3 }
type Field = {
	anchor: BasePart,
	folder: Folder,
	light: PointLight,
	cells: { Cell },
	parts: { BasePart },
	pool: { BasePart },
	smears: { Smear },
	smearAt: number,
	state: Forcefield.State,
	centreX: number,
	centreY: number,
	frame: number,
}

local fields: { Field } = {}

local function noise(a: number, b: number): number
	local value = math.sin(a * 12.9898 + b * 78.233) * 43758.5453
	return (value - math.floor(value)) * 2 - 1
end

local function makeDot(folder: Folder): BasePart
	local part = Instance.new("Part")
	part.Shape = Enum.PartType.Ball
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Material = Enum.Material.Neon
	part.Color = CYAN
	part.Size = Vector3.one * DOT
	part.Parent = folder
	return part
end

-- A ball stays round whatever its size, so a streak is a stretched sphere mesh.
local function makeStreak(folder: Folder, at: CFrame): BasePart
	local part = makeDot(folder)
	part.Shape = Enum.PartType.Block
	part.Transparency = 1
	part.CFrame = at
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = part
	return part
end

local function build(anchor: BasePart)
	local columns = math.floor(anchor.Size.X / SPACING)
	local rows = math.floor(anchor.Size.Y / SPACING)
	local width, height = anchor.Size.X / columns, anchor.Size.Y / rows
	local folder = Instance.new("Folder")
	folder.Name = "Cells"
	local light = Instance.new("PointLight")
	light.Color = Palette.DataCyan
	light.Range = 24
	light.Brightness = GLOW
	light.Parent = anchor
	local field: Field = {
		anchor = anchor,
		folder = folder,
		light = light,
		cells = {},
		parts = {},
		pool = {},
		smears = {},
		smearAt = 0,
		state = Forcefield.new(),
		centreX = 0,
		centreY = 0,
		frame = -1,
	}
	for row = 1, rows do
		for column = 1, columns do
			local part = makeDot(folder)
			table.insert(field.parts, part)
			table.insert(field.cells, {
				part = part,
				x = (column - 0.5) * width - anchor.Size.X / 2,
				y = (row - 0.5) * height - anchor.Size.Y / 2,
				row = row,
				shade = CYAN,
				phase = (noise(11, #field.cells) + 1) / 2 * SHADE_FRAMES,
				delay = (noise(7, #field.cells) + 1) / 2,
				pose = Vector3.zero,
			})
		end
	end
	for index = 1, SMEAR_COUNT do
		field.pool[index] = makeStreak(folder, anchor.CFrame)
	end
	folder.Parent = anchor
	table.insert(fields, field)
end

-- Streamed out and back in, the same marker arrives again.
local function remove(anchor: Instance)
	for index, field in fields do
		if field.anchor == anchor then
			field.folder:Destroy()
			field.light:Destroy()
			table.remove(fields, index)
			return
		end
	end
end

-- The body nearest the field's plane and inside the opening, as a point on the field.
local function nearestBody(field: Field): Vector3?
	local anchor = field.anchor
	local best: Vector3? = nil
	for _, player in Players:GetPlayers() do
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if root then
			local spot = anchor.CFrame:PointToObjectSpace(root.Position)
			local inside = math.abs(spot.X) < anchor.Size.X / 2 + TOUCH_MARGIN and math.abs(spot.Y) < anchor.Size.Y / 2 + TOUCH_MARGIN
			if inside and (not best or math.abs(spot.Z) < math.abs(best.Z)) then
				best = spot
			end
		end
	end
	return best
end

local function clearSmears(field: Field)
	for _, smear in field.smears do
		smear.part.Transparency = 1
	end
	table.clear(field.smears)
end

-- Each streak runs from the sphere's new spot back to its last one, and shrinks away.
local function drawSmears(field: Field, now: number)
	local fade = 1 - (now - field.smearAt) / BodyStyle.smearTime
	if fade <= 0 then
		clearSmears(field)
		return
	end
	for _, smear in field.smears do
		local part = smear.part
		part.Size = Vector3.new(DOT, DOT, math.max(smear.trail.Magnitude * fade, DOT))
		part.CFrame = CFrame.lookAt(smear.spot + smear.trail * fade / 2, smear.spot + smear.trail)
		part.Transparency = SMEAR_TRANSPARENCY
	end
end

local function draw(field: Field, frame: number, now: number)
	clearSmears(field)
	local state = field.state
	local tear = IDLE_TEAR + GLITCH_TEAR * state.glitch
	local shard = IDLE_SHARD + GLITCH_SHARD * state.glitch
	local ripple = IDLE_RIPPLE + GLITCH_RIPPLE * state.glitch
	local origin = field.anchor.CFrame
	local tears = {}
	local frames = table.create(#field.cells)
	for index, cell in field.cells do
		local band = math.ceil(cell.row / TEAR_ROWS)
		local tearNoise = tears[band]
		if not tearNoise then
			tearNoise = noise(frame, band)
			tears[band] = tearNoise
		end
		local shift = if math.abs(tearNoise) > TEAR_CHANCE then tear * tearNoise else 0
		local twitch = noise(frame, index + 1000)
		local out = twitch * ripple + (if math.abs(twitch) > SHARD_CHANCE then shard * twitch else 0)
		local awayX, awayY, bend = Forcefield.piece(state, cell.x, cell.y, field.centreX, field.centreY, cell.delay)
		local spot = origin * CFrame.new(cell.x + shift + awayX, cell.y + awayY, bend + out)
		frames[index] = spot
		local pose = Vector3.new(awayX, awayY, bend)
		local moved = cell.pose - pose
		cell.pose = pose
		if moved.Magnitude > SMEAR_MIN and #field.smears < SMEAR_COUNT then
			local part = field.pool[#field.smears + 1]
			part.Color = cell.shade
			table.insert(field.smears, { part = part, spot = spot.Position, trail = origin:VectorToWorldSpace(moved) })
		end

		-- Each sphere changes at its own moment, so the sheet never pulses as one.
		local pick = noise(math.floor((frame + cell.phase) / SHADE_FRAMES), index + 3000)
		local shade = SHADES[math.floor((pick + 1) / 2 * #SHADES) + 1] or CYAN
		if shade ~= cell.shade then
			cell.shade = shade
			cell.part.Color = shade
		end
	end
	workspace:BulkMoveTo(field.parts, frames, Enum.BulkMoveMode.FireCFrameChanged)
	field.light.Brightness = GLOW + GLITCH_GLOW * state.glitch
	field.smearAt = now
end

RunService.Heartbeat:Connect(function(dt)
	local camera = workspace.CurrentCamera
	local now = os.clock()
	local frame = ArmPose.step(now, FPS)
	for _, field in fields do
		local body = nearestBody(field)
		Forcefield.step(field.state, body and body.Z, dt)
		if body and not field.state.released then
			field.centreX, field.centreY = body.X, body.Y
		end
		if frame ~= field.frame then
			field.frame = frame
			if (camera.CFrame.Position - field.anchor.Position).Magnitude < NEAR_CAMERA then
				draw(field, frame, now)
			end
		end
		if #field.smears > 0 then
			drawSmears(field, now)
		end
	end
end)

for _, anchor in CollectionService:GetTagged(TAG) do
	build(anchor)
end
CollectionService:GetInstanceAddedSignal(TAG):Connect(build)
CollectionService:GetInstanceRemovedSignal(TAG):Connect(remove)
