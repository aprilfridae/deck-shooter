-- Robux: the Open All product and the Auto Open gamepass. Odds and piles are in CardCore.Packs.
local MarketplaceService = game:GetService("MarketplaceService")
local PolicyService = game:GetService("PolicyService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CardCore = ReplicatedStorage:WaitForChild("CardCore")
local Config = require(CardCore.Config)
local Packs = require(CardCore.Packs)
local PackServer = require(script.Parent.PackServer)
local PlayerCards = require(script.Parent.PlayerCards)

local RECEIPT_WAIT = 20 -- seconds a receipt waits for a save that's still loading

local Purchases = {}

-- Paying for random items is restricted in some places. If Roblox can't say, assume it is.
local function checkPolicy(player: Player)
	local ok, policy = pcall(function()
		return PolicyService:GetPolicyInfoForPlayerAsync(player)
	end)
	player:SetAttribute("OpenAllHidden", not ok or policy.ArePaidRandomItemsRestricted)
end

local function checkAutoOpen(player: Player)
	if Config.AutoOpenPass == 0 then
		return
	end
	local ok, owned = pcall(function()
		return MarketplaceService:UserOwnsGamePassAsync(player.UserId, Config.AutoOpenPass)
	end)
	if ok and owned then
		player:SetAttribute("AutoOpenOwned", true)
	end
end

function Purchases.start(remote: (string, (Player, any, any) -> any) -> (), rng: () -> number)
	-- Roblox calls this again until it gets an answer, so nothing here may pay out twice.
	MarketplaceService.ProcessReceipt = function(info: any)
		if info.ProductId ~= Config.OpenAllProduct then
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		local player = Players:GetPlayerByUserId(info.PlayerId)
		-- A receipt can come in while the player's save is still loading, on a join or a rejoin. Waiting a little
		-- pays it now instead of on their next join.
		local data = player and PlayerCards.get(player)
		local giveUpAt = os.clock() + RECEIPT_WAIT
		while player and not data and player.Parent == Players and os.clock() < giveUpAt do
			task.wait(0.5)
			data = PlayerCards.get(player)
		end
		if not player or not data then
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		local paid, status, result = pcall(Packs.redeem, data, info.PurchaseId, rng)
		if not paid then
			warn(`Open All receipt {info.PurchaseId} failed, Roblox will ask again: {status}`)
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		PlayerCards.changed(player)
		if status == "Opened" then
			PackServer.announce(player, { kind = "OpenedAll", result = result })
		elseif status == "Banked" then
			PackServer.announce(player, { kind = "Banked" })
		end
		-- If the save doesn't land, Roblox asks again, and the receipt stops it paying twice.
		if not PlayerCards.saveAndWait(player) then
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end

	remote("OpenAll", function(player, data)
		if Packs.pile(data) == 0 then
			return { ok = false, code = "NoPacks" }
		end
		local spent, result = Packs.useCredit(data, rng)
		if spent then
			PlayerCards.changed(player)
			PlayerCards.save(player)
			PackServer.announce(player, { kind = "OpenedAll", result = result })
			return { ok = true }
		elseif player:GetAttribute("OpenAllHidden") ~= false then -- also while the policy check hasn't answered
			return { ok = false, code = "Blocked" }
		elseif Config.OpenAllProduct == 0 then
			return { ok = false, code = "NotReady" }
		end
		MarketplaceService:PromptProductPurchase(player, Config.OpenAllProduct)
		return { ok = true }
	end)

	remote("BuyAutoOpen", function(player)
		if Config.AutoOpenPass == 0 then
			return { ok = false, code = "NotReady" }
		end
		MarketplaceService:PromptGamePassPurchase(player, Config.AutoOpenPass)
		return { ok = true }
	end)

	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player: Player, passId: number, bought: boolean)
		if bought and passId == Config.AutoOpenPass then
			player:SetAttribute("AutoOpenOwned", true)
		end
	end)

	PlayerCards.profileLoaded:Connect(function(player: Player)
		task.spawn(checkPolicy, player)
		task.spawn(checkAutoOpen, player)
	end)
end

return Purchases
