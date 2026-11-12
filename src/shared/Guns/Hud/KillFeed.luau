--!strict
-- The kill feed's list (docs/specs/hud-redesign.md): every kill on the server, newest last, a few at a time, each
-- for a few seconds. Pure rules; KillFeed.client.luau draws it.
local KillFeed = {
	MAX = 5, -- lines shown at once
	SECONDS = 6, -- how long a line stays
	FADE = 0.4, -- then how long it takes to go
	NAME_LENGTH = 20, -- characters of a name that are shown
}

export type Entry = { killer: string, victim: string, mine: boolean, at: number }

local DRAWN = "^[A-Z0-9 /:%.%->+_,'()?]$" -- what the label font can draw
local UNKNOWN = "?"

-- Adds a kill at the end, and drops the oldest past the most that show.
function KillFeed.push(list: { Entry }, entry: { killer: string, victim: string, mine: boolean }, now: number)
	table.insert(list, { killer = entry.killer, victim = entry.victim, mine = entry.mine, at = now })
	while #list > KillFeed.MAX do
		table.remove(list, 1)
	end
end

-- Drops the lines that have faded away. True if any went.
function KillFeed.prune(list: { Entry }, now: number): boolean
	local dropped = false
	for index = #list, 1, -1 do
		if now - list[index].at > KillFeed.SECONDS + KillFeed.FADE then
			table.remove(list, index)
			dropped = true
		end
	end
	return dropped
end

-- How see-through a line is: 0 while it shows, rising to 1 as it goes.
function KillFeed.fade(entry: Entry, now: number): number
	return math.clamp((now - entry.at - KillFeed.SECONDS) / KillFeed.FADE, 0, 1)
end

-- A name as the feed prints it: capitals, cut short, with a ? for anything the font can't draw.
-- nil if it isn't a name at all.
function KillFeed.clean(name: any): string?
	if type(name) ~= "string" or name == "" then
		return nil
	end
	local letters = {}
	if utf8.len(name) then
		for _, code in utf8.codes(name) do
			table.insert(letters, if code < 128 then string.char(code) else UNKNOWN)
		end
	else
		letters = string.split(name, "") -- not proper text: take it a byte at a time
	end
	local out = {}
	for index = 1, math.min(#letters, KillFeed.NAME_LENGTH) do
		local letter = string.upper(letters[index])
		table.insert(out, if string.find(letter, DRAWN) then letter else UNKNOWN)
	end
	return table.concat(out)
end

return KillFeed
