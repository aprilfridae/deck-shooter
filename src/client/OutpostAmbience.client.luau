-- The Outpost's ambience: loops while you're in the Outpost after the title screen, and fades
-- out anywhere else.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")

local Guns = ReplicatedStorage:WaitForChild("Guns")
local GunSounds = require(Guns:WaitForChild("GunSounds"))
local MenuState = require(Guns:WaitForChild("MenuState"))
local Zones = require(Guns:WaitForChild("Zones"))
local SoundGroups = require(script.Parent.SoundGroups)

local FADE_SECONDS = 1.5

local player = Players.LocalPlayer

local ambience = Instance.new("Sound")
ambience.Name = "OutpostAmbience"
ambience.SoundId = GunSounds.outpostAmbience
ambience.Looped = true
ambience.Volume = 0
ambience.SoundGroup = SoundGroups.game
ambience.Parent = SoundService

RunService.Heartbeat:Connect(function(dt: number)
	local wanted = Zones.of(player) == Zones.Outpost and not MenuState.isOpen(MenuState.shared)
	local volume = math.clamp(ambience.Volume + (if wanted then dt else -dt) / FADE_SECONDS, 0, 1)
	ambience.Volume = volume
	if volume > 0 and not ambience.IsPlaying then
		ambience:Play()
	elseif volume == 0 and ambience.IsPlaying then
		ambience:Pause()
	end
end)
