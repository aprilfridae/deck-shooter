-- The player's Credits, income and rebirths, top left in the Outpost under the radio's strip
-- (docs/specs/hud-redesign.md). Plain type, on the same left margin as the radio and the nav.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PackText = require(ReplicatedStorage:WaitForChild("CardCore"):WaitForChild("PackText"))
local Palette = require(ReplicatedStorage:WaitForChild("Guns"):WaitForChild("Palette"))
local CardData = require(script.Parent.CardData)
local MenuPanel = require(script.Parent.MenuPanel)
local TypeLabel = require(script.Parent.TypeLabel)

local HUD_MARGIN = 32 -- real pixels from the screen's left edge, as in OutpostMenu and RadioHud
-- Shares of the unit. Each line is the baseline its text sits on.
local LABEL_LINE = 0.05
local CREDITS_LINE = 0.079
local REBIRTH_LINE = 0.097
local LABEL_SIZE = 0.0095
local CREDITS_SIZE = 0.03
local LABEL_TRACKING = 0.0022
local INCOME_GAP = 0.008 -- from the Credits to the income beside them
local GREY = Color3.fromRGB(170, 176, 182) -- the radio's artist line

local IncomeLine = {}

function IncomeLine.new(parent: Instance): Frame
	local unit = MenuPanel.unit()
	local frame = Instance.new("Frame")
	frame.BackgroundTransparency = 1
	frame.Position = UDim2.fromOffset(HUD_MARGIN, 0)
	frame.Size = UDim2.new(1, -HUD_MARGIN, 1, 0)
	frame.Parent = parent

	local function line(style: string, size: number, y: number, tracking: number, color: Color3): any
		return TypeLabel.new(frame, {
			style = style,
			size = size * unit,
			tracking = tracking * unit,
			color = color,
			position = UDim2.fromOffset(0, y * unit),
		})
	end
	line("Label", LABEL_SIZE, LABEL_LINE, LABEL_TRACKING, Palette.Bone):set("CREDITS")
	local credits = line("Title", CREDITS_SIZE, CREDITS_LINE, 0, Palette.Bone)
	local income = line("Label", LABEL_SIZE, CREDITS_LINE, LABEL_TRACKING, GREY)
	local rebirths = line("LabelBold", LABEL_SIZE, REBIRTH_LINE, LABEL_TRACKING, Palette.Bone)

	local function draw()
		local snapshot = CardData.get()
		if snapshot then
			-- PackText ends the amount with " CR". The label above already says what it is.
			credits:set((string.gsub(PackText.credits(snapshot.credits), " CR$", "")))
			income:set(PackText.income(snapshot.ratePerSecond))
			income:setPosition(UDim2.fromOffset(credits:width() + INCOME_GAP * unit, CREDITS_LINE * unit))
			rebirths:set(string.format("REBIRTH %02d", snapshot.rebirths))
		end
	end
	local changed = CardData.changed:Connect(draw)
	frame.Destroying:Once(function()
		changed:Disconnect()
	end)
	draw()
	return frame
end

return IncomeLine
