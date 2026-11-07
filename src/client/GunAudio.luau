-- Plays gun sounds for the local player, straight in their ears.
local ContentProvider = game:GetService("ContentProvider")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local GunSounds = require(ReplicatedStorage:WaitForChild("Guns"):WaitForChild("GunSounds"))

local SoundGroups = require(script.Parent.SoundGroups)

local GunAudio = {}

local allSounds: { Sound } = {}

local function newSound(soundId: string): Sound
	local sound = Instance.new("Sound")
	sound.Name = string.match(soundId, "[^/]+$") or soundId
	sound.SoundId = soundId
	sound.Volume = 1
	sound.SoundGroup = SoundGroups.game
	sound.Parent = SoundService
	table.insert(allSounds, sound)
	return sound
end

local shots: { [string]: { Sound } } = {}
for gunId, soundIds in GunSounds.shots do
	shots[gunId] = {}
	for _, soundId in soundIds do
		table.insert(shots[gunId], newSound(soundId))
	end
end

local others: { [string]: Sound } = {}
for _, soundId in { GunSounds.hits.body, GunSounds.hits.head, GunSounds.hits.kill, GunSounds.hurt } do
	others[soundId] = newSound(soundId)
end
for _, soundId in GunSounds.reloads do
	others[soundId] = others[soundId] or newSound(soundId)
end

local steps: { Sound } = {}
for _, soundId in GunSounds.steps do
	table.insert(steps, newSound(soundId))
end
local jumps: { Sound } = {}
for _, soundId in GunSounds.jumps do
	table.insert(jumps, newSound(soundId))
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

-- Each play gets its own copy, so every sound rings out under the ones after it.
local function playCopy(template: Sound, startAt: number)
	local copy = template:Clone()
	copy.Parent = SoundService
	copy.Ended:Once(function()
		copy:Destroy()
	end)
	copy.TimePosition = startAt
	copy:Play()
end

function GunAudio.playShot(gunId: string, lateness: number)
	local takes = shots[gunId]
	if takes then
		playCopy(takes[pickTake(gunId, #takes)], GunSounds.startOffset(lateness))
	end
end

function GunAudio.playHit(headshot: boolean, killed: boolean)
	task.delay(GunSounds.hitDelaySeconds, playCopy, others[GunSounds.hitSound(headshot, killed)], 0)
end

function GunAudio.playReload(gunId: string)
	local soundId = GunSounds.reloads[gunId]
	if soundId then
		playCopy(others[soundId], 0)
	end
end

function GunAudio.playStep()
	playCopy(steps[pickTake("step", #steps)], 0)
end

function GunAudio.playJump()
	playCopy(jumps[pickTake("jump", #jumps)], GunSounds.jumpLeadSeconds)
end

function GunAudio.playHurt()
	task.delay(GunSounds.hitDelaySeconds, playCopy, others[GunSounds.hurt], 0)
end

return GunAudio
