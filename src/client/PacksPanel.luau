-- The Packs page: rolling, the four packs, purchases and rebirths, and a sheet of the odds.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local CardCore = ReplicatedStorage:WaitForChild("CardCore")
local Config = require(CardCore:WaitForChild("Config"))
local Packs = require(CardCore:WaitForChild("Packs"))
local PackText = require(CardCore:WaitForChild("PackText"))
local Rebirth = require(CardCore:WaitForChild("Rebirth"))
local AutoRollUnlock = require(script.Parent.AutoRollUnlock)
local CardData = require(script.Parent.CardData)
local MenuPanel = require(script.Parent.MenuPanel)
local PackFace = require(script.Parent.PackFace)
local PanelKit = require(script.Parent.PanelKit)

-- Shares of the unit.
local INFO_LINE = 0.132
local INFO_MIDDLE = 0.2
local ROLL_TOP = 0.146
local ROLL_WIDTH = 0.26
local ROLL_HEIGHT = 0.05
local ROLL_TEXT = 0.02
local AUTO_LEFT = 0.295
local AUTO_WIDTH = 0.18
local BAR_TOP = 0.2
local BAR_HEIGHT = 0.005
local PACK_TOP = 0.218
local PACK_WIDTH = 0.108
local PACK_GAP = 0.004
local PACK_LIFT = 0.008
local COUNT_LINE = 0.402
local ODDS_LINE = 0.418
local BUTTON_TOP = 0.43
local BUTTON_HEIGHT = 0.03
local BUTTON_WIDTH = 0.1467
local BUTTON_GAP = 0.005
local BUTTON_TEXT = 0.0105
local REBIRTH_TOP = 0.468
local REBIRTH_HEIGHT = 0.036
local BACK_TOP = 0.066
local BACK_WIDTH = 0.06
local BACK_HEIGHT = 0.026
local SHEET_ROLL_LINE = 0.135
local SHEET_ROW = 0.017
local SHEET_HOLD_LINE = 0.245
local SHEET_COLUMNS = { 0.135, 0.21, 0.285, 0.385 }
local SHEET_ROWS = {
	{ "FIELD", "Field", 1 },
	{ "REDLINE", "BlackSite", 1 },
	{ "PROTOTYPE", "Prototype", 1 },
	{ "ZERO-DAY 1ST", "ZeroDay", 1 },
	{ "ZERO-DAY 2-3", "ZeroDay", 2 },
}

local LIFT_INFO = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local EMPTY_FADE = 0.45
local EMPTY_LAYER = 10
local CONFIRM_SECONDS = 3

local player = Players.LocalPlayer
local lastRolledAt: number? = nil

CardData.packEvent:Connect(function(event: any)
	if event.kind == "Rolled" then
		lastRolledAt = os.clock()
	end
end)

local PacksPanel = {}

local function chance(outcomes: { any }, name: string): number
	for _, outcome in outcomes do
		if outcome.name == name then
			return outcome.chance
		end
	end
	return 0
end

local function send(name: string, request: any?)
	task.spawn(CardData.ask, name, request)
end

local show: (Frame, (Frame) -> ()) -> ()

-- The chances for this player's luck, because a buyer should see what they're paying for.
local function oddsSheet(view: Frame)
	local snapshot = CardData.get()
	local luck = Packs.luck(if snapshot then snapshot.rebirths else 0)
	PanelKit.title(view, "ODDS")
	local back = PanelKit.button(view, "BACK", PanelKit.RIGHT - BACK_WIDTH, BACK_TOP, BACK_WIDTH, BACK_HEIGHT, { size = PanelKit.SMALL_SIZE })
	back.Activated:Connect(function()
		show(view.Parent :: Frame, PacksPanel.main)
	end)

	local function small(text: string, x: number, y: number)
		PanelKit.label(view, "Label", PanelKit.SMALL_SIZE, x, y):set(text)
	end

	PanelKit.heading(view, "ROLLING A PACK", SHEET_ROLL_LINE)
	for index, outcome in Packs.packOdds(luck) do
		local y = SHEET_ROLL_LINE + index * SHEET_ROW
		small(PackText.name(outcome.name), PanelKit.MARGIN, y)
		small(PackText.odds(outcome.chance), SHEET_COLUMNS[1], y)
	end

	PanelKit.heading(view, "EACH CARD IN A PACK", SHEET_HOLD_LINE)
	local header = SHEET_HOLD_LINE + SHEET_ROW
	for column, name in { "FIELD", "REDLINE", "PROTOTYPE", "ZERO-DAY" } do
		small(name, SHEET_COLUMNS[column], header)
	end
	for index, row in SHEET_ROWS do
		local y = header + index * SHEET_ROW
		local tiers = Packs.tierOdds(row[2], row[3], luck)
		small(row[1], PanelKit.MARGIN, y)
		small(PackText.odds(chance(tiers, "Field")), SHEET_COLUMNS[1], y)
		small(PackText.odds(chance(tiers, "BlackSite")), SHEET_COLUMNS[2], y)
		small(PackText.odds(chance(tiers, "Prototype")), SHEET_COLUMNS[3], y)
		small(PackText.odds(chance(Packs.variantOdds(row[2], row[3], luck), "ZeroDay")), SHEET_COLUMNS[4], y)
	end
	local variants = Packs.variantOdds("Field", 2, luck)
	local foot = header + (#SHEET_ROWS + 2) * SHEET_ROW
	small(`CHROMATIC {PackText.odds(chance(variants, "Chromatic"))}`, PanelKit.MARGIN, foot)
	small(`REDACTED {PackText.odds(chance(variants, "Redacted"))}`, SHEET_COLUMNS[2], foot)
	small("3 CARDS EACH PACK", SHEET_COLUMNS[3] + 0.05, foot)
end

local function packCell(view: Frame, pack: string, column: number): () -> ()
	local unit = MenuPanel.unit()
	local x = PanelKit.MARGIN + (column - 1) * (PACK_WIDTH + PACK_GAP)
	local height = PACK_WIDTH * PackFace.HEIGHT / PackFace.WIDTH
	local button = PanelKit.hitBox(view, x, PACK_TOP, PACK_WIDTH, height)
	local rest = button.Position
	PackFace.new(button, { pack = pack, width = PACK_WIDTH * unit })
	local empty = Instance.new("Frame")
	empty.BackgroundColor3 = PanelKit.PAPER
	empty.BackgroundTransparency = EMPTY_FADE
	empty.BorderSizePixel = 0
	empty.Size = UDim2.fromScale(1, 1)
	empty.ZIndex = EMPTY_LAYER
	empty.Parent = button

	local function lift(y: number)
		TweenService:Create(button, LIFT_INFO, { Position = rest + UDim2.fromOffset(0, y) }):Play()
	end
	button.MouseEnter:Connect(function()
		lift(-PACK_LIFT * unit)
	end)
	button.MouseLeave:Connect(function()
		lift(0)
	end)
	button.Activated:Connect(function()
		send("OpenPack", pack)
	end)

	local count = PanelKit.label(view, "LabelBold", PanelKit.LABEL_SIZE, x, COUNT_LINE)
	local odds = PanelKit.label(view, "Label", PanelKit.SMALL_SIZE, x, ODDS_LINE)
	return function()
		local snapshot = CardData.get()
		if snapshot then
			local owned = snapshot.packs[pack]
			count:set(`X{owned}`)
			odds:set(PackText.odds(chance(Packs.packOdds(Packs.luck(snapshot.rebirths)), pack)))
			empty.Visible = owned == 0
		end
	end
end

-- The buttons whose words change. They're rebuilt only when something on them does, so a Credit
-- ticking in doesn't interrupt a click.
local function controls(view: Frame): () -> ()
	local holder: Frame? = nil
	local shown = ""
	local confirming = 0 -- counts up, so an old timer can tell it's out of date

	local function refresh()
		local snapshot = CardData.get()
		if not snapshot then
			return
		end
		local unlocked = player:GetAttribute("AutoRollUnlocked") == true
		local rolling = player:GetAttribute("AutoRollOn") == true
		local hidden = player:GetAttribute("OpenAllHidden") == true
		local autoOpen = player:GetAttribute("AutoOpenOwned") == true
		local price = Rebirth.price(snapshot.rebirths)
		local canRebirth = snapshot.credits >= price
		local pile = Packs.pile(snapshot)
		local canOpenAll = pile > 0 and (snapshot.openAllCredits > 0 or Config.OpenAllProduct ~= 0)
		local key = table.concat({
			tostring(unlocked),
			tostring(rolling),
			tostring(hidden),
			tostring(autoOpen),
			tostring(canRebirth),
			tostring(canOpenAll),
			tostring(price),
			tostring(confirming % 2),
		}, "|")
		if key == shown then
			return
		end
		shown = key
		if holder then
			holder:Destroy()
		end
		local frame = Instance.new("Frame")
		frame.BackgroundTransparency = 1
		frame.Size = UDim2.fromScale(1, 1)
		frame.Parent = view
		holder = frame

		local autoWords = if not unlocked then "AUTO ROLL" elseif rolling then "AUTO ROLL ON" else "AUTO ROLL OFF"
		local auto = PanelKit.button(frame, autoWords, AUTO_LEFT, ROLL_TOP, AUTO_WIDTH, ROLL_HEIGHT, { active = rolling, size = BUTTON_TEXT })
		auto.Activated:Connect(function()
			if unlocked then
				send("SetAutoRoll", not rolling)
			else
				task.spawn(AutoRollUnlock.prompt)
			end
		end)

		local function small(text: string, column: number, options: any): TextButton
			options.size = BUTTON_TEXT
			local x = PanelKit.MARGIN + (column - 1) * (BUTTON_WIDTH + BUTTON_GAP)
			return PanelKit.button(frame, text, x, BUTTON_TOP, BUTTON_WIDTH, BUTTON_HEIGHT, options)
		end

		if not hidden then
			local ready = Config.OpenAllProduct ~= 0 or snapshot.openAllCredits > 0
			local openAll = small(if ready then "OPEN ALL" else "SOON", 1, { disabled = not canOpenAll })
			openAll.Activated:Connect(function()
				send("OpenAll")
			end)
		end

		local autoReady = Config.AutoOpenPass ~= 0
		local words = if autoOpen then "AUTO OPEN ON" elseif autoReady then "AUTO OPEN" else "SOON"
		local buy = small(words, 2, { disabled = autoOpen or not autoReady })
		buy.Activated:Connect(function()
			send("BuyAutoOpen")
		end)

		local odds = small("ODDS", 3, {})
		odds.Activated:Connect(function()
			show(view.Parent :: Frame, oddsSheet)
		end)

		local asking = confirming % 2 == 1
		local rebirthWords = if asking then "CONFIRM REBIRTH" else `REBIRTH {PackText.credits(price)}`
		local width = PanelKit.RIGHT - PanelKit.MARGIN
		local rebirth = PanelKit.button(frame, rebirthWords, PanelKit.MARGIN, REBIRTH_TOP, width, REBIRTH_HEIGHT, {
			active = asking,
			disabled = not canRebirth,
		})
		rebirth.Activated:Connect(function()
			if asking then
				confirming += 1
				send("Rebirth")
			else
				confirming += 1
				local waiting = confirming
				task.delay(CONFIRM_SECONDS, function()
					if confirming == waiting and view.Parent then
						confirming += 1
						refresh()
					end
				end)
			end
			refresh()
		end)
	end
	return refresh
end

function PacksPanel.main(view: Frame)
	PanelKit.title(view, "PACKS")
	local luck = PanelKit.line(view, "", PanelKit.MARGIN, INFO_LINE)
	local income = PanelKit.line(view, "", INFO_MIDDLE, INFO_LINE)
	local rebirths = PanelKit.line(view, "", PanelKit.RIGHT, INFO_LINE, true)

	local roll = PanelKit.button(view, "ROLL", PanelKit.MARGIN, ROLL_TOP, ROLL_WIDTH, ROLL_HEIGHT, { size = ROLL_TEXT })
	roll.Activated:Connect(function()
		send("Roll")
	end)

	local width = PanelKit.RIGHT - PanelKit.MARGIN
	PanelKit.block(view, PanelKit.MARGIN, BAR_TOP, width, BAR_HEIGHT, PanelKit.INK).BackgroundTransparency = 0.85
	local bar = PanelKit.block(view, PanelKit.MARGIN, BAR_TOP, width, BAR_HEIGHT, PanelKit.INK)
	local barHeight = bar.Size.Y.Offset
	local barWidth = bar.Size.X.Offset

	local cells = {}
	for column, pack in Packs.ids do
		cells[column] = packCell(view, pack, column)
	end
	local refreshControls = controls(view)

	local function redraw()
		local snapshot = CardData.get()
		if snapshot then
			luck:set(PackText.luck(snapshot.rebirths))
			income:set(PackText.income(snapshot.ratePerSecond))
			rebirths:set(`REBIRTHS {snapshot.rebirths}`)
		end
		for _, cell in cells do
			cell()
		end
		refreshControls()
	end

	local connections = {
		CardData.changed:Connect(redraw),
		player.AttributeChanged:Connect(redraw),
		RunService.RenderStepped:Connect(function()
			local filled = if lastRolledAt then math.min((os.clock() - lastRolledAt) / Packs.ROLL_SECONDS, 1) else 1
			bar.Size = UDim2.fromOffset(barWidth * filled, barHeight)
		end),
	}
	view.Destroying:Once(function()
		for _, connection in connections do
			connection:Disconnect()
		end
	end)
	redraw()
end

show = function(content: Frame, build: (Frame) -> ())
	content:ClearAllChildren()
	local view = Instance.new("Frame")
	view.BackgroundTransparency = 1
	view.Size = UDim2.fromScale(1, 1)
	view.Parent = content
	build(view)
end

function PacksPanel.fill(content: Frame)
	show(content, PacksPanel.main)
end

return PacksPanel
