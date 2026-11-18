-- Signals between the match server and the systems a match changes, so neither has to require the other.
local joinedEvent = Instance.new("BindableEvent")
local cheatedEvent = Instance.new("BindableEvent")

local MatchHooks = {
	-- (player) A player has just been put into a match: per-match counts, such as movement strikes, start over.
	joined = joinedEvent.Event,
	-- (player, why) A cheat check wants this player out of their match (matches.md: removed from the match and
	-- logged, not kicked from the server).
	cheated = cheatedEvent.Event,
}

function MatchHooks.join(player: Player)
	joinedEvent:Fire(player)
end

function MatchHooks.cheat(player: Player, why: string)
	cheatedEvent:Fire(player, why)
end

return MatchHooks
