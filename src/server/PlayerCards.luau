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

-- Saves and waits to hear it landed, for a purchase that mustn't count until it has.
function PlayerCards.saveAndWait(player: Player): boolean
	local profile = profiles[player]
	if not profile then
		return false
	end
	local saved = false
	local connection = profile.OnAfterSave:Connect(function()
		saved = true
	end)
	profile:Save()
	local deadline = os.clock() + SAVE_WAIT
	while not saved and os.clock() < deadline do
		task.wait(0.1)
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
