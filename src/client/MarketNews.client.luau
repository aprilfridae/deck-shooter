-- Tells the player what happened in the market: outbid, won, sold, or a card that came back unsold
-- (docs/specs/market-screen.md). One short line slides in at the top of the screen, one after another.
-- It has its own script, not the menu's, because it shows whether or not the menu is open.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local CardCore = ReplicatedStorage:WaitForChild("CardCore")
local Cards = require(CardCore:WaitForChild("Cards"))
local Market = require(CardCore:WaitForChild("Market"))
local Zones = require(ReplicatedStorage:WaitForChild("Guns"):WaitForChild("Zones"))
local CardData = require(script.Parent.CardData)
local MenuPanel = require(script.Parent.MenuPanel)
local PanelKit = require(script.Parent.PanelKit)

local player = Players.LocalPlayer
local HEIGHT = 0.03
local PAD = 0.012
local TOP = 0.03
local SLIDE = 0.25 -- seconds
local SHOWN_FOR = 4
local RETRY = 2 -- seconds between asks for news that is waiting
local WAIT_STEP = 1 -- seconds between looks at whether the player is back in the Outpost

local gui = Instance.new("ScreenGui")
gui.Name = "MarketNews"
gui.DisplayOrder = 40
gui.IgnoreGuiInset = true
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")

local waiting: { string } = {}
local showing = false

local function show(text: string)
	local unit = MenuPanel.unit()
	local strip = Instance.new("Frame")
	strip.BackgroundColor3 = PanelKit.PAPER
	strip.BorderSizePixel = 0
	strip.AnchorPoint = Vector2.new(0.5, 0)
	strip.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 0.0056 * unit)
	corner.Parent = strip
	local label = PanelKit.label(strip, "LabelBold", PanelKit.LABEL_SIZE, PAD, HEIGHT * 0.64)
	label:set(text)
	strip.Size = UDim2.fromOffset(label:width() + PAD * 2 * unit, HEIGHT * unit)
	local hidden = UDim2.new(0.5, 0, 0, -HEIGHT * unit)
	local shown = UDim2.new(0.5, 0, 0, TOP * unit)
	strip.Position = hidden
	local ease = TweenInfo.new(SLIDE, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(strip, ease, { Position = shown }):Play()
	task.wait(SLIDE + SHOWN_FOR)
	TweenService:Create(strip, ease, { Position = hidden }):Play()
	task.wait(SLIDE)
	strip:Destroy()
end

local function run()
	if showing then
		return
	end
	showing = true
	while #waiting > 0 do
		-- Nothing pops up mid-match. It waits for the Outpost.
		while Zones.of(player) ~= Zones.Outpost do
			task.wait(WAIT_STEP)
		end
		show(table.remove(waiting, 1) :: string)
	end
	showing = false
end

local function add(item: any)
	if type(item) ~= "table" or type(item.cardId) ~= "string" or type(item.serial) ~= "number" then
		return
	end
	local card = Cards.byId[item.cardId]
	table.insert(waiting, Market.news({
		kind = item.kind,
		cardName = if card then card.name else item.cardId,
		serial = item.serial,
		price = item.price,
	}))
	task.spawn(run)
end

local remotes = ReplicatedStorage:WaitForChild("CardCoreRemotes")
remotes:WaitForChild("MarketNews").OnClientEvent:Connect(add)
-- Anything that settled before this script was listening, such as while the player was away.
-- The server refuses until the save has loaded, and until this gets through it only keeps news, it doesn't send
-- it. So keep asking.
while true do
	local reply = CardData.ask("MarketNewsWaiting")
	if reply.ok then
		for _, item in reply.news do
			add(item)
		end
		break
	end
	task.wait(RETRY)
end
