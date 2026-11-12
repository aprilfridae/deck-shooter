-- The player's Credits and income, in the Outpost's top right corner. It was top left until the radio's strip
-- went there (2026-11-10); River means to rework this readout later, so it has only been moved.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PackText = require(ReplicatedStorage:WaitForChild("CardCore"):WaitForChild("PackText"))
local Palette = require(ReplicatedStorage:WaitForChild("Guns"):WaitForChild("Palette"))
local CardData = require(script.Parent.CardData)
local MenuPanel = require(script.Parent.MenuPanel)
local TypeLabel = require(script.Parent.TypeLabel)

-- Shares of the unit.
local RIGHT = 0.03 -- in from the right edge
local CREDITS_LINE = 0.07
local INCOME_LINE = 0.09
local CREDITS_SIZE = 0.016
local INCOME_SIZE = 0.012
local TRACKING = 0.0012

local IncomeLine = {}

function IncomeLine.new(parent: Instance): Frame
	local unit = MenuPanel.unit()
	local frame = Instance.new("Frame")
	frame.BackgroundTransparency = 1
	frame.Size = UDim2.fromScale(1, 1)
	frame.Parent = parent

	local function line(style: string, size: number, y: number): any
		return TypeLabel.new(frame, {
			style = style,
			size = size * unit,
			tracking = TRACKING * unit,
			color = Palette.Bone,
			right = true,
			position = UDim2.new(1, -RIGHT * unit, 0, y * unit),
		})
	end
	local credits = line("LabelBold", CREDITS_SIZE, CREDITS_LINE)
	local income = line("Label", INCOME_SIZE, INCOME_LINE)

	local function draw()
		local snapshot = CardData.get()
		if snapshot then
			credits:set(PackText.credits(snapshot.credits))
			income:set(PackText.income(snapshot.ratePerSecond))
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
