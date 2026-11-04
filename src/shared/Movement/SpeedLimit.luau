-- Server speed check. Compares each position with the oldest one in a short
-- window, so one late network update cannot fail a legal player.
local MoveConfig = require("./MoveConfig")

export type Sample = { x: number, y: number, z: number, t: number }
export type Position = { x: number, y: number, z: number }
export type Track = {
	samples: { Sample },
	lastValid: Position,
	strikes: number,
}

local SpeedLimit = {}

function SpeedLimit.new(x: number, y: number, z: number, t: number): Track
	return {
		samples = { { x = x, y = y, z = z, t = t } },
		lastValid = { x = x, y = y, z = z },
		strikes = 0,
	}
end

-- Moves the track without a check, for respawns and server teleports.
function SpeedLimit.reset(track: Track, x: number, y: number, z: number, t: number)
	track.samples = { { x = x, y = y, z = z, t = t } }
	track.lastValid = { x = x, y = y, z = z }
end

function SpeedLimit.sample(track: Track, x: number, y: number, z: number, t: number): boolean
	local samples = track.samples
	-- Keeps one sample at least a full window old, so a gap in updates
	-- still has something to compare against.
	while #samples > 1 and t - samples[2].t >= MoveConfig.SpeedWindow do
		table.remove(samples, 1)
	end

	local oldest = samples[1]
	local elapsed = t - oldest.t
	local horizontal = math.sqrt((x - oldest.x) ^ 2 + (z - oldest.z) ^ 2)
	local rise = y - oldest.y
	local legal = horizontal <= MoveConfig.SpeedLimit * elapsed + MoveConfig.LagStuds
		and rise <= MoveConfig.MaxRiseSpeed * elapsed + MoveConfig.LagStuds

	if legal then
		table.insert(samples, { x = x, y = y, z = z, t = t })
		track.lastValid = { x = x, y = y, z = z }
	else
		local valid = track.lastValid
		track.samples = { { x = valid.x, y = valid.y, z = valid.z, t = t } }
	end
	return legal
end

function SpeedLimit.addStrike(track: Track): boolean
	track.strikes += 1
	return track.strikes >= MoveConfig.MaxStrikes
end

return SpeedLimit
