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

local LIST_TOP = 0.145
local ROW_STEP = 0.062
local SIZE_TEXT = 0.04
local TICK_WIDTH = 0.006
local BLOCK_HEIGHT = 0.05

local PlayPanel = {}

function PlayPanel.fill(content: Frame)
	local MARGIN, RIGHT = PanelKit.MARGIN, PanelKit.RIGHT
	PanelKit.title(content, "PLAY")
	for index, queue in QUEUES do
		local base = LIST_TOP + (index - 1) * ROW_STEP
		PanelKit.block(content, MARGIN, base - SIZE_TEXT, TICK_WIDTH, SIZE_TEXT, PanelKit.NAVY)
		PanelKit.label(content, "Title", SIZE_TEXT, MARGIN + 0.016, base):set(queue.size)
		PanelKit.line(content, queue.mode, 0.2, base - 0.002)
		PanelKit.line(content, "SOON", RIGHT, base - 0.002, true)
		PanelKit.rule(content, MARGIN, base + (ROW_STEP - SIZE_TEXT) / 2, RIGHT - MARGIN)
	end

	local top = LIST_TOP + #QUEUES * ROW_STEP - 0.01
	local unit = MenuPanel.unit()
	local block = PanelKit.block(content, MARGIN, top, RIGHT - MARGIN, BLOCK_HEIGHT, Palette.SignalAcid)
	local word = PanelKit.label(block, "LabelBold", PanelKit.LABEL_SIZE, 0, 0)
	word:setPosition(UDim2.fromOffset(MARGIN * unit, (BLOCK_HEIGHT + PanelKit.LABEL_SIZE) / 2 * unit))
	word:set("MATCHES ARE ON THE WAY")
end

return PlayPanel
