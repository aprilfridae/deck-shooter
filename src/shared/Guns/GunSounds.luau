-- The takes each gun's shot picks from, and the game's other sounds. They're Fridae Studios group
-- assets (ids in SoundIds.luau), so they play in the group's experiences. The source files live
-- outside the repo; to add or change a sound, upload it to the group and add its id to SoundIds.
local SoundIds = require("./SoundIds")

local HURT_HEALTH = 20

local function sound(file: string): string
	local id = SoundIds[file]
	if not id then
		error(`{file} has no uploaded id in SoundIds`)
	end
	return `rbxassetid://{id}`
end

local function takes(name: string, count: number, skip: number?): { string }
	local list = {}
	for take = 1, count do
		if take ~= skip then
			table.insert(list, sound(`gun-{name}-{take}.wav`))
		end
	end
	return list
end

local function numbered(name: string, count: number): { string }
	local list = {}
	for take = 1, count do
		table.insert(list, sound(`{name}-{take}.wav`))
	end
	return list
end

local GunSounds = {
	-- tools/pad-sounds.py adds this much silence to the front of every take.
	paddingSeconds = 0.02,
	-- Waits out the gunshot, so a hit and a shot don't land on top of each other.
	hitDelaySeconds = 0.08,
	shots = {
		M4 = takes("m4", 30),
		AK47 = takes("ak47", 30),
		SMG = takes("smg", 29), -- take 30 exported silent
		Sniper = takes("sniper", 30, 12), -- take 12 starts late and much louder
		Shotgun = takes("shotgun", 30),
		Pistol = takes("pistol", 30),
	},
	-- Played under every take of that gun's shot.
	shotBases = {
		Sniper = sound("gun-sniper-base.wav"),
	},
	-- Each gun's reload time in GunConfig matches the length of its sound here. The Sniper has none: its base
	-- shot sound covers it.
	reloads = {
		M4 = sound("reload-assault-v4.wav"),
		AK47 = sound("reload-assault-v4.wav"),
		Pistol = sound("reload-pistol-v4.wav"),
	},
	hits = {
		body = sound("hit-body.wav"),
		head = sound("hit-head.wav"),
		kill = sound("hit-kill.wav"),
	},
	hurt = sound("hurt.wav"),
	menuMusic = sound("menu-music-v2.mp3"),
	outpostAmbience = sound("outpost-ambience.ogg"),
	menuSelect = sound("menu-select.wav"),
	steps = numbered("step", 10),
	jumps = numbered("jump", 14),
	-- Bullets flying close past you. Each take's whizz peaks this far in.
	whizzes = numbered("bullet-whizz", 16),
	whizzPeakSeconds = 0.07,
	-- Every jump take opens with this much silence.
	jumpLeadSeconds = 0.1,
	lands = {
		soft = sound("move-land-soft.wav"),
		hard = sound("move-land-hard.wav"),
	},
	slideStart = sound("move-slide-start.wav"),
	-- The pistol hand's finger snap on a kill. The clip's fingers click together this far in.
	snap = sound("pistol-snap.wav"),
	snapDelaySeconds = 0.075, -- the click at 0.06s in the clip, which plays at 0.8 speed
	-- The coins a body bursts into when it dies.
	coinBurst = sound("coin-burst.wav"),
	-- Each pack rarity's opening sound.
	packOpens = {
		Field = sound("pack-open-common.wav"),
		BlackSite = sound("pack-open-rarer.wav"),
		Prototype = sound("pack-open-rarer.wav"),
		ZeroDay = sound("pack-open-rarest.wav"),
	},
}

-- Roblox can only start a sound on a frame. Starting a late shot this far into its padding
-- makes it land at the same moment it would have if the frame had been on time.
function GunSounds.startOffset(lateness: number): number
	return math.clamp(lateness, 0, GunSounds.paddingSeconds)
end

-- The sounds a hit plays together. A headshot kill plays the headshot sound with the kill sound.
function GunSounds.hitSounds(headshot: boolean, killed: boolean): { string }
	if killed then
		return if headshot then { GunSounds.hits.head, GunSounds.hits.kill } else { GunSounds.hits.kill }
	end
	return { if headshot then GunSounds.hits.head else GunSounds.hits.body }
end

-- A warning that you're nearly dead, not a sound for every hit.
function GunSounds.hurtPlays(previousHealth: number, health: number): boolean
	return health < previousHealth and health > 0 and health <= HURT_HEALTH
end

return GunSounds
