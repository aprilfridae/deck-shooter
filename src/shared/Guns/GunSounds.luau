-- The takes each gun's shot picks from. rbxasset files only exist on a computer that ran
-- tools/install-sounds.sh. Swap each one for its rbxassetid:// once it's uploaded to Roblox.
local FOLDER = "rbxasset://sounds/deckshooter/"

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
	shots = {
		M4 = takes("m4", 30),
		AK47 = takes("ak47", 30),
		SMG = takes("smg", 29), -- take 30 exported silent
		Sniper = takes("sniper", 30, 12), -- take 12 starts late and much louder
		Shotgun = takes("shotgun", 30),
		Pistol = takes("pistol", 30),
	},
}

-- Roblox can only start a sound on a frame. Starting a late shot this far into its padding
-- makes it land at the same moment it would have if the frame had been on time.
function GunSounds.startOffset(lateness: number): number
	return math.clamp(lateness, 0, GunSounds.paddingSeconds)
end

return GunSounds
