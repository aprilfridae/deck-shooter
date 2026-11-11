-- Air strafing, by the Source engine's air-acceleration rule. Pure: plain numbers in and out.
-- In the air you keep the speed you left the ground with: there's no air friction, and letting go of the keys
-- changes nothing. A move key only adds speed along the direction it asks for (wish), and only while your
-- speed along that direction is under a small cap. So holding forward does next to nothing, but asking for a
-- direction off to the side of where you're going (strafe key, turning the view the same way) keeps adding a
-- little sideways, which turns you and makes you faster. That's the whole trick.
-- Speeds are studs per second, scaled from Source by run speed: its 30 units a second cap against a 250 run
-- is the same share of our sprint speed.
local MoveConfig = require("./MoveConfig")

local AirStrafe = {}

-- The most speed along the wish direction that air acceleration can build up to.
AirStrafe.cap = MoveConfig.SprintSpeed * MoveConfig.AirCapShare

-- One frame of air movement. (vx, vz) is the flat velocity, (wx, wz) the direction asked for (any length; zero
-- for no keys), dt the frame's length. Returns the new flat velocity.
function AirStrafe.accelerate(vx: number, vz: number, wx: number, wz: number, dt: number): (number, number)
	local wish = math.sqrt(wx * wx + wz * wz)
	if wish < 1e-4 then
		return vx, vz
	end
	wx, wz = wx / wish, wz / wish
	local along = vx * wx + vz * wz -- speed already going the way asked
	local room = AirStrafe.cap - along
	if room <= 0 then
		return vx, vz
	end
	local push = math.min(MoveConfig.AirAccelerate * MoveConfig.SprintSpeed * dt, room)
	local before = math.sqrt(vx * vx + vz * vz)
	vx += wx * push
	vz += wz * push
	-- Source has no top speed in the air; this game has one, for the cheat checks. It never takes away speed
	-- you already had (a parry or a dash can be faster).
	local after = math.sqrt(vx * vx + vz * vz)
	local most = math.max(before, MoveConfig.AirStrafeMaxSpeed)
	if after > most then
		vx, vz = vx / after * most, vz / after * most
	end
	return vx, vz
end

return AirStrafe
