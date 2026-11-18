-- A scrolling grid of cards, used by the Profile index and for choosing a card in the Loadout.
-- Each card is a column with one row per tier. Only so many columns fit across the panel, so the cards wrap into
-- bands, one under the next, and the grid scrolls down through them (with 10 cards the last four used to run off
-- the panel's right edge, where nothing could reach them). The cards are shared out evenly between the bands and
-- sized so every band fills the panel's width: 10 cards make two bands of 5, not 6 and a short 4 (River, 2026-11-17).
local CardFace = require(script.Parent.CardFace)
local MenuPanel = require(script.Parent.MenuPanel)
local PanelKit = require(script.Parent.PanelKit)

local GAP = 0.006
local CELL_WIDTH = 0.0661 -- the smallest a card is drawn, with CELL_HEIGHT its shape
local CELL_HEIGHT = 0.1057
local BAND_GAP = 0.02 -- between one band of cards and the next, so each band reads as its own
local BOTTOM_ROOM = 0.03 -- under the last band, so it can be scrolled clear of the panel's edge
local BUTTON_LAYER = 6 -- above the card's shine

local CardGrid = {}

-- How many cards go across, and how wide each is drawn, for this many cards.
function CardGrid.layout(cards: number): (number, number)
	local room = PanelKit.RIGHT - PanelKit.MARGIN
	local most = math.max(1, math.floor((room + GAP) / (CELL_WIDTH + GAP)))
	local bands = math.ceil(math.max(1, cards) / most)
	local across = math.ceil(math.max(1, cards) / bands)
	return across, (room + GAP) / across - GAP
end

-- Scrolls once there are more rows than fit on the page. rows is the rows each card has (one per tier, and any
-- extra), and cards how many cards there are, which sets how many bands they wrap into.
function CardGrid.new(page: Instance, top: number, rows: number, cards: number?): ScrollingFrame
	local unit = MenuPanel.unit()
	local count = cards or 1
	local across, width = CardGrid.layout(count)
	local height = width * CELL_HEIGHT / CELL_WIDTH
	local bands = math.ceil(count / across)
	local total = bands * rows * (height + GAP) + (bands - 1) * BAND_GAP + BOTTOM_ROOM
	local grid = Instance.new("ScrollingFrame")
	grid.BackgroundTransparency = 1
	grid.BorderSizePixel = 0
	grid.CanvasSize = UDim2.fromOffset(0, total * unit)
	grid.Position = UDim2.fromOffset(0, top * unit)
	grid.ScrollBarImageColor3 = PanelKit.INK
	grid.ScrollBarThickness = 3
	grid.ScrollingDirection = Enum.ScrollingDirection.Y
	grid.ElasticBehavior = Enum.ElasticBehavior.Never
	grid.Size = UDim2.new(1, 0, 1, -top * unit)
	grid:SetAttribute("Rows", rows)
	grid:SetAttribute("Across", across)
	grid:SetAttribute("CellWidth", width)
	grid.Parent = page
	return grid
end

-- Adds a card, taking CardFace's options. column is the card's place in the list, row its tier's. With onClick,
-- the card can be clicked.
function CardGrid.add(grid: ScrollingFrame, column: number, row: number, options: any, onClick: (() -> ())?)
	local unit = MenuPanel.unit()
	local rows = grid:GetAttribute("Rows") or row
	local across = grid:GetAttribute("Across") or 1
	local width = grid:GetAttribute("CellWidth") or CELL_WIDTH
	local height = width * CELL_HEIGHT / CELL_WIDTH
	local band = (column - 1) // across
	local x = PanelKit.MARGIN + ((column - 1) % across) * (width + GAP)
	local top = (band * rows + row - 1) * (height + GAP) + band * BAND_GAP
	options.width = width * unit
	options.position = UDim2.fromOffset(x * unit, top * unit)
	local face = CardFace.new(grid, options)
	if onClick then
		local button = PanelKit.hitBox(face, 0, 0, width, height)
		button.ZIndex = BUTTON_LAYER
		button.Activated:Connect(onClick)
	end
end

return CardGrid
