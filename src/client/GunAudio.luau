-- Plays gun sounds for the local player, straight in their ears.
local ContentProvider = game:GetService("ContentProvider")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local GunSounds = require(ReplicatedStorage:WaitForChild("Guns"):WaitForChild("GunSounds"))

local SoundGroups = require(script.Parent.SoundGroups)

local GunAudio = {}

-- A flyby sounds from the bullet's path and travels along it past your head.
local WHIZZ_SPEED = 60 -- studs a second
local WHIZZ_NEAR = 2
local WHIZZ_FAR = 40
-- Coin bursts sound from the body, loud close by and gone past this far.
local COIN_NEAR = 8
local COIN_FAR = 150

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
for _, soundId in {
	GunSounds.hits.body,
	GunSounds.hits.head,
	GunSounds.hits.kill,
	GunSounds.hurt,
	GunSounds.lands.soft,
	GunSounds.lands.hard,
	GunSounds.slideStart,
	GunSounds.coinBurst,
	GunSounds.coinSuck,
	GunSounds.snap,
	GunSounds.cardFlourish,
	GunSounds.cardSkip,
} do
	others[soundId] = newSound(soundId)
end
for _, soundId in GunSounds.shotBases do
	others[soundId] = others[soundId] or newSound(soundId)
end
for _, soundId in GunSounds.reloads do
	others[soundId] = others[soundId] or newSound(soundId)
end

local steps: { Sound } = {}
for _, soundId in GunSounds.steps do
	table.insert(steps, newSound(soundId))
end
local whizzes: { Sound } = {}
for _, soundId in GunSounds.whizzes do
	local whizz = newSound(soundId)
	whizz.RollOffMode = Enum.RollOffMode.InverseTapered
	whizz.RollOffMinDistance = WHIZZ_NEAR
	whizz.RollOffMaxDistance = WHIZZ_FAR
	table.insert(whizzes, whizz)
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

-- Sounds still ringing from each gun, so a swap can fade them.
local SWAP_FADE = 0.15
local gunSounds: { [Sound]: string } = {}

-- Each play gets its own copy, so every sound rings out under the ones after it. gunId tags a gun's own sounds.
local function playCopy(template: Sound, startAt: number, gunId: string?)
	local copy = template:Clone()
	copy.Parent = SoundService
	if gunId then
		gunSounds[copy] = gunId
	end
	copy.Ended:Once(function()
		gunSounds[copy] = nil
		copy:Destroy()
	end)
	copy.TimePosition = startAt
	copy:Play()
end

-- Fades out every gun sound still playing that isn't keep's.
function GunAudio.fadeGuns(keep: string)
	for copy, gunId in gunSounds do
		if gunId ~= keep then
			gunSounds[copy] = nil
			local fade = TweenService:Create(copy, TweenInfo.new(SWAP_FADE), { Volume = 0 })
			fade.Completed:Once(function()
				copy:Destroy()
			end)
			fade:Play()
		end
	end
end

function GunAudio.playShot(gunId: string, lateness: number)
	local takes = shots[gunId]
	if takes then
		playCopy(takes[pickTake(gunId, #takes)], GunSounds.startOffset(lateness), gunId)
	end
	local base = GunSounds.shotBases[gunId]
	if base then
		playCopy(others[base], GunSounds.startOffset(lateness), gunId)
	end
end

function GunAudio.playHit(headshot: boolean, killed: boolean)
	for _, soundId in GunSounds.hitSounds(headshot, killed) do
		task.delay(GunSounds.hitDelaySeconds, playCopy, others[soundId], 0)
	end
end

-- The cards coming out. Only one plays at a time, and it's faded out when the cards go away or the flourish is cut
-- short.
local CARD_FADE = 0.15
local cardSound: Sound? = nil

function GunAudio.stopCards()
	local playing = cardSound
	if playing then
		cardSound = nil
		local fade = TweenService:Create(playing, TweenInfo.new(CARD_FADE), { Volume = 0 })
		fade.Completed:Once(function()
			playing:Destroy()
		end)
		fade:Play()
	end
end

-- Right click cutting the flourish short: the flourish's sound is cut and this plays over it.
function GunAudio.playCardSkip()
	GunAudio.stopCards()
	playCopy(others[GunSounds.cardSkip], 0)
end

function GunAudio.playCards()
	GunAudio.stopCards()
	local copy = others[GunSounds.cardFlourish]:Clone()
	copy.Parent = SoundService
	copy.Ended:Once(function()
		if cardSound == copy then
			cardSound = nil
		end
		copy:Destroy()
	end)
	cardSound = copy
	copy:Play()
end

function GunAudio.playReload(gunId: string)
	local soundId = GunSounds.reloads[gunId]
	if soundId then
		playCopy(others[soundId], 0, gunId)
	end
end

function GunAudio.playStep()
	playCopy(steps[pickTake("step", #steps)], 0)
end

function GunAudio.playJump()
	playCopy(jumps[pickTake("jump", #jumps)], GunSounds.jumpLeadSeconds)
end

function GunAudio.playLand(hard: boolean)
	playCopy(others[if hard then GunSounds.lands.hard else GunSounds.lands.soft], 0)
end

function GunAudio.playSlideStart()
	playCopy(others[GunSounds.slideStart], 0)
end

-- closest is the point on the bullet's path nearest your head, direction its unit direction.
function GunAudio.playWhizz(closest: Vector3, direction: Vector3)
	local take = whizzes[pickTake("whizz", #whizzes)]
	local anchor = Instance.new("Attachment")
	anchor.Name = "Whizz"
	anchor.WorldPosition = closest - direction * WHIZZ_SPEED * GunSounds.whizzPeakSeconds
	anchor.Parent = workspace.Terrain
	local copy = take:Clone()
	copy.Parent = anchor
	copy.Ended:Once(function()
		anchor:Destroy()
	end)
	local seconds = take.TimeLength > 0 and take.TimeLength or 0.5
	TweenService:Create(anchor, TweenInfo.new(seconds, Enum.EasingStyle.Linear), {
		WorldPosition = anchor.WorldPosition + direction * WHIZZ_SPEED * seconds,
	}):Play()
	copy:Play()
end

function GunAudio.playSnap()
	task.delay(GunSounds.snapDelaySeconds, playCopy, others[GunSounds.snap], 0)
end

-- The coins being pulled in. It comes from the body they're going to and moves with it.
function GunAudio.playCoinSuck(body: BasePart)
	local copy = others[GunSounds.coinSuck]:Clone()
	copy.RollOffMode = Enum.RollOffMode.InverseTapered
	copy.RollOffMinDistance = COIN_NEAR
	copy.RollOffMaxDistance = COIN_FAR
	copy.Parent = body
	copy.Ended:Once(function()
		copy:Destroy()
	end)
	copy:Play()
end

function GunAudio.playCoins(position: Vector3)
	local anchor = Instance.new("Attachment")
	anchor.Name = "Coins"
	anchor.WorldPosition = position
	anchor.Parent = workspace.Terrain
	local copy = others[GunSounds.coinBurst]:Clone()
	copy.RollOffMode = Enum.RollOffMode.InverseTapered
	copy.RollOffMinDistance = COIN_NEAR
	copy.RollOffMaxDistance = COIN_FAR
	copy.Parent = anchor
	copy.Ended:Once(function()
		anchor:Destroy()
	end)
	copy:Play()
end

function GunAudio.playHurt()
	task.delay(GunSounds.hitDelaySeconds, playCopy, others[GunSounds.hurt], 0)
end

return GunAudio
