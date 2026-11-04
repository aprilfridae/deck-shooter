-- One player's recent positions, used to rewind them to when a shot was fired.
local KEEP_SECONDS = 1

export type Entry = { x: number, y: number, z: number, pose: string, t: number }
export type Past = { x: number, y: number, z: number, pose: string }
export type History = { entries: { Entry } }

local History = {}

function History.new(): History
	return { entries = {} }
end

function History.record(history: History, x: number, y: number, z: number, pose: string, t: number)
	local entries = history.entries
	table.insert(entries, { x = x, y = y, z = z, pose = pose, t = t })
	while entries[1].t < t - KEEP_SECONDS do
		table.remove(entries, 1)
	end
end

function History.at(history: History, t: number): Past?
	local entries = history.entries
	local count = #entries
	if count == 0 then
		return nil
	end

	local later = entries[1]
	if t <= later.t then
		return { x = later.x, y = later.y, z = later.z, pose = later.pose }
	end
	for i = 2, count do
		later = entries[i]
		if t <= later.t then
			local earlier = entries[i - 1]
			local alpha = (t - earlier.t) / (later.t - earlier.t)
			return {
				x = earlier.x + (later.x - earlier.x) * alpha,
				y = earlier.y + (later.y - earlier.y) * alpha,
				z = earlier.z + (later.z - earlier.z) * alpha,
				pose = earlier.pose,
			}
		end
	end
	return { x = later.x, y = later.y, z = later.z, pose = later.pose }
end

return History
