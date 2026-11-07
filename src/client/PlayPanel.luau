-- The Play page: the launch queues from matches.md. They say SOON until matches exist.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Palette = require(ReplicatedStorage:WaitForChild("Guns"):WaitForChild("Palette"))
local MenuPanel = require(script.Parent.MenuPanel)
local PanelKit = require(script.Parent.PanelKit)

local QUEUES = {
	{ mode = "ELIMINATION", size = "1V1" },
	{ mode = "ELIMINATION", size = "2V2" },
	{ mode = "ELIMINATION", size = "3V3" },
	{ mode = "TOWER", size = "5V5" },
}

local ROW_HEIGHT = 0.062
local SIZE_TEXT = 0.04
local TICK_WIDTH = 0.006
local TEXT_GAP = 0.01 -- from the tick to the size
local MODE_LEFT = 0.2
local BLOCK_GAP = 0.02
local BLOCK_HEIGHT = 0.05

local PlayPanel = {}

function PlayPanel.fill(content: Frame)
	local MARGIN, RIGHT = PanelKit.MARGIN, PanelKit.RIGHT
	PanelKit.title(content, "PLAY")
	for index, queue in QUEUES do
		-- Everything in a row is centred on the same line, halfway between its two rules.
		local rowTop = PanelKit.RULE_LINE + (index - 1) * ROW_HEIGHT
		local middle = rowTop + ROW_HEIGHT / 2
		local capHeight = SIZE_TEXT * PanelKit.CAP_HEIGHT
		local base = middle + capHeight / 2
		local labelBase = middle + PanelKit.LABEL_SIZE * PanelKit.CAP_HEIGHT / 2
		local textLeft = MARGIN + TICK_WIDTH + TEXT_GAP - SIZE_TEXT * PanelKit.TITLE_INSET
		PanelKit.block(content, MARGIN, base - capHeight, TICK_WIDTH, capHeight, PanelKit.NAVY)
		PanelKit.label(content, "Title", SIZE_TEXT, textLeft, base):set(queue.size)
		PanelKit.line(content, queue.mode, MODE_LEFT, labelBase)
		PanelKit.line(content, "SOON", RIGHT, labelBase, true)
		PanelKit.rule(content, MARGIN, rowTop + ROW_HEIGHT, RIGHT - MARGIN)
	end

	local top = PanelKit.RULE_LINE + #QUEUES * ROW_HEIGHT + BLOCK_GAP
	local unit = MenuPanel.unit()
	local block = PanelKit.block(content, MARGIN, top, RIGHT - MARGIN, BLOCK_HEIGHT, Palette.SignalAcid)
	local word = PanelKit.label(block, "LabelBold", PanelKit.LABEL_SIZE, 0, 0)
	word:setPosition(UDim2.fromOffset(MARGIN * unit, (BLOCK_HEIGHT + PanelKit.LABEL_SIZE) / 2 * unit))
	word:set("MATCHES ARE ON THE WAY")
end

return PlayPanel
