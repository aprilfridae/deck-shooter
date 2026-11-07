-- The Profile page, for the player or anyone else in the server: headshot, name, Credits and Deck
-- Power Rating, then the card index and comments.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local CardCore = ReplicatedStorage:WaitForChild("CardCore")
local CardIndex = require(CardCore:WaitForChild("CardIndex"))
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
local STATS_LINE = 0.09
local STATS_GAP = 0.13
local TABS_TOP = 0.13
local TABS_HEIGHT = 0.03
local TABS_GAP = 0.008
local COUNT_SIZE = 0.04
local COUNT_LINE = 0.215
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
		local size = NAME_SIZE * room / measured:width()
		measured:setVisible(false)
		PanelKit.label(content, "Title", size, INFO_LEFT, NAME_LINE):set(name)
	end
	PanelKit.line(content, `CREDITS {profile.credits}`, INFO_LEFT, STATS_LINE)
	PanelKit.line(content, `DPR {profile.dpr}`, INFO_LEFT + STATS_GAP, STATS_LINE)
end

local function cell(grid: ScrollingFrame, column: number, row: number, options: any)
	CardGrid.add(grid, column, row, options, function()
		CardInspect.open(options)
	end)
end

-- Nobody can own a Zero-Day yet, so Studio shows each card as one in a row of its own.
local function zeroDayPreviews(grid: ScrollingFrame, cards: { any }, row: number)
	for column, card in cards do
		cell(grid, column, row, { cardId = card.cardId, tier = "Field", variant = Variant.ZeroDay, count = 0, serial = 1 })
	end
end

local function cardGrid(page: Frame, profile: any)
	local RIGHT = PanelKit.RIGHT
	local index = CardIndex.build(profile.stacks)
	PanelKit.label(page, "Title", COUNT_SIZE, RIGHT, COUNT_LINE, true)
		:set(string.format("%02d/%02d", index.owned, index.total))
	PanelKit.label(page, "LabelBold", PanelKit.SMALL_SIZE, RIGHT, COUNT_LINE + 0.016, true):set("OWNED")
	local tiers = #index.cards[1].tiers
	local preview = RunService:IsStudio()
	local grid = CardGrid.new(page, GRID_TOP, if preview then tiers + 1 else tiers)
	for column, card in index.cards do
		for row, entry in card.tiers do
			local owned = entry.count > 0
			cell(grid, column, row, {
				cardId = card.cardId,
				tier = entry.tier,
				variant = entry.variant,
				count = entry.count,
				corner = if owned then `X{entry.count}` else nil,
				ghost = not owned,
			})
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
		cardGrid(page, profile)
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
