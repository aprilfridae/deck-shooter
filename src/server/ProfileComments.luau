-- Stores comments on profiles. They have their own DataStore, because ProfileStore locks each save
-- to its owner's session, so another player's save can't be written from here.
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TextChatService = game:GetService("TextChatService")
local TextService = game:GetService("TextService")

local Comments = require(ReplicatedStorage:WaitForChild("CardCore"):WaitForChild("Comments"))

local store = DataStoreService:GetDataStore("ProfileComments_v1")
local reports = DataStoreService:GetDataStore("ProfileCommentReports_v1")

local memory: { [number]: { any } } = {} -- stands in for the DataStore in Studio without API access
local lastPost: { [Player]: number } = {}

local ProfileComments = {}

local function keyOf(ownerId: number): string
	return `Profile_{ownerId}`
end

local function read(ownerId: number): { any }?
	local ok, saved = pcall(function()
		return store:GetAsync(keyOf(ownerId))
	end)
	if ok then
		return saved or memory[ownerId] or {}
	elseif RunService:IsStudio() then
		return memory[ownerId] or {}
	end
	return nil
end

local function change(ownerId: number, edit: ({ any }) -> ()): boolean
	local ok = pcall(function()
		store:UpdateAsync(keyOf(ownerId), function(saved)
			local list = saved or {}
			edit(list)
			return list
		end)
	end)
	if ok then
		return true
	elseif RunService:IsStudio() then
		memory[ownerId] = memory[ownerId] or {}
		edit(memory[ownerId])
		return true
	end
	return false
end

local function canChat(player: Player): boolean
	local ok, allowed = pcall(function()
		return TextChatService:CanUserChatAsync(player.UserId)
	end)
	return if ok then allowed else RunService:IsStudio()
end

-- The filter only accepts players on this server, and an author may have left, so the saved text
-- has already been filtered for everyone. It's filtered again for whoever reads it.
local function filteredForAll(text: string, player: Player): string?
	local ok, shown = pcall(function()
		return TextService:FilterStringAsync(text, player.UserId):GetNonChatStringForBroadcastAsync()
	end)
	return if ok then shown else nil
end

local function filteredFor(text: string, reader: Player): string?
	local ok, shown = pcall(function()
		return TextService:FilterStringAsync(text, reader.UserId):GetNonChatStringForUserAsync(reader.UserId)
	end)
	return if ok then shown else nil
end

-- Every comment on a profile that passes the filter for this reader.
function ProfileComments.view(reader: Player, ownerId: number): { any }?
	local list = read(ownerId)
	if not list then
		return nil
	end
	local shown = {}
	for _, comment in list do
		local text = filteredFor(comment.text, reader)
		if text then
			table.insert(shown, {
				authorId = comment.authorId,
				authorName = comment.authorName,
				text = text,
			})
		end
	end
	return shown
end

function ProfileComments.post(player: Player, ownerId: number, text: string, commentsOff: boolean): (boolean, string?)
	local allowed, code = Comments.canPost(player.UserId, ownerId, commentsOff)
	if not allowed then
		return false, code
	end
	local now = os.clock()
	if not Comments.cooled(lastPost[player], now) then
		return false, "TooSoon"
	end
	if not canChat(player) then
		return false, "CantChat"
	end
	local clean = filteredForAll(text, player)
	if not clean then
		return false, "FilterFailed"
	end
	local saved = change(ownerId, function(list)
		Comments.put(list, { authorId = player.UserId, authorName = player.Name, text = clean, at = os.time() })
	end)
	if not saved then
		return false, "StoreFailed"
	end
	lastPost[player] = now
	return true, nil
end

function ProfileComments.delete(ownerId: number, authorId: number): boolean
	return change(ownerId, function(list)
		Comments.remove(list, authorId)
	end)
end

-- Saves the comment, its author and the reporter for River to review.
function ProfileComments.report(reporter: Player, ownerId: number, authorId: number): boolean
	local list = read(ownerId)
	local comment = list and Comments.find(list, authorId)
	if not comment then
		return false
	end
	if RunService:IsStudio() then
		return true
	end
	return (
		pcall(function()
			reports:SetAsync(`Report_{ownerId}_{authorId}_{reporter.UserId}`, {
				owner = ownerId,
				author = authorId,
				authorName = comment.authorName,
				text = comment.text,
				reporter = reporter.UserId,
				at = os.time(),
			})
		end)
	)
end

Players.PlayerRemoving:Connect(function(player)
	lastPost[player] = nil
end)

return ProfileComments
