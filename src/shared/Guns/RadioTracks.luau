-- The radio's tracks. To add one: upload it to the group (tools/upload-group-assets.py), put its id in
-- SoundIds.luau, and add a line here. Titles and artists are drawn in the Label font, which has capitals,
-- digits and + - . / : > _ only: no commas, brackets or apostrophes.
-- Only the menu theme is here, as a stand-in. On 2026-11-10 River's 23 picks were uploaded and Roblox's
-- moderation removed a lot of them, for swearing among other things, so River had them all taken out (the
-- list is in git: commit c391433). Roblox rejects songs with swearing or other adult content in the lyrics,
-- so the next set needs clean or instrumental versions.
local GunSounds = require("./GunSounds")

export type Track = { title: string, artist: string, sound: string }

local tracks: { Track } = {
	{ title = "MENU THEME", artist = "SPLIT DECK", sound = GunSounds.menuMusic },
}

return tracks
