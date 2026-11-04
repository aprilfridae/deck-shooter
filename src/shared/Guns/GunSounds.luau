-- Which sound each gun's shot plays. rbxasset files only exist on a computer that ran
-- tools/install-sounds.sh. Swap each one for its rbxassetid:// once it's uploaded to Roblox.
local FOLDER = "rbxasset://sounds/deckshooter/"

return {
	shots = {
		M4 = FOLDER .. "gun-m4.ogg",
		AK47 = FOLDER .. "gun-ak47.wav",
		SMG = FOLDER .. "gun-smg.ogg",
		Sniper = FOLDER .. "gun-sniper.ogg",
		Shotgun = FOLDER .. "gun-shotgun.ogg",
		Pistol = FOLDER .. "gun-pistol.wav",
	},
}
