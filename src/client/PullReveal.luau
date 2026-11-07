-- The pull reveal: tearing a pack, flipping its cards, and quick lists for Auto Open and Open All.
-- Reveals queue up and play one at a time.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local CardCore = ReplicatedStorage:WaitForChild("CardCore")
local CardLook = require(CardCore:WaitForChild("CardLook"))
local Cards = require(CardCore:WaitForChild("Cards"))
local Inventory = require(CardCore:WaitForChild("Inventory"))
local Packs = require(CardCore:WaitForChild("Packs"))
local PullMotion = require(CardCore:WaitForChild("PullMotion"))
local Palette = require(ReplicatedStorage:WaitForChild("Guns"):WaitForChild("Palette"))
local CardData = require(script.Parent.CardData)
local CardFace = require(script.Parent.CardFace)
local CardInspect = require(script.Parent.CardInspect)
local MenuPanel = require(script.Parent.MenuPanel)
local PackCardBack = require(script.Parent.PackCardBack)
local PanelKit = require(script.Parent.PanelKit)
local PullStage = require(script.Parent.PullStage)

-- Shares of the unit.
local CARD_WIDTH = 0.135
local RARE_WIDTH = 0.1
local RARE_LEFT = 0.12 -- from the screen's middle, so it's clear of the menu
local BUTTON_WIDTH = 0.1
local BUTTON_HEIGHT = 0.03
local BUTTON_DROP = 0.17 -- below the screen's middle
local SHAKE = 0.006
local LIST_WIDTH = 0.34
local LIST_HEIGHT = 0.42
local LIST_ROW = 0.019
local LIST_TOP = 0.05
local LIST_BOTTOM = 0.05
local LIST_INSET = 0.02
local COUNT_LINE = 0.135 -- below the screen's middle
local NOTICE_HEIGHT = 0.09
local NOTICE_LINE = 0.03

local CARD_SHAPE = 240 / 150
local SHEET_DIM = 0.35
local RARE_SECONDS = 4 -- an Auto Open pull waits this long, so an idle player's queue keeps moving
local TOP_LAYER = 20
local SLOT_LAYER = 5

local player = Players.LocalPlayer

local gui = Instance.new("ScreenGui")
gui.Name = "PullReveal"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.DisplayOrder = 6 -- over the Outpost menu
gui.Enabled = false
gui.Parent = player:WaitForChild("PlayerGui")

local sheet = Instance.new("TextButton")
sheet.Text = ""
sheet.AutoButtonColor = false
sheet.BackgroundColor3 = Palette.DeepNavy
sheet.BorderSizePixel = 0
sheet.Size = UDim2.fromScale(1, 1)
sheet.Parent = gui

local queue: { { run: (Frame, () -> ()) -> (), auto: boolean } } = {}
local stage: Frame? = nil
local playing: { auto: boolean, settled: boolean?, done: () -> () }? = nil
local watching: RBXScriptConnection? = nil

local PullReveal = {}

local function tween(gui_: Instance, seconds: number, goal: { [string]: any }): Tween
	local playing = TweenService:Create(gui_, TweenInfo.new(seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), goal)
	playing:Play()
	return playing
end

local function stop()
	playing = nil
	if stage then
		stage:Destroy()
		stage = nil
	end
	if watching then
		watching:Disconnect()
		watching = nil
	end
	gui.Enabled = false
end

local function playNext()
	if stage then
		stage:Destroy()
		stage = nil
	end
	local entry = table.remove(queue, 1)
	if not entry then
		stop()
		return
	end
	local frame = Instance.new("Frame")
	frame.BackgroundTransparency = 1
	frame.Size = UDim2.fromScale(1, 1)
	frame.Parent = gui
	stage = frame
	sheet.Visible = true
	sheet.BackgroundTransparency = SHEET_DIM
	if not watching then
		-- The inspected card is in the world, so everything here has to step out of its way.
		watching = RunService.Heartbeat:Connect(function()
			gui.Enabled = not CardInspect.isOpen()
		end)
	end
	gui.Enabled = true
	local function done()
		if stage == frame then
			playNext()
		end
	end
	playing = { auto = entry.auto, done = done }
	entry.run(frame, done)
end

-- A player's own reveal goes ahead of Auto Open's, and cuts one short.
local function enqueue(job: (Frame, () -> ()) -> (), auto: boolean?)
	local entry = { run = job, auto = auto == true }
	if entry.auto then
		table.insert(queue, entry)
	else
		local place = #queue + 1
		for index, waiting in queue do
			if waiting.auto then
				place = index
				break
			end
		end
		table.insert(queue, place, entry)
		if playing and playing.auto then
			playing.done()
		end
	end
	if not stage then
		playNext()
	end
end

local function button(parent: Instance, text: string, offset: number, screenX: number?): TextButton
	local unit = MenuPanel.unit()
	local made = PanelKit.button(parent, text, 0, 0, BUTTON_WIDTH, BUTTON_HEIGHT, {})
	made.AnchorPoint = Vector2.new(0.5, 0)
	made.Position = UDim2.new(screenX or 0.5, offset * unit, 0.5, BUTTON_DROP * unit)
	made.ZIndex = TOP_LAYER
	return made
end

local function centred(gui_: GuiObject)
	gui_.AnchorPoint = Vector2.new(0.5, 0.5)
	gui_.Position = UDim2.fromScale(0.5, 0.5)
end

local function inspect(card: any)
	local snapshot = CardData.get()
	local key = Inventory.key(card.cardId, card.tier, card.variant)
	local count = snapshot and snapshot.stacks[key] or 1
	CardInspect.open({ cardId = card.cardId, tier = card.tier, variant = card.variant, count = count })
end

-- One face-down card for Auto Open. flip() builds and turns it, and clicking it afterwards inspects it.
local function cardSlot(parent: Frame, pack: string, card: any, width: number, x: number, onShown: () -> ()): any
	local unit = MenuPanel.unit()
	local height = width * CARD_SHAPE
	local rest = UDim2.new(0.5, x * unit, 0.5, 0)
	local holder = Instance.new("Frame")
	holder.BackgroundTransparency = 1
	holder.AnchorPoint = Vector2.new(0.5, 0.5)
	holder.Position = rest
	holder.Size = UDim2.fromOffset(width, height)
	holder.ZIndex = SLOT_LAYER
	holder.Parent = parent
	local back = PackCardBack.new(holder, pack, width)
	centred(back)
	local hit = Instance.new("TextButton")
	hit.Text = ""
	hit.BackgroundTransparency = 1
	hit.Size = UDim2.fromScale(1, 1)
	hit.ZIndex = TOP_LAYER
	hit.Parent = holder

	local state = "down"
	local function flip()
		if state ~= "down" then
			return
		end
		state = "building"
		task.spawn(function()
			local random = Random.new()
			local build = PullMotion.buildTime(card)
			local started = os.clock()
			while holder.Parent and os.clock() - started < build do
				local strength = SHAKE * unit * (os.clock() - started) / build
				holder.Position = rest + UDim2.fromOffset(random:NextNumber(-strength, strength), random:NextNumber(-strength, strength))
				task.wait()
			end
			if not holder.Parent then
				return
			end
			holder.Position = rest
			holder.ClipsDescendants = true
			local half = PullMotion.FLIP_TIME / 2
			tween(holder, half, { Size = UDim2.fromOffset(0, height) }).Completed:Wait()
			if not holder.Parent then
				return
			end
			back:Destroy()
			local face = CardFace.new(holder, { cardId = card.cardId, tier = card.tier, variant = card.variant, width = width })
			centred(face)
			tween(holder, half, { Size = UDim2.fromOffset(width, height) }).Completed:Wait()
			if not holder.Parent then
				return
			end
			holder.ClipsDescendants = false
			state = "up"
			onShown()
		end)
	end
	hit.Activated:Connect(function()
		if state == "up" then
			inspect(card)
		end
	end)
	return { flip = flip, holder = holder }
end

-- Plays by itself in the 3D world beside the menu, so the menu stays usable. Opening another
-- pack once this one has finished moves straight on to it.
function PullReveal.pack(pack: string, cards: { any })
	enqueue(function(frame: Frame, done: () -> ())
		sheet.Visible = false
		PullStage.play(frame, pack, cards, {
			inspect = inspect,
			rested = function(line: number)
				if stage == frame and playing then
					playing.settled = true
				end
				local close = button(frame, "DONE", 0, CardInspect.SCREEN_X)
				close.Position = UDim2.new(CardInspect.SCREEN_X, 0, 0, line)
				close.Activated:Once(done)
			end,
		})
	end)
	if playing and playing.settled then
		playing.done()
	end
end

-- One rare card from Auto Open. There's no sheet, so an idle player can still walk and click.
function PullReveal.rare(pack: string, card: any)
	local waiting = 0
	for _, entry in queue do
		waiting += if entry.auto then 1 else 0
	end
	if not PullMotion.keepsRare(waiting, card) then
		return
	end
	enqueue(function(frame: Frame, done: () -> ())
		local unit = MenuPanel.unit()
		sheet.Visible = false
		local slot = cardSlot(frame, pack, card, RARE_WIDTH * unit, -RARE_LEFT, function()
			task.delay(RARE_SECONDS, done)
		end)
		slot.flip()
	end, true)
end

-- A short message with a button.
function PullReveal.notice(text: string)
	enqueue(function(frame: Frame, done: () -> ())
		local unit = MenuPanel.unit()
		local paper = Instance.new("Frame")
		paper.BackgroundColor3 = PanelKit.PAPER
		paper.BorderSizePixel = 0
		paper.Size = UDim2.fromOffset(LIST_WIDTH * unit, NOTICE_HEIGHT * unit)
		centred(paper)
		paper.Parent = frame
		PanelKit.label(paper, "Label", PanelKit.SMALL_SIZE, LIST_INSET, NOTICE_LINE):set(text)
		local close = PanelKit.button(paper, "DONE", LIST_WIDTH / 2 - BUTTON_WIDTH / 2, NOTICE_HEIGHT - BUTTON_HEIGHT - 0.01, BUTTON_WIDTH, BUTTON_HEIGHT, {})
		close.Activated:Once(done)
	end)
end

local function listRows(frame: Frame, entries: { any }, opened: number, done: () -> ())
	local unit = MenuPanel.unit()
	local paper = Instance.new("Frame")
	paper.BackgroundColor3 = PanelKit.PAPER
	paper.BorderSizePixel = 0
	paper.Size = UDim2.fromOffset(LIST_WIDTH * unit, LIST_HEIGHT * unit)
	centred(paper)
	paper.Parent = frame
	PanelKit.heading(paper, `OPENED {opened} PACKS`, LIST_TOP - 0.015)
	local rows = Instance.new("ScrollingFrame")
	rows.BackgroundTransparency = 1
	rows.BorderSizePixel = 0
	rows.CanvasSize = UDim2.fromOffset(0, (#entries + 1) * LIST_ROW * unit)
	rows.Position = UDim2.fromOffset(0, LIST_TOP * unit)
	rows.ScrollBarImageColor3 = PanelKit.INK
	rows.ScrollBarThickness = 3
	rows.Size = UDim2.fromOffset(LIST_WIDTH * unit, (LIST_HEIGHT - LIST_TOP - LIST_BOTTOM) * unit)
	rows.Parent = paper
	local close = PanelKit.button(paper, "DONE", LIST_WIDTH / 2 - BUTTON_WIDTH / 2, LIST_HEIGHT - BUTTON_HEIGHT - 0.01, BUTTON_WIDTH, BUTTON_HEIGHT, {})
	close.Activated:Once(done)
	task.spawn(function()
		for index, entry in entries do
			if not rows.Parent then
				return
			end
			local y = index * LIST_ROW
			PanelKit.label(rows, "Label", PanelKit.SMALL_SIZE, LIST_INSET, y):set(`X{entry.count}`)
			local name = string.upper(Cards.byId[entry.cardId].name)
			PanelKit.label(rows, "Label", PanelKit.SMALL_SIZE, LIST_INSET + 0.06, y):set(`{name} {CardLook.rarityText(entry.tier, entry.variant)}`)
			task.wait(PullMotion.QUICK_ROW)
		end
	end)
end

-- Stops on each rare stack until it's clicked, then lists everything.
function PullReveal.summary(result: any)
	enqueue(function(frame: Frame, done: () -> ())
		local unit = MenuPanel.unit()
		local entries = PullMotion.quickList(result.cards)
		local rares = {}
		for _, entry in entries do
			if Packs.isRare(entry) then
				table.insert(rares, entry)
			end
		end
		local index = 0
		local holder: Frame? = nil
		local function advance()
			if holder then
				holder:Destroy()
				holder = nil
			end
			index += 1
			local entry = rares[index]
			if not entry then
				listRows(frame, entries, result.opened, done)
				return
			end
			local page = Instance.new("Frame")
			page.BackgroundTransparency = 1
			page.Size = UDim2.fromScale(1, 1)
			page.Parent = frame
			holder = page
			local face = CardFace.new(page, { cardId = entry.cardId, tier = entry.tier, variant = entry.variant, width = CARD_WIDTH * unit })
			centred(face)
			local count = PanelKit.label(page, "LabelBold", PanelKit.LABEL_SIZE, 0, 0, nil, PanelKit.PAPER)
			count:set(`X{entry.count}`)
			count:setPosition(UDim2.new(0.5, -count:width() / 2, 0.5, COUNT_LINE * unit))
			button(page, "NEXT", -BUTTON_WIDTH * 0.55).Activated:Once(advance)
			button(page, "SKIP", BUTTON_WIDTH * 0.55).Activated:Once(function()
				index = #rares
				advance()
			end)
		end
		advance()
	end)
end

function PullReveal.close()
	table.clear(queue)
	stop()
end

return PullReveal
