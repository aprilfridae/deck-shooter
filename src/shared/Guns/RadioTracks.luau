-- The radio's tracks. To add one: upload it to the group (tools/upload-group-assets.py), put its id in
-- SoundIds.luau, and add a line here. Titles and artists are drawn in the Label font, which has capitals,
-- digits and + - . / : > _ only, so brackets become dashes, "&" becomes "+", and other marks are dropped.
-- This is River's second set (2026-11-10), converted from m4a to mp3 for the upload. The first set of 23 was
-- taken out after Roblox's moderation removed many of them for swearing; that list is in git (c391433).
-- A track Roblox hasn't cleared, or has removed, is skipped by the radio.
local SoundIds = require("./SoundIds")

export type Track = { title: string, artist: string, sound: string }

local function sound(file: string): string
	return `rbxassetid://{SoundIds[file]}`
end

local tracks: { Track } = {
	{ title = "SAPIENCE", artist = "EUPHEE + GRAPE MILK", sound = sound("radio-euphee-grape-milk-sapience.mp3") },
	{ title = "BLZZDY UP THE FLOOR - FEAT. DANIEL MAURO", artist = "OLSWEL", sound = sound("radio-olswel-blzzdy-up-the-floor-feat-daniel.mp3") },
	{ title = "CRY WHEN I YOU", artist = "OLSWEL", sound = sound("radio-olswel-cry-when-i-you.mp3") },
	{ title = "FRIDAYY", artist = "OLSWEL", sound = sound("radio-olswel-fridayy.mp3") },
	{ title = "L96A1", artist = "OLSWEL", sound = sound("radio-olswel-l96a1.mp3") },
	{ title = "HELLOMYNAMEIS", artist = "OLSWEL", sound = sound("radio-olswel-hellomynameis.mp3") },
	{ title = "KATRIP - VIP", artist = "OLSWEL", sound = sound("radio-olswel-katrip-vip.mp3") },
	{ title = "PRETTY AWESOME - FEAT. DILIP", artist = "OLSWEL", sound = sound("radio-olswel-pretty-awesome-feat-dilip.mp3") },
	{ title = "DOPE1 - WITH OLSWEL", artist = "SYZY", sound = sound("radio-syzy-dope1-with-olswel.mp3") },
	{ title = "DANCING ON MY OWN", artist = "SYZY", sound = sound("radio-syzy-dancing-on-my-own.mp3") },
	{ title = "INDUSTRY CORPORATE FREAK", artist = "SYZY", sound = sound("radio-syzy-industry-corporate-freak.mp3") },
	{ title = "TAKE MY ENERGY", artist = "SYZY", sound = sound("radio-syzy-take-my-energy.mp3") },
	{ title = "LITEWORK", artist = "OLSWEL", sound = sound("radio-olswel-litework.mp3") },
	{ title = "ONE HUNDRED PERCENT ORIGINAL", artist = "OLSWEL", sound = sound("radio-olswel-one-hundred-percent-original.mp3") },
}

return tracks
