-- Lets the movement guard know a fast move is about to happen legally.
local given = Instance.new("BindableEvent")
local allowed = Instance.new("BindableEvent")

local MoveGrace = {
	given = given.Event,
	allowed = allowed.Event,
}

-- The guard looks away for these seconds: for teleports, where any distance is legal.
function MoveGrace.give(player: Player, seconds: number)
	given:Fire(player, seconds)
end

-- The guard keeps checking, but allows a launch at this velocity on top of ordinary movement for these seconds.
-- For pushes whose size the server knows, so a cheat can't use the time to go anywhere.
function MoveGrace.allow(player: Player, seconds: number, velocity: Vector3)
	allowed:Fire(player, seconds, velocity)
end

return MoveGrace
