-- Loads and saves each player's card data through ProfileStore.
-- Session locking stops the same save being live on two servers, so cards can't be duplicated.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CardCore = ReplicatedStorage:WaitForChild("CardCore")
local Dpr = require(CardCore.Dpr)
local Income = require(CardCore.Income)
local SaveData = require(CardCore.SaveData)
local ProfileStore = require(script.Parent.vendor.ProfileStore)

local PlayerStore = ProfileStore.New("PlayerData_v1", {})
local profiles: { [Player]: any } = {}

local SAVE_WAIT = 15 -- seconds
local SAVE_RETRY = 4 -- seconds before asking for the save again
local SERVER_ID = game:GetService("HttpService"):GenerateGUID(false) -- tells this server's save stamps from another's
local saveCount = 0

local remotes = Instance.new("Folder")
remotes.Name = "CardCoreRemotes"
local snapshotEvent = Instance.new("RemoteEvent")
snapshotEvent.Name = "Snapshot"
snapshotEvent.Parent = remotes

local profileLoaded = Instance.new("BindableEvent")

local PlayerCards = {
	remotes = remotes,
	profileLoaded = profileLoaded.Event,
}

function PlayerCards.get(player: Player): any?
	local profile = profiles[player]
	return if profile then profile.Data else nil
end

function PlayerCards.snapshot(player: Player): any?
	local data = PlayerCards.get(player)
	if not data then
		return nil
	end
	-- The lowest serial in each stack: the one a card shows.
	local lowest = {}
	for key, held in data.serials do
		lowest[key] = held.runs[1]
	end
	return {
		credits = data.credits,
		stacks = data.stacks,
		lowest = lowest,
		market = { listed = data.market.listed, bids = data.market.bids }, -- cards up for auction and Credits set aside
		deck = data.deck,
		catalysts = data.catalysts,
		dpr = Dpr.compute(data.deck, data.gunLevels),
		ratePerSecond = Income.ratePerSecond(data),
		class = data.class,
		rifle = data.rifle,
		packs = data.packs,
		rebirths = data.rebirths,
		openAllCredits = data.openAllCredits,
	}
end

function PlayerCards.changed(player: Player)
	local snapshot = PlayerCards.snapshot(player)
	if snapshot then
		snapshotEvent:FireClient(player, snapshot)
	end
end

-- Asks ProfileStore to write now, for changes that can't wait for its next save.
function PlayerCards.save(player: Player)
	local profile = profiles[player]
	if profile then
		profile:Save()
	end
end

-- Saves and waits to hear that a save holding the data as it is now has landed, for changes that mustn't count
-- until they are stored: a purchase, a card going up for auction, a bid.
-- ProfileStore's signal fires for every save of the profile, including one already on its way that was taken
-- before the change. So the data is stamped first, and only a save carrying that stamp or a later one counts.
function PlayerCards.saveAndWait(player: Player): boolean
	local profile = profiles[player]
	if not profile then
		return false
	end
	saveCount += 1
	local mark = saveCount
	profile.Data.saveMark = { SERVER_ID, mark }
	local saved = false
	local connection = profile.OnAfterSave:Connect(function(last: any)
		local stamp = type(last) == "table" and last.saveMark
		if type(stamp) == "table" and stamp[1] == SERVER_ID and type(stamp[2]) == "number" and stamp[2] >= mark then
			saved = true
		end
	end)
	profile:Save()
	local deadline = os.clock() + SAVE_WAIT
	local asked = os.clock()
	while not saved and os.clock() < deadline and profiles[player] == profile do
		task.wait(0.1)
		-- A save that fails isn't announced or retried, so ask again now and then.
		if not saved and os.clock() - asked >= SAVE_RETRY then
			asked = os.clock()
			profile:Save()
		end
	end
	connection:Disconnect()
	return saved
end

local function onPlayerAdded(player: Player)
	local profile = PlayerStore:StartSessionAsync(`Player_{player.UserId}`, {
		Cancel = function()
			return player.Parent ~= Players
		end,
	})
	if not profile then
		player:Kick("Your card data could not be loaded. Please rejoin.")
		return
	end

	local data, code = SaveData.load(profile.Data)
	if not data then
		-- A newer build wrote this save, so leave it exactly as it is.
		warn(`[CardCore] refused save for {player.UserId}: {code}`)
		profile:EndSession()
		player:Kick("This server is out of date. Please rejoin.")
		return
	end

	profile.Data = data
	profile:AddUserId(player.UserId)
	profile.OnSessionEnd:Connect(function()
		profiles[player] = nil
		player:Kick("Your card data session ended. Please rejoin.")
	end)

	if player.Parent ~= Players then
		profile:EndSession()
		return
	end

	profiles[player] = profile
	print(`[CardCore] profile loaded for {player.UserId}`)
	PlayerCards.changed(player)
	profileLoaded:Fire(player)
end

local function onPlayerRemoving(player: Player)
	local profile = profiles[player]
	if profile then
		profile:EndSession()
	end
end

function PlayerCards.start()
	remotes.Parent = ReplicatedStorage
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
end

function PlayerCards.loaded(): { Player }
	local players = {}
	for player in profiles do
		table.insert(players, player)
	end
	return players
end

return PlayerCards
