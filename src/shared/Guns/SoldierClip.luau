-- Turns a gun's SoldierClips module into clips ArmClip can play. Each frame's bones are the soldier's arm parts,
-- fingers, Gun, Mag and Action, all as { x, y, z, qx, qy, qz, qw }. A frame that names two poses is blended
-- between them. Frames that name the same thing share one table, so a frame can be found again with table.find.
local ArmClip = require("./ArmClip")

local SoldierClip = {}

export type Frame = { bones: { [string]: { number } } }
export type Clip = { fps: number, loop: boolean, scaled: boolean, frames: { Frame } }

function SoldierClip.expand(data: any): { [string]: Clip }
	local cache: { [string]: Frame } = {}
	local function frameOf(ref: { any }): Frame
		local key = table.concat({ ref[1], ref[2] or "", tostring(ref[3] or "") }, "|")
		local cached = cache[key]
		if cached then
			return cached
		end
		local from = data.poses[ref[1]]
		assert(from, "no pose " .. tostring(ref[1]))
		local frame: Frame
		if ref[2] then
			local to = data.poses[ref[2]]
			assert(to, "no pose " .. tostring(ref[2]))
			frame = { bones = ArmClip.blendBones(from, to, ref[3]) }
		else
			frame = { bones = from }
		end
		cache[key] = frame
		return frame
	end
	local clips = {}
	for name, clip in data.clips do
		local frames = {}
		for index, ref in clip.frames do
			frames[index] = frameOf(ref)
		end
		clips[name] = { fps = clip.fps, loop = clip.loop == true, scaled = clip.scaled == true, frames = frames }
	end
	return clips
end

-- The frames per second that make a scaled clip last the given seconds.
function SoldierClip.fpsFor(clip: Clip, seconds: number): number
	return #clip.frames / math.max(seconds, 0.05)
end

return SoldierClip
