-- The takes each gun's shot picks from. rbxasset files only exist on a computer that ran
-- tools/install-sounds.sh. Swap each one for its rbxassetid:// once it's uploaded to Roblox.
local FOLDER = "rbxasset://sounds/deckshooter/"
local HURT_HEALTH = 20

local function takes(name: string, count: number, skip: number?): { string }
	local list = {}
	for take = 1, count do
		if take ~= skip then
			table.insert(list, `{FOLDER}gun-{name}-{take}.wav`)
		end
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
	hits = {
		body = `{FOLDER}hit-body.wav`,
		head = `{FOLDER}hit-head.wav`,
		kill = `{FOLDER}hit-kill.wav`,
	},
	hurt = `{FOLDER}hurt.wav`,
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
