-- The third-person recoil: a spring that each shot knocks back and that settles again, like the first-person
-- gun's kick. Pure numbers. RemotePoses turns the value into the shoulders rising, the torso rocking back and the
-- hips being pushed back a touch.
-- River found third-person shooting wrong: it was one still "fire" pose held for a sixth of a second.
local ShotKick = {}

local STIFF = 420 -- how hard it pulls back to rest
local DAMP = 30 -- how fast it stops ringing: settles in about a quarter second with barely any bounce
local HIT = 44 -- the speed one shot of strength 1 adds, which peaks the value near 1
local MOST = 2.6 -- sustained fire can't stack past this
local STEP = 1 / 240

export type Kick = { at: number, speed: number, side: number }

function ShotKick.new(): Kick
	return { at = 0, speed = 0, side = 1 }
end

-- A shot. strength is the gun's (ShotKick.strength); side alternates so the twist isn't always the same way.
function ShotKick.hit(kick: Kick, strength: number)
	kick.speed += HIT * strength
	kick.side = -kick.side
end

-- Moves the spring on and returns where it is: 0 at rest, about the gun's strength at the top of one shot.
function ShotKick.step(kick: Kick, dt: number): number
	local left = math.clamp(dt, 0, 0.1)
	while left > 0 do
		local step = math.min(left, STEP)
		kick.speed += (-STIFF * kick.at - DAMP * kick.speed) * step
		kick.at += kick.speed * step
		left -= step
	end
	if kick.at > MOST then
		kick.at = MOST
		kick.speed = math.min(kick.speed, 0)
	end
	return kick.at
end

-- How hard a gun kicks the body, from its view kick in GunConfig (degrees): about 1 for the rifles and the SMG,
-- over 2 for the sniper.
function ShotKick.strength(viewKick: number?): number
	return math.clamp(0.6 + math.sqrt(viewKick or 0.1) * 1.6, 0.8, 2.6)
end

return ShotKick
