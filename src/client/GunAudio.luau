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
-- Other players' shots sound from where they fired: full volume this close, gone past this far.
local SHOT_NEAR = 25
local SHOT_FAR = 600
-- Other players' footsteps: full volume this close, gone past this far.
local STEP_NEAR = 6
local STEP_FAR = 90
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

local function newFarSound(soundId: string): Sound
	local sound = newSound(soundId)
	sound.RollOffMode = Enum.RollOffMode.InverseTapered
	sound.RollOffMinDistance = SHOT_NEAR
	sound.RollOffMaxDistance = SHOT_FAR
	return sound
end

local farShots: { [string]: { Sound } } = {}
for gunId, soundIds in GunSounds.farShots do
	farShots[gunId] = {}
	for _, soundId in soundIds do
		table.insert(farShots[gunId], newFarSound(soundId))
	end
end
local farBases: { [string]: Sound } = {}
for gunId, soundId in GunSounds.farShotBases do
	farBases[gunId] = newFarSound(soundId)
end

local farSteps: { Sound } = {}
for _, soundId in GunSounds.farSteps do
	local step = newSound(soundId)
	step.RollOffMode = Enum.RollOffMode.InverseTapered
	step.RollOffMinDistance = STEP_NEAR
	step.RollOffMaxDistance = STEP_FAR
	table.insert(farSteps, step)
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
	GunSounds.wallJump,
	GunSounds.coinBurst,
	GunSounds.coinSuck,
	GunSounds.collateral,
	GunSounds.snap,
	GunSounds.cardFlourish,
	GunSounds.cardSkip,
	GunSounds.cardCrush,
} do
	others[soundId] = newSound(soundId)
end
-- River: the jump and slide sounds were far too loud. Copies keep these volumes.
local QUIET = 0.25
others[GunSounds.slideStart].Volume = QUIET
for _, soundId in GunSounds.slideLayers do
	others[soundId] = newSound(soundId)
	others[soundId].Volume = QUIET
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
	local jump = newSound(soundId)
	jump.Volume = QUIET
	table.insert(jumps, jump)
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

-- Someone else's shot, heard from where it was fired.
function GunAudio.playFarShot(gunId: string, origin: Vector3)
	local takes = farShots[gunId]
	if not takes then
		return
	end
	local anchor = Instance.new("Attachment")
	anchor.Name = "FarShot"
	anchor.WorldPosition = origin
	anchor.Parent = workspace.Terrain
	local longest: Sound? = nil
	for _, template in { takes[pickTake(`far{gunId}`, #takes)], farBases[gunId] } do
		local copy = template:Clone()
		copy.Parent = anchor
		copy.TimePosition = 0
		copy:Play()
		longest = copy -- the base, when there is one, outlasts the take
	end
	if longest then
		longest.Ended:Once(function()
			anchor:Destroy()
		end)
	end
	task.delay(8, function() -- in case the sound never loaded, so never ended
		anchor:Destroy()
	end)
end

function GunAudio.playCollateral()
	task.delay(GunSounds.hitDelaySeconds, playCopy, others[GunSounds.collateral], 0)
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

-- A card being crushed in the fist: whatever is left of the flourish's sound is cut, and this rings out even after
-- the cards are gone.
function GunAudio.playCardCrush()
	GunAudio.stopCards()
	playCopy(others[GunSounds.cardCrush], 0)
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

-- Someone else's footstep, heard from their feet.
function GunAudio.playFarStep(at: Vector3)
	local anchor = Instance.new("Attachment")
	anchor.Name = "FarStep"
	anchor.WorldPosition = at
	anchor.Parent = workspace.Terrain
	local copy = farSteps[pickTake("farStep", #farSteps)]:Clone()
	copy.Parent = anchor
	copy:Play()
	task.delay(3, function() -- the takes are under 1.5s
		anchor:Destroy()
	end)
end

function GunAudio.playJump()
	playCopy(jumps[pickTake("jump", #jumps)], GunSounds.jumpLeadSeconds)
end

function GunAudio.playLand(hard: boolean)
	playCopy(others[if hard then GunSounds.lands.hard else GunSounds.lands.soft], 0)
end

function GunAudio.playWallJump()
	playCopy(others[GunSounds.wallJump], 0)
end

function GunAudio.playSlideStart()
	playCopy(others[GunSounds.slideStart], 0)
	-- One of the layer takes on top, never the same one twice running.
	playCopy(others[GunSounds.slideLayers[pickTake("slideLayer", #GunSounds.slideLayers)]], 0)
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
