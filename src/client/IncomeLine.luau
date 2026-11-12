-- The player's Credits, income and rebirths, top left in the Outpost under the radio's strip
-- (docs/specs/hud-redesign.md). Plain type, on the same left margin as the radio and the nav.
local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local PackText = require(ReplicatedStorage:WaitForChild("CardCore"):WaitForChild("PackText"))
local Palette = require(ReplicatedStorage:WaitForChild("Guns"):WaitForChild("Palette"))
local CardData = require(script.Parent.CardData)
local MenuPanel = require(script.Parent.MenuPanel)
local TypeLabel = require(script.Parent.TypeLabel)

local HUD_MARGIN = 32 -- real pixels from the screen's left edge, as in OutpostMenu and RadioHud
-- The radio's strip is laid out for a screen 1080 high and scaled by the screen's height (RadioHud.luau), while
-- this is sized by the unit, which follows the width on a narrow window. So it hangs from where the strip really
-- ends, or the two overlap.
local RADIO_BOTTOM = 62 / 1080 -- of the screen's height: the strip's top (14) and height (48)
local RADIO_GAP = 0.012 -- of the unit, from the strip down to this readout
-- Shares of the unit, down from there. Each line is the baseline its text sits on.
local LABEL_LINE = 0.0095
local CREDITS_LINE = 0.0385
local REBIRTH_LINE = 0.0565
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
	-- The radio's screen starts under Roblox's top bar, and this one starts at the very top.
	local inset = GuiService:GetGuiInset().Y
	local top = inset + Workspace.CurrentCamera.ViewportSize.Y * RADIO_BOTTOM + RADIO_GAP * unit
	frame.Position = UDim2.fromOffset(HUD_MARGIN, top)
	frame.Size = UDim2.new(1, -HUD_MARGIN, 1, -top)
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
