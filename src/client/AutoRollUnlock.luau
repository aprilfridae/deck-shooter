-- Unlocks auto roll: the favorite first, and the Fridae Studios group if that doesn't work.
-- AvatarEditorService isn't officially for experiences, so the group is there for when it breaks.
local AvatarEditorService = game:GetService("AvatarEditorService")
local GroupService = game:GetService("GroupService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("CardCore"):WaitForChild("Config"))
local CardData = require(script.Parent.CardData)

local PROMPT_WAIT = 15 -- seconds, because the service isn't supported and may never answer

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
	local result: Enum.AvatarPromptResult? = nil
	local connection = AvatarEditorService.PromptSetFavoriteCompleted:Once(function(answer: Enum.AvatarPromptResult)
		result = answer
	end)
	local shown = pcall(function()
		AvatarEditorService:PromptSetFavorite(game.PlaceId, Enum.AvatarItemType.Asset, true)
	end)
	local deadline = os.clock() + PROMPT_WAIT
	while shown and result == nil and os.clock() < deadline do
		task.wait(0.1)
	end
	connection:Disconnect()
	if result == Enum.AvatarPromptResult.Success then
		CardData.ask("ClaimFavorite")
	else
		askGroup()
	end
	prompting = false
end

task.spawn(function()
	while not CardData.get() do -- the server refuses until the save has loaded
		CardData.changed:Wait()
	end
	local ok, favorited = pcall(function()
		return AvatarEditorService:GetFavorite(game.PlaceId, Enum.AvatarItemType.Asset)
	end)
	if ok and favorited then
		CardData.ask("ClaimFavorite")
	end
end)

return AutoRollUnlock
