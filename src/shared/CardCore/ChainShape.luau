-- The shape of Switchback's chain as it flies (River, 2026-11-12: a 3D chain "that has physics", like a thrown
-- hook, with a technology feel). Pure numbers: Abilities.client.luau places the links from them, and the server
-- uses the same flight time to swap the two players when the chain lands, not before.
local ChainShape = {
	SPEED = 260, -- studs a second
	LINK = 1.15, -- studs from one link to the next
	MOST_LINKS = 80,
	HOLD = 0.12, -- seconds the chain stays taut on its target before it lets go
	RELEASE = 0.3, -- seconds it takes to break apart after a hit, or wind back in after a miss
	WHIP = 1.5, -- studs the middle swings side to side while it flies
	WAVES = 2.5, -- waves along its length
	WHIP_RATE = 22, -- how fast they run down it, radians a second
	SAG = 2.2, -- studs the middle hangs before it pulls tight
}

-- How long the chain takes to cover this many studs.
function ChainShape.flight(length: number): number
	return length / ChainShape.SPEED
end

-- How many links are out when the head is this far from the hand.
function ChainShape.links(reached: number): number
	return math.clamp(math.floor(reached / ChainShape.LINK), 0, ChainShape.MOST_LINKS)
end

-- How far the head is from the hand at this age, for a chain thrown `length` studs. After a miss it winds back.
function ChainShape.reached(age: number, length: number, hit: boolean): number
	local flight = ChainShape.flight(length)
	if age <= flight then
		return length * math.max(age, 0) / flight
	elseif age <= flight + ChainShape.HOLD or hit then
		return length
	end
	return length * math.max(1 - (age - flight - ChainShape.HOLD) / ChainShape.RELEASE, 0)
end

-- How tight the chain is, 0 slack to 1 taut: slack in flight, pulled tight as it lands.
function ChainShape.tension(age: number, length: number): number
	local flight = ChainShape.flight(length)
	return math.clamp((age - flight * 0.7) / (flight * 0.3 + ChainShape.HOLD * 0.5), 0, 1)
end

-- Where a link sits off the straight line: sideways swing and downward hang, in studs. `along` is 0 at the hand
-- and 1 at the head. Both ends are pinned, so the hand and the head never leave the line.
function ChainShape.offset(along: number, age: number, length: number): (number, number)
	local pinned = math.sin(math.pi * math.clamp(along, 0, 1))
	local slack = 1 - ChainShape.tension(age, length)
	local scale = math.min(length / 30, 1) -- a short throw has less chain to swing
	local swing = math.sin(along * ChainShape.WAVES * 2 * math.pi - age * ChainShape.WHIP_RATE)
	return swing * ChainShape.WHIP * pinned * slack * scale, -ChainShape.SAG * pinned * slack * scale
end

-- How see-through the chain is: solid until it has landed and held, then gone over the release (a hit only; a
-- miss winds back in solid).
function ChainShape.fade(age: number, length: number, hit: boolean): number
	if not hit then
		return 0
	end
	return math.clamp((age - ChainShape.flight(length) - ChainShape.HOLD) / ChainShape.RELEASE, 0, 1)
end

-- When the whole effect is over.
function ChainShape.life(length: number): number
	return ChainShape.flight(length) + ChainShape.HOLD + ChainShape.RELEASE
end

return ChainShape
