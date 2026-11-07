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
local PackArt = require(CardCore:WaitForChild("PackArt"))
local Packs = require(CardCore:WaitForChild("Packs"))
local PullMotion = require(CardCore:WaitForChild("PullMotion"))
local Variant = require(CardCore:WaitForChild("Variant"))
local Palette = require(ReplicatedStorage:WaitForChild("Guns"):WaitForChild("Palette"))
local CardData = require(script.Parent.CardData)
local CardFace = require(script.Parent.CardFace)
local CardInspect = require(script.Parent.CardInspect)
local MenuPanel = require(script.Parent.MenuPanel)
local PackFace = require(script.Parent.PackFace)
local PanelKit = require(script.Parent.PanelKit)
local TypeLabel = require(script.Parent.TypeLabel)

-- Shares of the unit.
local CARD_WIDTH = 0.135
local PACK_WIDTH = 0.14
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

local CARD_SHAPE = 240 / 150
local CARD_CORNER = 10 / 150 -- of the width
local TEAR_LINE = 0.16 -- of the wrapper's height
local SHEET_DIM = 0.35
local ZERO_DAY_DIM = 0.12
local ZERO_DAY_GROWTH = 1.3
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

local queue: { (Frame, () -> ()) -> () } = {}
local stage: Frame? = nil
local watching: RBXScriptConnection? = nil

local PullReveal = {}

local function tween(gui_: Instance, seconds: number, goal: { [string]: any }): Tween
	local playing = TweenService:Create(gui_, TweenInfo.new(seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), goal)
	playing:Play()
	return playing
end

local function stop()
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
	local job = table.remove(queue, 1)
	if not job then
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
	job(frame, function()
		if stage == frame then
			playNext()
		end
	end)
end

local function enqueue(job: (Frame, () -> ()) -> ())
	table.insert(queue, job)
	if not stage then
		playNext()
	end
end

local function button(parent: Instance, text: string, offset: number): TextButton
	local unit = MenuPanel.unit()
	local made = PanelKit.button(parent, text, 0, 0, BUTTON_WIDTH, BUTTON_HEIGHT, {})
	made.AnchorPoint = Vector2.new(0.5, 0)
	made.Position = UDim2.new(0.5, offset * unit, 0.5, BUTTON_DROP * unit)
	made.ZIndex = TOP_LAYER
	return made
end

local function centred(gui_: GuiObject)
	gui_.AnchorPoint = Vector2.new(0.5, 0.5)
	gui_.Position = UDim2.fromScale(0.5, 0.5)
end

-- A plain back in the pack's colours. The card's real back would give away its name.
local function plainBack(parent: Instance, pack: string, width: number): Frame
	local look = PackFace.look(pack)
	local back = Instance.new("Frame")
	back.BackgroundColor3 = look.back
	back.BorderSizePixel = 0
	back.Size = UDim2.fromScale(1, 1)
	back.Parent = parent
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, CARD_CORNER * width)
	corner.Parent = back
	local outline = Instance.new("UIStroke")
	outline.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	outline.Color = look.art
	outline.Thickness = width * 0.012
	outline.Parent = back
	local size = width * 0.42
	local words = TypeLabel.new(back, {
		style = "LabelLarge",
		size = size,
		tracking = 0,
		color = look.art,
		shadow = false,
		position = UDim2.fromOffset(0, width * CARD_SHAPE / 2 + size * 0.35),
	})
	words:set("S1")
	words:setPosition(UDim2.fromOffset((width - words:width()) / 2, width * CARD_SHAPE / 2 + size * 0.35))
	return back
end

local function inspect(card: any)
	local snapshot = CardData.get()
	local key = Inventory.key(card.cardId, card.tier, card.variant)
	local count = snapshot and snapshot.stacks[key] or 1
	CardInspect.open({ cardId = card.cardId, tier = card.tier, variant = card.variant, count = count })
end

-- One face-down card. flip() builds and turns it, and clicking it afterwards inspects it.
local function cardSlot(parent: Frame, pack: string, card: any, width: number, x: number, tilt: number, onZeroDay: (() -> ())?, onShown: () -> ()): any
	local unit = MenuPanel.unit()
	local height = width * CARD_SHAPE
	local rest = UDim2.new(0.5, x * unit, 0.5, 0)
	local holder = Instance.new("Frame")
	holder.BackgroundTransparency = 1
	holder.AnchorPoint = Vector2.new(0.5, 0.5)
	holder.Position = rest
	holder.Rotation = tilt
	holder.Size = UDim2.fromOffset(width, height)
	holder.ZIndex = SLOT_LAYER
	holder.Parent = parent
	local grow = Instance.new("UIScale")
	grow.Parent = holder
	local back = plainBack(holder, pack, width)
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
			holder.Rotation = 0
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
			local zeroDay = card.variant == Variant.ZeroDay
			if zeroDay and onZeroDay then
				onZeroDay()
			end
			-- A rotated frame can't clip, which is why the card straightens before it turns.
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
			if zeroDay and onZeroDay then
				holder.ZIndex = TOP_LAYER
				tween(grow, half, { Scale = ZERO_DAY_GROWTH })
			else
				tween(holder, half, { Rotation = tilt })
			end
			state = "up"
			onShown()
		end)
	end
	hit.Activated:Connect(function()
		if state == "up" then
			inspect(card)
		else
			flip()
		end
	end)
	return { flip = flip, holder = holder }
end

-- The wrapper's two halves pulling apart along the tear.
local function tear(parent: Frame, pack: string, width: number)
	local height = width * PackFace.HEIGHT / PackFace.WIDTH
	local function half(top: number, bottom: number, direction: number)
		local clip = Instance.new("Frame")
		clip.BackgroundTransparency = 1
		clip.ClipsDescendants = true
		clip.AnchorPoint = Vector2.new(0.5, 0)
		clip.Position = UDim2.new(0.5, 0, 0.5, -height / 2 + top * height)
		clip.Size = UDim2.fromOffset(width, (bottom - top) * height)
		clip.Parent = parent
		local image = Instance.new("ImageLabel")
		image.BackgroundTransparency = 1
		image.Image = PackArt.image(pack) or ""
		image.Position = UDim2.fromOffset(0, -top * height)
		image.Size = UDim2.fromOffset(width, height)
		image.Parent = clip
		tween(clip, PullMotion.TEAR_TIME, { Position = clip.Position + UDim2.fromOffset(0, direction * height * 0.6) })
		tween(image, PullMotion.TEAR_TIME, { ImageTransparency = 1 })
	end
	half(0, TEAR_LINE, -1)
	half(TEAR_LINE, 1, 1)
end

function PullReveal.pack(pack: string, cards: { any })
	enqueue(function(frame: Frame, done: () -> ())
		local unit = MenuPanel.unit()
		tear(frame, pack, PACK_WIDTH * unit)
		task.delay(PullMotion.TEAR_TIME * 0.7, function()
			if not frame.Parent then
				return
			end
			local left = #cards
			local function shown()
				left -= 1
				if left == 0 then
					button(frame, "DONE", 0).Activated:Once(done)
				end
			end
			local function zeroDay()
				sheet.BackgroundTransparency = ZERO_DAY_DIM
			end
			for index, card in cards do
				local x, tilt = PullMotion.fan(index)
				local slot = cardSlot(frame, pack, card, CARD_WIDTH * unit, x, tilt, zeroDay, shown)
				local fanned = slot.holder.Position
				slot.holder.Position = UDim2.fromScale(0.5, 0.5)
				slot.holder.Rotation = 0
				tween(slot.holder, PullMotion.FLIP_TIME, { Position = fanned, Rotation = tilt })
			end
		end)
	end)
end

-- One rare card from Auto Open. There's no sheet, so an idle player can still walk and click.
function PullReveal.rare(pack: string, card: any)
	enqueue(function(frame: Frame, done: () -> ())
		local unit = MenuPanel.unit()
		sheet.Visible = false
		local slot = cardSlot(frame, pack, card, RARE_WIDTH * unit, -RARE_LEFT, 0, nil, function()
			task.delay(RARE_SECONDS, done)
		end)
		slot.flip()
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
