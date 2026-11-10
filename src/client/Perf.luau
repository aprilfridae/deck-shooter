-- This machine's quality level, for anything that draws extras: Perf.pick(all of it, trimmed, the least). It watches
-- the frame rate and steps down when the game is drawn slowly, and back up when there's room (PerfLevel has the
-- rules). The level is also on the player as the attribute PerfLevel, to look at while testing.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local PerfLevel = require(ReplicatedStorage:WaitForChild("Guns"):WaitForChild("PerfLevel"))

local Perf = {}

local quality = 0
pcall(function()
	quality = UserSettings():GetService("UserGameSettings").SavedQualityLevel.Value
end)
local state = PerfLevel.new(quality)
-- A phone or tablet starts a level down: it can earn its way up, but shouldn't open on the full load.
local UserInputService = game:GetService("UserInputService")
if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then
	state.level = math.min(state.level, 2)
end
local level = state.level
Players.LocalPlayer:SetAttribute("PerfLevel", level)

RunService.RenderStepped:Connect(function(dt)
	local now = PerfLevel.step(state, dt, os.clock())
	if now ~= level then
		level = now
		Players.LocalPlayer:SetAttribute("PerfLevel", level)
	end
end)

function Perf.level(): number
	return level
end

function Perf.pick<T>(high: T, medium: T, low: T): T
	return PerfLevel.pick(level, high, medium, low)
end

return Perf
