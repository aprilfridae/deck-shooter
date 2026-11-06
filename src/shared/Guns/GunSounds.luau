-- The takes each gun's shot picks from, and the game's other sounds.
-- They're uploaded to River's Roblox account (ids in SoundIds.luau), but uploaded audio only plays in
-- experiences River owns. Anywhere else, such as a collaborator's own place, they play from the
-- local copies that tools/install-assets.ps1 (or install-sounds.sh) puts in Studio.
local SoundIds = require("./SoundIds")

local FOLDER = "rbxasset://sounds/deckshooter/"
local OWNER_ID = 3542058083 -- River
local HURT_HEALTH = 20

local function ownedByRiver(): boolean
	local ok, owned = pcall(function()
		return game.CreatorType == Enum.CreatorType.User and game.CreatorId == OWNER_ID
	end)
	return ok and owned == true
end

local useUploaded = ownedByRiver()

local function sound(file: string): string
	local id = SoundIds[file]
	if useUploaded and id then
		return `rbxassetid://{id}`
	end
	return FOLDER .. file
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
	-- Each gun's reload time in GunConfig matches the length of its sound here.
	reloads = {
		M4 = sound("reload-assault-v2.wav"),
		AK47 = sound("reload-assault-v2.wav"),
		Sniper = sound("reload-sniper.wav"),
		Pistol = sound("reload-pistol-v4.wav"),
	},
	hits = {
		body = sound("hit-body.wav"),
		head = sound("hit-head.wav"),
		kill = sound("hit-kill.wav"),
	},
	hurt = sound("hurt.wav"),
	menuMusic = sound("menu-music-v2.mp3"),
	menuSelect = sound("menu-select.wav"),
	steps = numbered("step", 10),
	jumps = numbered("jump", 14),
	-- Every jump take opens with this much silence.
	jumpLeadSeconds = 0.1,
}

-- Roblox can only start a sound on a frame. Starting a late shot this far into its padding
-- makes it land at the same moment it would have if the frame had been on time.
function GunSounds.startOffset(lateness: number): number
	return math.clamp(lateness, 0, GunSounds.paddingSeconds)
end

function GunSounds.hitSound(headshot: boolean, killed: boolean): string
	if killed then
		return GunSounds.hits.kill
	end
	return if headshot then GunSounds.hits.head else GunSounds.hits.body
end

-- A warning that you're nearly dead, not a sound for every hit.
function GunSounds.hurtPlays(previousHealth: number, health: number): boolean
	return health < previousHealth and health > 0 and health <= HURT_HEALTH
end

return GunSounds
