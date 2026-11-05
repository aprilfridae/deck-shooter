-- Turns the music's loudness into bar heights. Roblox gives one loudness, not frequencies,
-- so the bars share it out with a moving pattern.
local LOUD = 350 -- PlaybackLoudness that fills a bar
local FALL_SPEED = 2.5 -- share of a full bar lost per second

local MusicBars = {}

function MusicBars.level(loudness: number, bar: number, bars: number, time: number): number
	local place = bar / bars
	local pattern = 0.65
		+ 0.25 * math.sin(time * 7 + place * 19)
		+ 0.15 * math.sin(time * 13 - place * 41)
	return math.clamp(loudness / LOUD * pattern, 0, 1)
end

function MusicBars.ease(current: number, target: number, dt: number): number
	return math.max(target, current - FALL_SPEED * dt)
end

function MusicBars.lit(level: number, segments: number): number
	return math.ceil(level * segments)
end

return MusicBars
