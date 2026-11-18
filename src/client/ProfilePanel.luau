-- The Profile page, for the player or anyone else in the server: headshot, name, Credits and Deck
-- Power Rating, then the card index and comments.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local CardCore = ReplicatedStorage:WaitForChild("CardCore")
local CardIndex = require(CardCore:WaitForChild("CardIndex"))
local CardLook = require(CardCore:WaitForChild("CardLook"))
local Fusion = require(CardCore:WaitForChild("Fusion"))
local PackText = require(CardCore:WaitForChild("PackText"))
local Variant = require(CardCore:WaitForChild("Variant"))
local CardData = require(script.Parent.CardData)
local CardGrid = require(script.Parent.CardGrid)
local CardInspect = require(script.Parent.CardInspect)
local CommentsPanel = require(script.Parent.CommentsPanel)
local MenuPanel = require(script.Parent.MenuPanel)
local PanelKit = require(script.Parent.PanelKit)

local HEAD_TOP = 0.025
local HEAD_SIZE = 0.09
local INFO_LEFT = 0.125
local NAME_SIZE = 0.042
local NAME_LINE = 0.065
local NAME_FIT = 0.96
local STATS_LINE = 0.09
local STATS_GAP = 0.13
local STATS_SPACE = 0.02 -- the least room between the Credits and DPR
local TABS_TOP = 0.13
local TABS_HEIGHT = 0.03
local TABS_GAP = 0.008
local GRID_TOP = 0.176
local PAGE_TOP = 0.172

local ProfilePanel = {}

local function header(content: Frame, profile: any)
	local MARGIN, RIGHT = PanelKit.MARGIN, PanelKit.RIGHT
	local unit = MenuPanel.unit()
	local head = Instance.new("ImageLabel")
	head.BackgroundColor3 = PanelKit.INK
	head.BorderSizePixel = 0
	head.Image = `rbxthumb://type=AvatarHeadShot&id={profile.userId}&w=150&h=150`
	head.Position = UDim2.fromOffset(MARGIN * unit, HEAD_TOP * unit)
	head.Size = UDim2.fromOffset(HEAD_SIZE * unit, HEAD_SIZE * unit)
	head.Parent = content

	local name = string.upper(profile.name)
	local measured = PanelKit.label(content, "Title", NAME_SIZE, INFO_LEFT, NAME_LINE)
	measured:set(name)
	local room = (RIGHT - INFO_LEFT) * unit
	if measured:width() > room then
		-- A little under the exact fit: the shrunk name came out about 3% wider than measured, past the margin.
		local size = NAME_SIZE * room / measured:width() * NAME_FIT
		measured:setVisible(false)
		PanelKit.label(content, "Title", size, INFO_LEFT, NAME_LINE):set(name)
	end
	-- Shortened as in the Outpost's corner (1.01K), so even a huge balance leaves room on the line for OWNED.
	local credits = PanelKit.line(content, `CREDITS {PackText.balance(profile.credits)}`, INFO_LEFT, STATS_LINE)
	-- After the Credits however long they run, so a big number can't run into DPR.
	local dprX = math.max(INFO_LEFT + STATS_GAP, INFO_LEFT + credits:width() / unit + STATS_SPACE)
	PanelKit.line(content, `DPR {profile.dpr}`, dprX, STATS_LINE)
	-- In the header, not over the grid: the grid's sixth column fills the panel's right edge.
	local index = CardIndex.build(profile.stacks)
	PanelKit.line(content, string.format("OWNED %02d/%02d", index.owned, index.total), PanelKit.RIGHT, STATS_LINE, true)
end

-- The fuse button under one of your own cards held up: what it would take, greyed out when it can't be done.
-- Spending Chromatic or rarer copies takes a second press. The new card is held up once it's made.
local function fuseAction(cardId: string, tier: string, refresh: () -> ()): any?
	local snapshot = CardData.get()
	if not snapshot then
		return nil
	end
	local offer = Fusion.offer(snapshot.stacks, snapshot.credits, cardId, tier)
	if not offer then
		return nil
	end
	local into = CardLook.tierName(offer.nextTier)
	if not offer.enough then
		return { text = `FUSE {offer.have}/{offer.needed} INTO {into}`, disabled = true }
	elseif not offer.affordable then
		return { text = `FUSING NEEDS {offer.fee} CR`, disabled = true }
	end
	local function send(includeVariants: boolean, relabel: (any) -> ())
		relabel({ text = "FUSING", disabled = true })
		task.spawn(function()
			local reply = CardData.ask("Fuse", {
				cardId = cardId,
				tier = tier,
				useCatalyst = false,
				includeVariants = includeVariants,
			})
			if reply.ok then
				local made = reply.result
				CardInspect.open({ cardId = made.cardId, tier = made.tier, variant = made.variant, count = 1 })
				refresh()
			else
				relabel({ text = "COULD NOT FUSE", disabled = true })
			end
		end)
	end
	local text = `FUSE {offer.needed} INTO {into} - {offer.fee} CR`
	if offer.spendsVariants then
		return {
			text = text,
			run = function(relabel)
				relabel({
					text = "SPENDS VARIANTS - PRESS AGAIN",
					run = function(again)
						send(true, again)
					end,
				})
			end,
		}
	end
	return {
		text = text,
		run = function(relabel)
			send(false, relabel)
		end,
	}
end

-- refresh, given only on your own profile, redraws it after a fusion and offers the fuse button.
local function cell(grid: ScrollingFrame, column: number, row: number, options: any, refresh: (() -> ())?)
	CardGrid.add(grid, column, row, options, function()
		-- Held up, a card shows its lowest serial where the index showed how many you have.
		local held = table.clone(options)
		if held.lowest then
			held.corner = nil
			held.serial = held.lowest
		end
		if refresh and options.count > 0 then
			held.action = fuseAction(options.cardId, options.tier, refresh)
		end
		CardInspect.open(held)
	end)
end

-- Nobody can own a Zero-Day yet, so Studio shows each card as one in a row of its own.
local function zeroDayPreviews(grid: ScrollingFrame, cards: { any }, row: number)
	for column, card in cards do
		cell(grid, column, row, { cardId = card.cardId, tier = "Field", variant = Variant.ZeroDay, count = 0, serial = 1 })
	end
end

local function cardGrid(page: Frame, profile: any, refresh: (() -> ())?)
	local index = CardIndex.build(profile.stacks)
	local tiers = #index.cards[1].tiers
	local preview = RunService:IsStudio()
	local grid = CardGrid.new(page, GRID_TOP, if preview then tiers + 1 else tiers, #index.cards)
	for column, card in index.cards do
		for row, entry in card.tiers do
			local owned = entry.count > 0
			cell(grid, column, row, {
				cardId = card.cardId,
				tier = entry.tier,
				variant = entry.variant,
				count = entry.count,
				corner = if owned then `X{entry.count}` else nil,
				lowest = profile.lowest and profile.lowest[`{card.cardId}:{entry.tier}:{entry.variant}`],
				ghost = not owned,
			}, refresh)
		end
	end
	if preview then
		zeroDayPreviews(grid, index.cards, tiers + 1)
	end
end

local function tabs(content: Frame, profile: any, chosen: string)
	local MARGIN, RIGHT = PanelKit.MARGIN, PanelKit.RIGHT
	local width = (RIGHT - MARGIN - TABS_GAP) / 2
	for index, name in { "CARD INDEX", "COMMENTS" } do
		local x = MARGIN + (index - 1) * (width + TABS_GAP)
		local button = PanelKit.button(content, name, x, TABS_TOP, width, TABS_HEIGHT, { active = name == chosen })
		button.Activated:Connect(function()
			ProfilePanel.draw(content, profile, name)
		end)
	end
end

function ProfilePanel.draw(content: Frame, profile: any, tab: string)
	content:ClearAllChildren()
	header(content, profile)
	tabs(content, profile, tab)
	local page = Instance.new("Frame")
	page.BackgroundTransparency = 1
	page.Size = UDim2.fromScale(1, 1)
	page.Parent = content
	if tab == "COMMENTS" then
		CommentsPanel.fill(page, profile, PAGE_TOP)
	else
		local own = profile.userId == Players.LocalPlayer.UserId
		cardGrid(page, profile, if own
			then function()
				task.spawn(function()
					local reply = CardData.ask("GetProfile", profile.userId)
					if reply.ok and content.Parent then
						ProfilePanel.draw(content, reply.result, "CARD INDEX")
					end
				end)
			end
			else nil)
	end
end

-- Draws the profile for this user, or a message if they've left.
function ProfilePanel.fill(content: Frame, userId: number)
	PanelKit.line(content, "LOADING", PanelKit.MARGIN, 0.05)
	task.spawn(function()
		local reply = CardData.ask("GetProfile", userId)
		if not content.Parent then
			return
		end
		if reply.ok then
			ProfilePanel.draw(content, reply.result, "CARD INDEX")
		else
			content:ClearAllChildren()
			PanelKit.line(content, "PLAYER NOT FOUND", PanelKit.MARGIN, 0.05)
		end
	end)
end

return ProfilePanel
