-- A scrolling grid of cards, used by the Profile index and for choosing a card in the Loadout.
local CardFace = require(script.Parent.CardFace)
local MenuPanel = require(script.Parent.MenuPanel)
local PanelKit = require(script.Parent.PanelKit)

local GAP = 0.006
local CELL_WIDTH = 0.0661 -- a card's shape, with CELL_HEIGHT
local CELL_HEIGHT = 0.1057
local BUTTON_LAYER = 6 -- above the card's shine

local CardGrid = {}

-- Scrolls once there are more rows than fit on the page.
function CardGrid.new(page: Instance, top: number, rows: number): ScrollingFrame
	local unit = MenuPanel.unit()
	local grid = Instance.new("ScrollingFrame")
	grid.BackgroundTransparency = 1
	grid.BorderSizePixel = 0
	grid.CanvasSize = UDim2.fromOffset(0, rows * (CELL_HEIGHT + GAP) * unit)
	grid.Position = UDim2.fromOffset(0, top * unit)
	grid.ScrollBarImageColor3 = PanelKit.INK
	grid.ScrollBarThickness = 3
	grid.ScrollingDirection = Enum.ScrollingDirection.Y
	grid.Size = UDim2.new(1, 0, 1, -top * unit)
	grid.Parent = page
	return grid
end

-- Adds a card, taking CardFace's options. With onClick, the card can be clicked.
function CardGrid.add(grid: ScrollingFrame, column: number, row: number, options: any, onClick: (() -> ())?)
	local unit = MenuPanel.unit()
	local x = PanelKit.MARGIN + (column - 1) * (CELL_WIDTH + GAP)
	local top = (row - 1) * (CELL_HEIGHT + GAP)
	options.width = CELL_WIDTH * unit
	options.position = UDim2.fromOffset(x * unit, top * unit)
	local face = CardFace.new(grid, options)
	if onClick then
		local button = PanelKit.hitBox(face, 0, 0, CELL_WIDTH, CELL_HEIGHT)
		button.ZIndex = BUTTON_LAYER
		button.Activated:Connect(onClick)
	end
end

return CardGrid
