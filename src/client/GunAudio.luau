-- Plays gun sounds for the local player, straight in their ears.
local ContentProvider = game:GetService("ContentProvider")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local GunSounds = require(ReplicatedStorage:WaitForChild("Guns"):WaitForChild("GunSounds"))

local GunAudio = {}

local shots: { [string]: Sound } = {}
for gunId, soundId in GunSounds.shots do
	local sound = Instance.new("Sound")
	sound.Name = `Shot{gunId}`
	sound.SoundId = soundId
	sound.Volume = 1
	sound.Parent = SoundService
	shots[gunId] = sound
end

-- Loading up front stops the first shot from being late or silent.
task.spawn(function()
	local sounds = {}
	for _, sound in shots do
		table.insert(sounds, sound)
	end
	ContentProvider:PreloadAsync(sounds)
end)

local held: Sound? = nil
local heldGunId: string? = nil

-- Lets the shot that's playing finish, then stops.
function GunAudio.releaseShot()
	local sound = held
	if not sound then
		return
	end
	held = nil
	heldGunId = nil
	sound.Looped = false
	local remaining = (sound.TimeLength - sound.TimePosition) / sound.PlaybackSpeed
	task.delay(math.max(remaining, 0), function()
		sound:Destroy()
	end)
end

-- Automatic guns loop one shot while firing, so the audio engine keeps the beat exactly.
-- Frames can't: starting each shot separately lands up to a frame early or late.
function GunAudio.holdShot(gunId: string, speed: number)
	if heldGunId ~= gunId then
		GunAudio.releaseShot()
		local template = shots[gunId]
		if not template then
			return
		end
		local sound = template:Clone()
		sound.Looped = true
		sound.PlaybackSpeed = speed
		sound.Parent = SoundService
		sound:Play()
		held = sound
		heldGunId = gunId
	elseif held then
		held.PlaybackSpeed = speed
	end
end

-- Each shot gets its own copy, so a tail can ring out under the next shot.
function GunAudio.playShot(gunId: string)
	local template = shots[gunId]
	if not template then
		return
	end
	local shot = template:Clone()
	shot.Parent = SoundService
	shot.Ended:Once(function()
		shot:Destroy()
	end)
	shot:Play()
end

return GunAudio
