-- Builds the Relay map under Lune with the real Kit, using Lune's Roblox types, and checks its
-- shape: both sides match, spawns face each other, and nothing walkable is hidden in the fog.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")
local harness = require("./harness")

local describe, it, expect = harness.describe, harness.it, harness.expect
local Instance, CFrame, Vector3 = roblox.Instance, roblox.CFrame, roblox.Vector3

-- Lune has no Random, so a small generator stands in.
local Random = {}
Random.__index = Random
function Random.new(seed: number)
	return setmetatable({ state = seed % 2147483647 }, Random)
end
function Random:NextNumber(): number
	self.state = (self.state * 48271) % 2147483647
	return self.state / 2147483647
end
function Random:NextInteger(low: number, high: number): number
	return low + math.floor(self:NextNumber() * (high - low + 1))
end

-- Stands in for game, script and their children; require() reads the module named last.
local function stub(name: string): any
	return setmetatable({ name = name }, {
		__index = function(_, key)
			if key == "GetService" or key == "WaitForChild" then
				return function(_, child)
					return stub(child)
				end
			elseif key == "AddTag" then
				return function() end
			end
			return stub(key)
		end,
	})
end

local terrain = Instance.new("Folder")
local world = Instance.new("Folder")
local FILES = {
	Palette = "src/shared/Guns/Palette.luau",
	OutpostAssets = "src/shared/Guns/OutpostAssets.luau",
	Kit = "src/server/Outpost/Kit.luau",
	LightShaft = "src/server/Outpost/LightShaft.luau",
	Relay = "src/server/Outpost/Relay.luau",
}
local loaded: { [string]: any } = {}
local environment: any
-- The collision groups need PhysicsService, so a stand-in just records the group.
loaded.Collision = {
	setup = function() end,
	feetOnly = function(part: any)
		part.CollisionGroup = "WalkOnly"
	end,
}
local function load(name: string): any
	if loaded[name] == nil then
		-- A Lune Folder can't stand in for workspace, so the map is parented to one by name.
		local source = string.gsub(fs.readFile(FILES[name]), "folder.Parent = workspace", "folder.Parent = __world")
		loaded[name] = luau.load(source, { debugName = name, environment = environment })()
	end
	return loaded[name]
end
environment = {
	game = stub("game"),
	script = stub("script"),
	workspace = { Terrain = terrain },
	__world = world,
	require = function(target: any): any
		return load(rawget(target, "name"))
	end,
	Instance = Instance,
	Enum = roblox.Enum,
	Vector3 = Vector3,
	Vector2 = roblox.Vector2,
	CFrame = CFrame,
	Color3 = roblox.Color3,
	ColorSequence = roblox.ColorSequence,
	NumberSequence = roblox.NumberSequence,
	NumberSequenceKeypoint = roblox.NumberSequenceKeypoint,
	NumberRange = roblox.NumberRange,
	UDim2 = roblox.UDim2,
	Random = Random,
}

local Relay = load("Relay")
local origin = CFrame.new(-4000, 300, 0)
local built = Relay.build(origin)

local function partsOf(folder: any): { any }
	local parts = {}
	for _, item in folder:GetDescendants() do
		if item:IsA("BasePart") then
			table.insert(parts, item)
		end
	end
	return parts
end

describe("Relay map", function()
	local side1 = partsOf(built.folder.Side1)
	local side2 = partsOf(built.folder.Side2)

	it("builds both sides the same", function()
		expect(#side1).toBe(#side2)
		expect(#side1 > 1000).toBe(true)
	end)

	it("stays under a part budget", function()
		expect(#side1 + #side2 < 9000).toBe(true)
	end)

	it("mirrors every part through the centre", function()
		local turn = origin * CFrame.Angles(0, math.pi, 0) * origin:Inverse()
		local worst = 0
		for index, part in side1 do
			local expected = turn * part.CFrame
			worst = math.max(worst, (expected.Position - side2[index].CFrame.Position).Magnitude)
		end
		expect(worst < 0.01).toBe(true)
	end)

	it("puts the spawns in opposite towers, facing each other", function()
		local a, b = built.spawns[1].CFrame, built.spawns[2].CFrame
		local offset = origin:PointToObjectSpace(a.Position)
		local other = origin:PointToObjectSpace(b.Position)
		expect(offset.X < -50).toBe(true)
		expect(Vector3.new(offset.X + other.X, offset.Y - other.Y, offset.Z + other.Z).Magnitude < 0.01).toBe(true)
		expect(a.LookVector:Dot(b.Position - a.Position) > 0).toBe(true)
	end)

	it("gives each side a terminal back to the Outpost", function()
		expect(#built.terminals).toBe(2)
		expect(built.terminals[1].ObjectText).toBe("OUTPOST")
	end)

	it("keeps every walkable surface above the fall line", function()
		local lowest = math.huge
		for _, part in side1 do
			if part.CanCollide and part.Name ~= "RelaySpawn" then
				local local_ = origin:PointToObjectSpace(part.CFrame.Position)
				-- The stem and the closed floors reach into the fog but nobody stands on them.
				local wide = part.Size.X > 4 and part.Size.Z > 4
				if wide and part.Size.Y < 2 and local_.Y < lowest then
					lowest = local_.Y
				end
			end
		end
		expect(lowest > Relay.fallDepth).toBe(true)
	end)

	it("lets bullets through every invisible railing and pane", function()
		local blocking = 0
		for _, part in side1 do
			if part.Transparency == 1 and part.CanCollide and part.CollisionGroup ~= "WalkOnly" then
				local tilted = part.CFrame.UpVector.Y < 0.99
				if not tilted then
					blocking += 1
				end
			end
		end
		expect(blocking).toBe(0)
	end)

	it("keeps stairs walkable", function()
		local steepest = 0
		for _, part in side1 do
			-- Stair ramps are the invisible parts that tilt.
			if part.Transparency == 1 and part.CanCollide and part.CollisionGroup ~= "WalkOnly" then
				local up = part.CFrame.UpVector
				steepest = math.max(steepest, math.deg(math.acos(math.clamp(up.Y, -1, 1))))
			end
		end
		expect(steepest > 20).toBe(true)
		expect(steepest < 40).toBe(true)
	end)
end)
