-- The Profile page, for the player or anyone else in the server: headshot, name, Credits and Deck
-- Power Rating, then the card index and comments.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CardCore = ReplicatedStorage:WaitForChild("CardCore")
local CardIndex = require(CardCore:WaitForChild("CardIndex"))
local Guns = ReplicatedStorage:WaitForChild("Guns")
local CardData = require(script.Parent.CardData)
local CommentsPanel = require(script.Parent.CommentsPanel)
local MenuPanel = require(script.Parent.MenuPanel)
local PanelKit = require(script.Parent.PanelKit)

local TIER_NAMES = { Field = "FIELD", BlackSite = "BLACK SITE", Prototype = "PROTOTYPE" }

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
local GRID_GAP = 0.006
local CELL_WIDTH = 0.0755 -- a playing card's shape, with CELL_HEIGHT
local CELL_HEIGHT = 0.1057
local CELL_MARGIN = 0.008 -- inside a card, on all four sides
local COPIES_SIZE = 0.02
local NAME_SIZE_SMALL = 0.0082
local NAME_STEP = 0.012
local TIER_SIZE = 0.0068
local GHOST_INK = PanelKit.INK:Lerp(PanelKit.PAPER, 0.6)
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

local function cardGrid(page: Frame, profile: any)
	local MARGIN, RIGHT = PanelKit.MARGIN, PanelKit.RIGHT
	local index = CardIndex.build(profile.stacks)
	PanelKit.label(page, "Title", COUNT_SIZE, RIGHT, COUNT_LINE, true)
		:set(string.format("%02d/%02d", index.owned, index.total))
	PanelKit.label(page, "LabelBold", PanelKit.SMALL_SIZE, RIGHT, COUNT_LINE + 0.016, true):set("OWNED")
	local width = CELL_WIDTH
	for column, card in index.cards do
		local x = MARGIN + (column - 1) * (width + GRID_GAP)
		for row, entry in card.tiers do
			local top = GRID_TOP + (row - 1) * (CELL_HEIGHT + GRID_GAP)
			local owned = entry.count > 0
			local cell = PanelKit.block(page, x, top, width, CELL_HEIGHT, PanelKit.PAPER)
			cell.BackgroundTransparency = if owned then 0 else 1
			local stroke = Instance.new("UIStroke")
			stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
			stroke.Color = if owned then PanelKit.INK else GHOST_INK
			stroke.Parent = cell
			local ink = if owned then PanelKit.INK else GHOST_INK
			local firstLine = CELL_MARGIN + NAME_SIZE_SMALL * PanelKit.CAP_HEIGHT
			local words = string.split(string.upper(card.name), " ")
			for line, word in words do
				local y = firstLine + (line - 1) * NAME_STEP
				PanelKit.cardLabel(cell, "LabelBold", NAME_SIZE_SMALL, CELL_MARGIN, y, ink):set(word)
			end
			local tierLine = firstLine + 2 * NAME_STEP + 0.002 -- under two lines, so tiers line up across cards
			PanelKit.cardLabel(cell, "Label", TIER_SIZE, CELL_MARGIN, tierLine, ink):set(TIER_NAMES[entry.tier])
			if owned then
				PanelKit.cardLabel(cell, "Title", COPIES_SIZE, CELL_MARGIN, CELL_HEIGHT - CELL_MARGIN):set(`X{entry.count}`)
			end
		end
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
