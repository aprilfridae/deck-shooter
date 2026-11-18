-- What the Outpost script (Outpost.server.luau) lets other server code do with players' places and bodies. The
-- script fills in the functions when it starts; anything that needs them calls Places.ready() first.
--
-- Matches use it to send players to their arena and back, and to hold off the usual respawn: in a match a dead
-- player stays dead until the next round starts.

local readyEvent = Instance.new("BindableEvent")

local Places = {
	-- Filled in by Outpost.server.luau.
	setZone = nil :: ((Player, string) -> ())?,
	loadBody = nil :: ((Player) -> ())?,
	travel = nil :: ((Player, string) -> ())?,
	-- A spawn that wins over the zone's own, for a player in a match. Set by the match, cleared when it ends.
	spawnOverride = {} :: { [Player]: SpawnLocation },
	-- Players whose death doesn't bring them back after the respawn time.
	holdRespawn = {} :: { [Player]: boolean },
	isReady = false,
}

function Places.markReady()
	Places.isReady = true
	readyEvent:Fire()
end

function Places.ready()
	if not Places.isReady then
		readyEvent.Event:Wait()
	end
end

return Places
