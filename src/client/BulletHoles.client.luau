-- Marks where bullets hit walls. The server sends the real landing points, spread included.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local remotes = ReplicatedStorage:WaitForChild("GunRemotes")
local impactRemote = remotes:WaitForChild("Impacts") :: RemoteEvent

local MAX_HOLES = 150
local LIFETIME_SECONDS = 20
local SIZE = Vector3.new(0.2, 0.2, 0.04)
local SURFACE_GAP = 0.02

local folder = Instance.new("Folder")
folder.Name = "BulletHoles"
folder.Parent = workspace

local holes: { BasePart } = {}

local function addHole(position: Vector3, normal: Vector3)
	local hole = Instance.new("Part")
	hole.Anchored = true
	hole.CanCollide = false
	hole.CanQuery = false
	hole.CanTouch = false
	hole.CastShadow = false
	hole.Size = SIZE
	hole.Material = Enum.Material.SmoothPlastic
	hole.Color = Color3.fromRGB(15, 15, 18)
	local front = position + normal * SURFACE_GAP
	hole.CFrame = CFrame.lookAt(front, front + normal)
	hole.Parent = folder

	table.insert(holes, hole)
	if #holes > MAX_HOLES then
		table.remove(holes, 1):Destroy()
	end
	task.delay(LIFETIME_SECONDS, function()
		local index = table.find(holes, hole)
		if index then
			table.remove(holes, index)
			hole:Destroy()
		end
	end)
end

impactRemote.OnClientEvent:Connect(function(impacts)
	for _, impact in impacts do
		addHole(impact.position, impact.normal)
	end
end)
