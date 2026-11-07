-- Sets the camera mode and mouse behavior based on the current zone.
-- Outpost: third-person camera with free mouse for UI interaction.
-- Everywhere else (the test room, the Relay map): first-person locked camera for combat.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")

local Guns = ReplicatedStorage:WaitForChild("Guns")
local Zones = require(Guns:WaitForChild("Zones"))

local player = Players.LocalPlayer

local function applyZone()
	local zone = Zones.of(player)
	
	if zone == Zones.Outpost then
		-- Outpost: third-person camera with free mouse
		pcall(function()
			player.CameraMode = Enum.CameraMode.Classic
			player.CameraMinZoomDistance = 5
			player.CameraMaxZoomDistance = 20
		end)
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
		UserInputService.MouseIconEnabled = true
	else
		-- First-person locked camera for combat
		pcall(function()
			player.CameraMode = Enum.CameraMode.LockFirstPerson
			player.CameraMinZoomDistance = 0.5
			player.CameraMaxZoomDistance = 0.5
		end)
		UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
		UserInputService.MouseIconEnabled = false
	end
end

player:GetAttributeChangedSignal("Zone"):Connect(applyZone)
applyZone()
