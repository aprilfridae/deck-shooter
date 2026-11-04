-- Lets the movement guard know a fast move is about to happen legally.
local given = Instance.new("BindableEvent")

local MoveGrace = {
	given = given.Event,
}

function MoveGrace.give(player: Player, seconds: number)
	given:Fire(player, seconds)
end

return MoveGrace
