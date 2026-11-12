-- Clips for the first-person arms. A clip is a list of key frames at its fps; sampleAt blends between them
-- so the arms move at full framerate.
local ArmClip = {}

-- The frame showing after elapsed seconds, or nil once a one-shot clip has ended.
function ArmClip.frameAt(clip: any, elapsed: number): any
	local index = math.floor(elapsed * clip.fps)
	local count = #clip.frames
	if clip.loop then
		return clip.frames[index % count + 1]
	end
	return clip.frames[index + 1]
end

-- Two frames blended: CFrames and numbers move part of the way, bones blend, anything else comes from the first.
function ArmClip.blendFrames(from: any, to: any, share: number): any
	if share <= 0 or from == to then
		return from
	end
	local blended = {}
	for key, a in from do
		local b = to[key]
		if b == nil then
			blended[key] = a
		elseif key == "bones" then
			blended[key] = ArmClip.blendBones(a, b, share)
		elseif typeof(a) == "CFrame" then
			blended[key] = a:Lerp(b, share)
		elseif type(a) == "number" then
			blended[key] = a + (b - a) * share
		else
			blended[key] = a
		end
	end
	return blended
end

-- The pose after elapsed seconds, blended between key frames, or nil once a one-shot clip has ended.
-- A one-shot clip holds its last frame for that frame's time, as frameAt does.
function ArmClip.sampleAt(clip: any, elapsed: number): any
	local position = elapsed * clip.fps
	local index = math.floor(position)
	local share = position - index
	local count = #clip.frames
	if clip.loop then
		return ArmClip.blendFrames(clip.frames[index % count + 1], clip.frames[(index + 1) % count + 1], share)
	end
	local from = clip.frames[index + 1]
	if not from then
		return nil
	end
	local to = clip.frames[index + 2]
	return if to then ArmClip.blendFrames(from, to, share) else from
end

-- One of a gun's reload takes, with share from 0 up to 1 choosing which.
function ArmClip.pickReload(clips: any, share: number): any
	local takes = { clips.reload, clips.reload2, clips.reload3 }
	return takes[math.floor(share * #takes) + 1]
end

-- A pose part of the way between two frames' bones. Each bone is { x, y, z, qx, qy, qz, qw }.
function ArmClip.blendBones(from: any, to: any, share: number): any
	local blended = {}
	for name, a in from do
		local b = to[name]
		local dot = a[4] * b[4] + a[5] * b[5] + a[6] * b[6] + a[7] * b[7]
		local sign = if dot < 0 then -1 else 1 -- a quaternion and its negative are the same turn
		local bone = {}
		for i = 1, 3 do
			bone[i] = a[i] + (b[i] - a[i]) * share
		end
		local lengthSquared = 0
		for i = 4, 7 do
			bone[i] = a[i] + (b[i] * sign - a[i]) * share
			lengthSquared += bone[i] * bone[i]
		end
		local length = math.sqrt(lengthSquared)
		for i = 4, 7 do
			bone[i] /= length
		end
		blended[name] = bone
	end
	return blended
end

-- One frame with another laid over it. Bones in top win, and the gun stays where frame has it.
function ArmClip.overlay(frame: any, top: any): any
	local bones = table.clone(frame.bones)
	for name, bone in top.bones do
		bones[name] = bone
	end
	return { gun = frame.gun, bones = bones }
end

return ArmClip
