-- A grey room for testing movement. It runs on every server, so Team Test and
local Palette = require(game:GetService("ReplicatedStorage"):WaitForChild("Guns"):WaitForChild("Palette"))
-- published playtests have a floor. Remove it when real arenas arrive.

local GREY = Color3.fromRGB(150, 150, 155)
local DARK = Palette.DeepNavy

local room = Instance.new("Folder")
room.Name = "TestRoom"

local function block(name: string, className: string, size: Vector3, cframe: CFrame, color: Color3?): BasePart
	local part = Instance.new(className) :: BasePart
	part.Name = name
	part.Anchored = true
	part.Size = size
	part.CFrame = cframe
	part.Color = color or GREY
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = room
	return part
end

local function ramp(name: string, degrees: number, x: number)
	local run = 40
	local rise = run * math.tan(math.rad(degrees))
	block(name, "WedgePart", Vector3.new(16, rise, run), CFrame.new(x, rise / 2, -50), DARK)
end

block("Floor", "Part", Vector3.new(200, 2, 200), CFrame.new(0, -1, 0))
ramp("Ramp15", 15, -70)
ramp("Ramp30", 30, -45)

block("WallLong", "Part", Vector3.new(40, 12, 2), CFrame.new(50, 6, -50), DARK)
block("WallShort", "Part", Vector3.new(2, 12, 24), CFrame.new(31, 6, -39), DARK)

block("Ledge", "Part", Vector3.new(16, 4, 16), CFrame.new(-5, 2, -50), DARK)

block("GapNear", "Part", Vector3.new(16, 6, 30), CFrame.new(60, 3, 25), DARK)
block("GapFar", "Part", Vector3.new(16, 6, 30), CFrame.new(60, 3, 67), DARK)

local spawnPad = Instance.new("SpawnLocation")
spawnPad.Name = "Spawn"
spawnPad.Anchored = true
spawnPad.Size = Vector3.new(8, 1, 8)
spawnPad.CFrame = CFrame.new(0, 0.5, 40)
spawnPad.Color = DARK
spawnPad.Duration = 0
spawnPad.Parent = room

room.Parent = workspace
