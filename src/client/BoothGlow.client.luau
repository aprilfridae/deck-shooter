-- Flickers each of the Outpost's stalls when the player walks up to it. Each player sees
-- their own, so this runs on the client.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local BoothGlow = require(ReplicatedStorage:WaitForChild("Guns"):WaitForChild("BoothGlow"))

local random = Random.new()
local stalls: { [string]: any } = {}

local function paint(entry: any, level: number)
	if entry.part:IsA("Light") then
		entry.part.Brightness = entry.base * BoothGlow.LIGHT_SHARE * level
	else
		entry.part.Transparency = 1 - BoothGlow.NEON_SHARE * level
	end
end

local function add(part: Instance)
	local name = part:GetAttribute("FlickerStall")
	if type(name) ~= "string" then
		return
	end
	local stall = stalls[name]
	if not stall then
		stall = { entries = {}, sum = Vector3.zero, count = 0, near = false, startedAt = nil, nextAt = 0 }
		stalls[name] = stall
	end
	local entry = { part = part, base = if part:IsA("Light") then part.Brightness else 0 }
	table.insert(stall.entries, entry)
	paint(entry, 1)
	if part:IsA("BasePart") then
		stall.sum += part.Position
		stall.count += 1
	end
end

CollectionService:GetInstanceAddedSignal(BoothGlow.TAG):Connect(add)
for _, part in CollectionService:GetTagged(BoothGlow.TAG) do
	add(part)
end

local function isNear(stall: any): boolean
	local character = Players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root or stall.count == 0 then
		return false
	end
	return (root.Position - stall.sum / stall.count).Magnitude < BoothGlow.RANGE
end

RunService.Heartbeat:Connect(function()
	local now = os.clock()
	for _, stall in stalls do
		local near = isNear(stall)
		if not stall.startedAt and near and (not stall.near or now >= stall.nextAt) then
			stall.startedAt = now
			stall.nextAt = now + BoothGlow.TOTAL + random:NextNumber(BoothGlow.REPEAT_LOW, BoothGlow.REPEAT_HIGH)
		end
		stall.near = near
		if stall.startedAt then
			local elapsed = now - stall.startedAt
			local level = BoothGlow.level(elapsed)
			for _, entry in stall.entries do
				paint(entry, level)
			end
			if elapsed >= BoothGlow.TOTAL then
				stall.startedAt = nil
			end
		end
	end
end)
