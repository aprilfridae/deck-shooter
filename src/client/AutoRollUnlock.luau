-- Unlocks auto roll: the favorite first, and the Fridae Studios group if that doesn't work.
-- AvatarEditorService isn't officially for experiences, so the group is there for when it breaks.
local AvatarEditorService = game:GetService("AvatarEditorService")
local GroupService = game:GetService("GroupService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("CardCore"):WaitForChild("Config"))
local CardData = require(script.Parent.CardData)

local prompting = false

local AutoRollUnlock = {}

local function askGroup()
	pcall(function()
		GroupService:PromptJoinAsync(Config.GroupId)
	end)
	CardData.ask("CheckGroup")
end

-- Shows the favorite prompt, and the group's if that one fails or is turned down.
function AutoRollUnlock.prompt()
	if prompting then
		return
	end
	prompting = true
	local finished = Instance.new("BindableEvent")
	local connection = AvatarEditorService.PromptSetFavoriteCompleted:Once(function(result: Enum.AvatarPromptResult)
		finished:Fire(result == Enum.AvatarPromptResult.Success)
	end)
	local shown = pcall(function()
		AvatarEditorService:PromptSetFavorite(game.PlaceId, Enum.AvatarItemType.Asset, true)
	end)
	if shown then
		local favorited = finished.Event:Wait()
		if favorited then
			CardData.ask("ClaimFavorite")
		else
			askGroup()
		end
	else
		connection:Disconnect()
		askGroup()
	end
	finished:Destroy()
	prompting = false
end

task.spawn(function()
	local ok, favorited = pcall(function()
		return AvatarEditorService:GetFavorite(game.PlaceId, Enum.AvatarItemType.Asset)
	end)
	if ok and favorited then
		CardData.ask("ClaimFavorite")
	end
end)

return AutoRollUnlock
