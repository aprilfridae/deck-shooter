-- Plays gun sounds for the local player, straight in their ears.
local ContentProvider = game:GetService("ContentProvider")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local GunSounds = require(ReplicatedStorage:WaitForChild("Guns"):WaitForChild("GunSounds"))

local GunAudio = {}

local shots: { [string]: { Sound } } = {}
local allSounds: { Sound } = {}
for gunId, soundIds in GunSounds.shots do
	shots[gunId] = {}
	for take, soundId in soundIds do
		local sound = Instance.new("Sound")
		sound.Name = `Shot{gunId}{take}`
		sound.SoundId = soundId
		sound.Volume = 1
		sound.Parent = SoundService
		table.insert(shots[gunId], sound)
		table.insert(allSounds, sound)
	end
end

-- Loading up front stops the first shot from being late or silent.
task.spawn(function()
	ContentProvider:PreloadAsync(allSounds)
end)

local lastTake: { [string]: number } = {}

-- Picks a random take, never the same one twice in a row.
local function pickTake(gunId: string, count: number): number
	local take = math.random(1, count)
	if take == lastTake[gunId] then
		take = take % count + 1
	end
	lastTake[gunId] = take
	return take
end

-- Each shot gets its own copy, so every shot rings out under the ones after it.
function GunAudio.playShot(gunId: string, lateness: number)
	local takes = shots[gunId]
	if not takes then
		return
	end
	local shot = takes[pickTake(gunId, #takes)]:Clone()
	shot.Parent = SoundService
	shot.Ended:Once(function()
		shot:Destroy()
	end)
	shot.TimePosition = GunSounds.startOffset(lateness)
	shot:Play()
end

return GunAudio
