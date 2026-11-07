-- The Play page: the launch queues from matches.md. They say SOON until matches exist.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Guns = ReplicatedStorage:WaitForChild("Guns")
local PanelMotion = require(Guns:WaitForChild("Hud"):WaitForChild("PanelMotion"))
local Palette = require(Guns:WaitForChild("Palette"))
local MenuPanel = require(script.Parent.MenuPanel)
local PanelKit = require(script.Parent.PanelKit)

local ROUNDS = "FIRST TO 5 ROUND WINS TAKES THE MATCH."
local QUEUES = { -- the Label font has no commas or apostrophes
	{ mode = "ELIMINATION", size = "1V1", about = "ONE ON ONE. LAST PLAYER STANDING WINS THE ROUND.\n" .. ROUNDS },
	{ mode = "ELIMINATION", size = "2V2", about = "TEAMS OF TWO. WIPE THE OTHER TEAM. NO RESPAWNS.\n" .. ROUNDS },
	{ mode = "ELIMINATION", size = "3V3", about = "TEAMS OF THREE. WIPE THE OTHER TEAM. NO RESPAWNS.\n" .. ROUNDS },
	{
		mode = "TOWER",
		size = "5V5",
		about = "OWN THE TOWER WHEN TIME RUNS OUT TO WIN THE ROUND.\nCAPTURE IT IN THE ENEMY HOME ARENA TO WIN.",
	},
}

local ROW_HEIGHT = 0.062
local SIZE_TEXT = 0.04
local TICK_WIDTH = 0.006
local TEXT_GAP = 0.01 -- from the tick to the size
local MODE_LEFT = 0.2
local BLOCK_GAP = 0.02
local BLOCK_HEIGHT = 0.05
local ABOUT_GAP = 0.012 -- from the row's text to the first line of its description
local ABOUT_STEP = 0.016 -- between the lines of a description
local ABOUT_LINES = 2

local PlayPanel = {}

-- Draws a row inside its own box, which grows under the mouse and clips what's below its edge.
local function buildRow(content: Frame, queue: any): any
	local MARGIN, RIGHT = PanelKit.MARGIN, PanelKit.RIGHT
	local box = PanelKit.hitBox(content, 0, 0, MARGIN + RIGHT, ROW_HEIGHT)
	box.ClipsDescendants = true

	-- Everything on the row's top line is centred halfway between the rules of a closed row.
	local capHeight = SIZE_TEXT * PanelKit.CAP_HEIGHT
	local base = ROW_HEIGHT / 2 + capHeight / 2
	local labelBase = ROW_HEIGHT / 2 + PanelKit.LABEL_SIZE * PanelKit.CAP_HEIGHT / 2
	local inkLeft = MARGIN + TICK_WIDTH + TEXT_GAP
	local tick = PanelKit.block(box, MARGIN, base - capHeight, TICK_WIDTH, capHeight, PanelKit.NAVY)
	PanelKit.label(box, "Title", SIZE_TEXT, inkLeft - SIZE_TEXT * PanelKit.TITLE_INSET, base):set(queue.size)
	PanelKit.line(box, queue.mode, MODE_LEFT, labelBase)
	PanelKit.line(box, "SOON", RIGHT, labelBase, true)

	-- The open row keeps the same space under its last line as it has above the size.
	local smallCap = PanelKit.SMALL_SIZE * PanelKit.CAP_HEIGHT
	local firstLine = base + ABOUT_GAP + smallCap
	local lines = {}
	for line = 1, ABOUT_LINES do
		lines[line] = PanelKit.label(box, "Label", PanelKit.SMALL_SIZE, inkLeft, firstLine + (line - 1) * ABOUT_STEP)
	end

	return {
		box = box,
		tick = tick,
		lines = lines,
		about = queue.about,
		rule = PanelKit.rule(content, MARGIN, 0, RIGHT - MARGIN),
		tickHeight = capHeight,
		grows = ABOUT_GAP + smallCap + (ABOUT_LINES - 1) * ABOUT_STEP,
		opening = 0, -- seconds, up to PanelMotion.EXPAND_TIME
		decoding = 0, -- seconds since the mouse came onto the row
	}
end

local function showAbout(row: any, text: string)
	local parts = string.split(text, "\n")
	for line, drawn in row.lines do
		drawn:set(parts[line] or "")
	end
end

function PlayPanel.fill(content: Frame)
	local MARGIN, RIGHT = PanelKit.MARGIN, PanelKit.RIGHT
	PanelKit.title(content, "PLAY")
	local unit = MenuPanel.unit()
	local rows = {}
	local hovered: any? = nil -- only one row is open, and Roblox can report entering before leaving
	local function hover(row: any?)
		if hovered then
			showAbout(hovered, "") -- the first line would show through the edge of a closed row
		end
		hovered = row
		if row then
			row.decoding = 0
		end
	end
	for index, queue in QUEUES do
		local row = buildRow(content, queue)
		rows[index] = row
		row.box.MouseEnter:Connect(function()
			if hovered ~= row then
				hover(row)
			end
		end)
		row.box.MouseLeave:Connect(function()
			if hovered == row then
				hover(nil)
			end
		end)
	end

	local block = PanelKit.block(content, MARGIN, 0, RIGHT - MARGIN, BLOCK_HEIGHT, Palette.DataCyan)

	-- Stacks the rows, each starting where the one above it ended.
	local function stack()
		local top = PanelKit.RULE_LINE
		for _, row in rows do
			local extra = row.grows * PanelMotion.expand(row.opening)
			local height = ROW_HEIGHT + extra
			row.box.Position = UDim2.fromOffset(0, top * unit)
			row.box.Size = UDim2.fromOffset((MARGIN + RIGHT) * unit, height * unit)
			row.tick.Size = UDim2.fromOffset(TICK_WIDTH * unit, (row.tickHeight + extra) * unit)
			top += height
			row.rule.Position = UDim2.fromOffset(MARGIN * unit, top * unit)
		end
		block.Position = UDim2.fromOffset(MARGIN * unit, (top + BLOCK_GAP) * unit)
	end
	stack()

	local motion
	motion = RunService.RenderStepped:Connect(function(delta)
		if not content.Parent then
			motion:Disconnect()
			return
		end
		for _, row in rows do
			local goal = if row == hovered then PanelMotion.EXPAND_TIME else 0
			if row.opening < goal then
				row.opening = math.min(row.opening + delta, goal)
			elseif row.opening > goal then
				row.opening = math.max(row.opening - delta, goal)
			end
			if row == hovered then
				row.decoding += delta
				showAbout(row, PanelMotion.decode(row.about, row.decoding))
			end
		end
		stack()
	end)

	local word = PanelKit.label(block, "LabelBold", PanelKit.LABEL_SIZE, 0, 0)
	word:setPosition(UDim2.fromOffset(MARGIN * unit, (BLOCK_HEIGHT + PanelKit.LABEL_SIZE) / 2 * unit))
	word:set("MATCHES ARE ON THE WAY")
end

return PlayPanel
