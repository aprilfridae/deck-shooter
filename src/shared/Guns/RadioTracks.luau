-- The radio's tracks. To add one: upload it to the group (tools/upload-group-assets.py), put its id in
-- SoundIds.luau, and add a line here. Titles and artists are drawn in the Label font, which has capitals,
-- digits and a few marks only: no commas or apostrophes.
-- Only the menu theme is here until River's tracks are uploaded; it stands in so the radio can be tried.
local GunSounds = require("./GunSounds")

export type Track = { title: string, artist: string, sound: string }

local tracks: { Track } = {
	{ title = "MENU THEME", artist = "SPLIT DECK", sound = GunSounds.menuMusic },
}

return tracks
