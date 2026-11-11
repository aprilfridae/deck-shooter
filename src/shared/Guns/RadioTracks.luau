-- The radio's tracks: River's picks, uploaded to the group on 2026-11-10 with the artists' permission (River's
-- word). To add one: upload it (tools/upload-group-assets.py), put its id in SoundIds.luau, and add a line here.
-- Titles and artists are drawn in the Label font, which has capitals, digits and + - . / : > _ only, so brackets
-- and commas are written with - and +. One artist's name is shortened to MF to keep swearing off the screen.
-- Not uploaded: "edyn - dissonance mix", which is 36 MB and over Roblox's size limit for one sound.
local SoundIds = require("./SoundIds")

export type Track = { title: string, artist: string, sound: string }

local function sound(file: string): string
	return `rbxassetid://{SoundIds[file]}`
end

local tracks: { Track } = {
	{ title = "DIVINE INTUITION", artist = "ANGELUS", sound = sound("radio-angelus-divine-intuition.mp3") },
	{ title = "PEANO", artist = "ANTOJE", sound = sound("radio-antoje-peano.mp3") },
	{ title = "TELEPHONE - GUNK ELXNCE SYDNEY RUNNER REMIX", artist = "CECE NATALIE", sound = sound("radio-cece-natalie-telephone-gunk-elxnce-s.mp3") },
	{ title = "PLAYWRIGHT", artist = "DOBI", sound = sound("radio-dobi-playwright.mp3") },
	{ title = "POCKET DIAL", artist = "DOBI", sound = sound("radio-dobi-pocket-dial.mp3") },
	{ title = "DEATHNOTE", artist = "EDYN", sound = sound("radio-edyn-deathnote.mp3") },
	{ title = "BACKDOOR", artist = "ERICDOA", sound = sound("radio-ericdoa-backdoor.mp3") },
	{ title = "AWESOME", artist = "GUNK", sound = sound("radio-gunk-awesome.mp3") },
	{ title = "DREAMFLASHER", artist = "JANE REMOVER", sound = sound("radio-jane-remover-dreamflasher.mp3") },
	{ title = "HOW TO TELEPORT", artist = "JANE REMOVER", sound = sound("radio-jane-remover-how-to-teleport.mp3") },
	{ title = "2010 JUSTIN BIEBER", artist = "LUCY BEDROQUE", sound = sound("radio-lucy-bedroque-2010-justin-bieber.mp3") },
	{ title = "BYOB", artist = "LUCY BEDROQUE", sound = sound("radio-lucy-bedroque-byob.mp3") },
	{ title = "FENTY FACE", artist = "LUCY BEDROQUE", sound = sound("radio-lucy-bedroque-fenty-face.mp3") },
	{ title = "TO YA FACE", artist = "LUCY BEDROQUE", sound = sound("radio-lucy-bedroque-to-ya-face.mp3") },
	{ title = "ZYGOTE", artist = "LUCY BEDROQUE", sound = sound("radio-lucy-bedroque-zygote.mp3") },
	{ title = "LITEWORK", artist = "OLSWEL", sound = sound("radio-olswel-litework.mp3") },
	{ title = "ONE HUNDRED PERCENT ORIGINAL", artist = "OLSWEL", sound = sound("radio-olswel-one-hundred-percent-original.mp3") },
	{ title = "FOUR SEASONS", artist = "OSQUINN", sound = sound("radio-osquinn-four-seasons.mp3") },
	{ title = "GOTY", artist = "SATURN", sound = sound("radio-saturn-goty.mp3") },
	{ title = "LIL GOO", artist = "TSUBI CLUB", sound = sound("radio-tsubi-club-lil-goo.mp3") },
	{ title = "CLICHE SONG - MOTHER REMIX", artist = "ZAYOK", sound = sound("radio-zayok-cliche-song-mother-remix.mp3") },
	{ title = "LUCK OF THE DRAW", artist = "ZAYOK", sound = sound("radio-zayok-luck-of-the-draw.mp3") },
	{ title = "FEEL GOOD", artist = "ZAYOK + MF", sound = sound("radio-zayok-mf-feel-good.mp3") },
}

return tracks
